/*  Tahaffuz - evaluate on a public SMS corpus

    swipl tests/eval_corpus.pl uci              UCI SMS Spam Collection
    swipl tests/eval_corpus.pl mendeley         Mendeley SMS Phishing dataset
    swipl tests/eval_corpus.pl mendeley count   only check the file loads
    swipl tests/eval_corpus.pl zenodo summary   numbers only, no message text
    swipl tests/eval_corpus.pl pksms summary

    Corpora: uci, mendeley, zenodo, pksms.
    Modes:   (none) full report incl. example messages | summary | count

    Datasets (evaluation only - nothing in kb.pl is taken from them):
      data/uci/SMSSpamCollection     ham / spam, tab separated
          Almeida & Gomez Hidalgo, UCI ML Repository, CC BY 4.0
      data/mendeley/Dataset_5971.csv ham / spam / smishing, CSV
          Mishra & Soni, "SMS Phishing Dataset for Machine Learning and
          Pattern Recognition", Mendeley Data, 2022, CC BY 4.0,
          doi:10.17632/f45bkkt8pr.1
      data/zenodo_ru/phishing_dataset_1000.csv  0 = ham, 1 = smishing
          G. Siddiq, "Roman Urdu Phishing SMS Dataset for Smishing
          Detection Research", Zenodo, v1.0.0, 2026, CC BY 4.0,
          doi:10.5281/zenodo.21810885 (converted from .xlsx, unchanged).
          Pakistani Roman Urdu / English; likely template-generated.
      data/pk_sms/Pakistan_sms_dataset.csv  Normal / Promotional / fraud
          Kaggle "pakistan-sms-classification-dataset" via GitHub
          usamabhatti1998/pakistan_sms_classification. No licence stated.
          English only; partly LLM-paraphrased (per its README).

    "spam" is mostly marketing, not fraud. The useful numbers are
    false positives on "ham" and recall on "smishing".

    Don't tune against mendeley / zenodo / pksms results.
*/
:- use_module(library(csv)).
:- use_module('../src/explain').

:- initialization(main, main).

:- dynamic tests_dir/1.
:- prolog_load_context(directory, Dir), asserta(tests_dir(Dir)).

main :-
    current_prolog_flag(argv, Argv),
    (   Argv = [CorpusA|Rest], atom_string(Corpus0, CorpusA), atom(Corpus0)
    ->  Corpus = Corpus0
    ;   Corpus = uci, Rest = []
    ),
    load(Corpus, Rows),
    (   Rest = [count|_]   -> label_counts(Corpus, Rows)
    ;   Rest = [summary|_] -> summary(Corpus, Rows)
    ;   evaluate(Corpus, Rows)
    ).

% ---------------------------------------------------------------
% Loading: Rows = [Label-Text], Label in ham | spam | smishing
% ---------------------------------------------------------------

corpus_path(Rel, File) :-
    tests_dir(Dir),
    directory_file_path(Dir, Rel, File).

load(uci, Rows) :-
    corpus_path('../data/uci/SMSSpamCollection', File),
    read_file_to_string(File, Content, [encoding(utf8)]),
    split_string(Content, "\n", "\r", Lines),
    findall(Label-Text, ( member(L, Lines), tab_line(L, Label, Text) ), Rows).
load(mendeley, Rows) :-
    corpus_path('../data/mendeley/Dataset_5971.csv', File),
    csv_read_file(File, [_Header|Records], [convert(false), match_arity(false), encoding(utf8)]),
    findall(Label-Text,
            ( member(R, Records), arg(1, R, L0), arg(2, R, Text),
              downcase_atom(L0, Label) ),
            Rows).
load(zenodo, Rows) :-
    load_grouped(zenodo, Grouped),
    findall(L-T, member(L-_-T, Grouped), Rows).
load(pksms, Rows) :-
    corpus_path('../data/pk_sms/Pakistan_sms_dataset.csv', File),
    csv_read_file(File, [_Header|Records], [convert(false), match_arity(false), encoding(utf8)]),
    findall(Label-Text,
            ( member(R, Records), arg(1, R, L0), arg(2, R, Text),
              downcase_atom(L0, L1), pksms_label(L1, Label) ),
            Rows).

pksms_label(normal, ham).
pksms_label(promotional, spam).
pksms_label(fraud, smishing).

% Label-Group-Text, Group = the dataset's own category column
load_grouped(zenodo, Rows) :-
    corpus_path('../data/zenodo_ru/phishing_dataset_1000.csv', File),
    csv_read_file(File, [_Header|Records], [convert(false), match_arity(false), encoding(utf8)]),
    findall(Label-Group-Text,
            ( member(R, Records), arg(2, R, Text), arg(3, R, L0), arg(4, R, Group),
              zenodo_label(L0, Label) ),
            Rows).

zenodo_label('0', ham).
zenodo_label('1', smishing).

tab_line(Line, Label, Text) :-
    sub_string(Line, B, 1, A, "\t"), !,
    sub_string(Line, 0, B, _, LabelS),
    sub_string(Line, _, A, 0, Text),
    atom_string(Label, LabelS).

label_counts(Corpus, Rows) :-
    length(Rows, N),
    format("~w: ~w messages loaded~n", [Corpus, N]),
    forall(member(L, [ham, spam, smishing]),
           ( aggregate_all(count, member(L-_, Rows), C),
             ( C > 0 -> format("  ~w: ~w~n", [L, C]) ; true ) )).

% ---------------------------------------------------------------
% Evaluation
% ---------------------------------------------------------------

evaluate(Corpus, Rows) :-
    findall(L-V-T, ( member(L-T, Rows), analyse(T, _, V, _) ), Results),
    format("~n=== ~w ===~n", [Corpus]),
    forall(member(L, [ham, spam, smishing]), table(L, Results)),
    format("~nGenuine (ham) messages rated SCAM:~n"),
    forall(member(ham-scam-T, Results), show(T)),
    show_first(15, ham-suspicious, Results, "Genuine (ham) messages rated SUSPICIOUS"),
    show_first(15, smishing-safe, Results, "Smishing messages rated SAFE (missed)").

% numbers only: verdict counts per label and which indicators fired,
% never any message text (keeps the dataset unseen)
summary(Corpus, Rows) :-
    findall(L-V-Ns,
            ( member(L-T, Rows), analyse(T, _, V, Rs),
              findall(N, member(reason(N, _, _, _, _), Rs), Ns) ),
            Results),
    format("~n=== ~w (summary only) ===~n", [Corpus]),
    forall(member(L, [ham, spam, smishing]), table(L, Results)),
    forall(member(L, [ham, smishing]), indicator_counts(L, Results)),
    (   catch(load_grouped(Corpus, Grouped), _, fail)
    ->  group_table(Grouped)
    ;   true
    ).

% verdicts per dataset category (category names only, no message text)
group_table(Grouped) :-
    findall(G, member(_-G-_, Grouped), Gs0), sort(Gs0, Gs),
    format("~nBy category:~n"),
    format("  ~w~t~44|~w~t~52|~w~t~60|~w~t~68|~w~n", ['Category', 'N', 'Safe', 'Susp', 'Scam']),
    forall(member(G, Gs),
           ( findall(V, ( member(_-G-T, Grouped), analyse(T, _, V, _) ), Vs),
             length(Vs, N),
             aggregate_all(count, member(safe, Vs), A),
             aggregate_all(count, member(suspicious, Vs), B),
             aggregate_all(count, member(scam, Vs), C),
             format("  ~w~t~44|~w~t~52|~w~t~60|~w~t~68|~w~n", [G, N, A, B, C]) )).

indicator_counts(Label, Results) :-
    findall(N, ( member(Label-_-Ns, Results), member(N, Ns) ), All),
    msort(All, Sorted), clumped(Sorted, Pairs),
    sort(2, @>=, Pairs, ByCount),
    format("~nIndicators fired on ~w:~n", [Label]),
    forall(member(N-C, ByCount), format("  ~w~t~28|~w~n", [N, C])).

table(Label, Results) :-
    aggregate_all(count, member(Label-_-_, Results), N),
    (   N =:= 0 -> true
    ;   aggregate_all(count, member(Label-safe-_, Results), Safe),
        aggregate_all(count, member(Label-suspicious-_, Results), Sus),
        aggregate_all(count, member(Label-scam-_, Results), Scam),
        format("~w (~w):  safe ~w (~1f%)  suspicious ~w (~1f%)  scam ~w (~1f%)~n",
               [Label, N, Safe, 100*Safe/N, Sus, 100*Sus/N, Scam, 100*Scam/N])
    ).

show_first(Max, Label-Verdict, Results, Title) :-
    findall(T, member(Label-Verdict-T, Results), All),
    (   All == [] -> true
    ;   length(All, Total),
        format("~n~s (first ~w of ~w):~n", [Title, Max, Total]),
        ( length(First, Max), append(First, _, All) -> true ; First = All ),
        forall(member(T, First), show(T))
    ).

show(Text) :-
    analyse(Text, S, _, Rs),
    findall(N, member(reason(N, _, _, _, _), Rs), Ns),
    format("  [~2f] ~w~n        ~w~n", [S, Ns, Text]).
