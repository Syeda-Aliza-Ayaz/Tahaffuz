/*  Tahaffuz - web server

    swipl server.pl            then open http://localhost:8080
    swipl server.pl 9000       use another port

    Routes:
      GET  /              web/index.html
      GET  /static/...    files in web/ (CSS, JS)
      POST /api/analyse   {"message": "..."}  ->  verdict, score, reasons

    Bound to localhost only: nobody else on the network can reach it.
*/
:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, src, SrcDir),
   asserta(user:file_search_path(src, SrcDir)),
   directory_file_path(Dir, web, WebDir),
   asserta(user:file_search_path(web, WebDir)).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).
:- use_module(library(http/http_server_files)).
:- use_module(src(explain)).
:- use_module(src(diagnosis)).

:- initialization(main, main).

max_length(5000).

:- http_handler(root(.),            http_reply_file(web('index.html'), []), []).
:- http_handler(root(static),       serve_files_in_directory(web), [prefix]).
:- http_handler(root(api/analyse),  analyse_handler, [method(post)]).

main :-
    current_prolog_flag(argv, Argv),
    (   Argv = [P|_], atom_number(P, Port) -> true
    ;   getenv('PORT', PortStr), atom_number(PortStr, Port) -> true
    ;   Port = 8080
    ),
    http_server(http_dispatch, [port(Port)]),
    format("Tahaffuz running at http://localhost:~w  (Ctrl+C to stop)~n", [Port]),
    thread_get_message(stop).       % keep the server alive

% ---------------------------------------------------------------
% POST /api/analyse
% ---------------------------------------------------------------

analyse_handler(Request) :-
    (   catch(http_read_json_dict(Request, In), _, fail),
        is_dict(In),
        get_dict(message, In, Message),
        string(Message)
    ->  check_message(Message)
    ;   reply_error(400, "Send JSON like {\"message\": \"your text\"}.")
    ).

check_message(Message) :-
    max_length(Max),
    normalize_space(string(Trimmed), Message),
    string_length(Message, Len),
    (   Trimmed == ""
    ->  reply_error(400, "The message is empty.")
    ;   Len > Max
    ->  format(string(E), "The message is too long (~w characters, limit ~w).", [Len, Max]),
        reply_error(400, E)
    ;   reply_analysis(Message)
    ).

reply_analysis(Message) :-
    assess(Message, Score, Verdict, Reasons, Types, action(Action, ActionText), Advice),
    percent(Score, Percent),
    maplist(reason_json, Reasons, ReasonsJson),
    maplist(diagnosis_json, Types, DiagnosisJson),
    Result0 = _{ score: S2, percent: Percent, verdict: Verdict,
                 capped: Capped, reasons: ReasonsJson,
                 diagnosis: DiagnosisJson,
                 action: _{ type: Action, text: ActionText },
                 advice: Advice },
    S2 is round(Score * 100) / 100,
    (   gate_note(Score, Verdict, Note)
    ->  Capped = true, Result = Result0.put(note, Note)
    ;   Capped = false, Result = Result0
    ),
    reply_json_dict(Result).

reason_json(reason(Name, CF, Contribution, Text, Evidence),
            _{ indicator: Name, cf: CF, contribution: C2,
               reason: Text, matched: Evidence }) :-
    C2 is round(Contribution * 100) / 100.

diagnosis_json(Type, _{ type: Type, name: Name, description: Desc }) :-
    scam_type(Type, Name, Desc).

reply_error(Status, Message) :-
    reply_json_dict(_{ error: Message }, [status(Status)]).
