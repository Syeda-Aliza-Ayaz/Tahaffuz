/*  Tahaffuz - Explanation facility
    ---------------------------------------------------------------
    Runs the matcher and inference engine and records why the verdict
    was reached: each fired indicator, its CF, the words that triggered
    it, and how much it raised the score.

    Contribution = how much the score went up when this indicator was
    combined in. Indicators are combined strongest first, so the
    contributions add up exactly to the final score.

    assess/7 adds the diagnosis (which kind of scam) and decision support
    (what to do) from diagnosis.pl.
*/
:- module(explain, [
    analyse/4,          % +Message, -Score, -Verdict, -Reasons
    assess/7,           % +Message, -Score, -Verdict, -Reasons, -Types, -Action, -Advice
    explain/1,          % +Message   (prints a report)
    percent/2,          % +Score, -Percent
    gate_note/3         % +Score, +Verdict, -Note   (fails if not capped)
]).
:- use_module(kb).
:- use_module(matcher).
:- use_module(inference).
:- use_module(diagnosis).

% full consultation: verdict + reasons + diagnosis + what to do
assess(Message, Score, Verdict, Reasons, Types, Action, Advice) :-
    analyse(Message, Score, Verdict, Reasons),
    findall(N, member(reason(N, _, _, _, _), Reasons), Names),
    diagnose(Verdict, Names, Types),
    decision_support(Verdict, Types, Action, Advice).

% Reasons = [reason(Indicator, CF, Contribution, Text, Evidence), ...]
analyse(Message, Score, Verdict, Reasons) :-
    fired_indicators(Message, Fired),
    findall(CF-fired(N, Ev),
            ( member(fired(N, Ev), Fired), indicator(N, CF, _) ),
            Pairs),
    sort(1, @>=, Pairs, Sorted),
    contributions(Sorted, 0, Score0, Reasons),
    Score is round(Score0 * 10000) / 10000,     % avoid 0.69999 at band edges
    findall(N, member(fired(N, _), Fired), Names),
    verdict(Score, Names, Verdict).

% MYCIN never reaches 1.0, so never show 100%
percent(Score, Percent) :-
    Percent is min(99, round(Score * 100)).

% Explains the gate rule when it lowered the verdict (used by the console
% and the web page, so both say the same thing).
gate_note(Score, Verdict, Note) :-
    capped(Score, Verdict),
    percent(Score, Percent),
    format(string(Note),
           "The score is ~w%, but the message never directly asks for money, an OTP, personal details, a call to a personal number, or a visit to a fake brand site - so it is rated Suspicious, not Scam.",
           [Percent]).

contributions([], S, S, []).
contributions([CF-fired(N, Ev)|T], S0, S, [reason(N, CF, C, Text, Ev)|Rs]) :-
    combine(S0, CF, S1),
    C is S1 - S0,
    indicator(N, _, Text),
    contributions(T, S1, S, Rs).

% ---------------------------------------------------------------
% Console report
% ---------------------------------------------------------------

explain(Message) :-
    assess(Message, Score, Verdict, Reasons, Types, action(_, ActionText), Advice),
    percent(Score, Percent),
    upcase_atom(Verdict, V),
    format("~nMessage: ~s~n", [Message]),
    format("Verdict: ~w   (confidence ~w%)~n", [V, Percent]),
    (   Reasons == []
    ->  format("No scam indicators found.~n")
    ;   format("Reasons (strongest first):~n"),
        forall(member(R, Reasons), print_reason(R))
    ),
    (   gate_note(Score, Verdict, Note)
    ->  format("Note: ~s~n", [Note])
    ;   true
    ),
    (   Types == []
    ->  true
    ;   format("Diagnosis:~n"),
        forall(member(T, Types),
               ( scam_type(T, Name, Desc), format("  - ~w: ~w~n", [Name, Desc]) ))
    ),
    format("What to do: ~w~n", [ActionText]),
    forall(member(Tip, Advice), format("  * ~w~n", [Tip])).

print_reason(reason(_, CF, C, Text, Ev)) :-
    atomic_list_concat(Ev, ', ', EvText),
    format("  +~2f  ~w  [CF ~2f]~n          matched: ~w~n", [C, Text, CF, EvText]).
