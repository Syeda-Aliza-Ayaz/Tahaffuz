/*  Tahaffuz - Pattern matcher
    ---------------------------------------------------------------
    Decides which indicators are present in a message.
    Keyword / substring matching only - no NLP.

    Steps:
      1. normalise: lowercase, drop apostrophes (don't -> dont),
         split into sentences, split sentences into words
      2. find links (with or without http://)
      3. run each indicator's rule and collect the ones that fire
*/
:- module(matcher, [
    fired_indicators/2,     % +Message, -[fired(Name, Evidence)]
    normalise/2,            % +Message, -Sentences (list of word lists)
    link_host/2,            % +Word, -Host
    personal_mobile/1       % +Word
]).
:- use_module(kb).

% ctx(Sentences, Words, Text, Links)
%   Sentences : [[word, ...], ...]
%   Words     : all words in order
%   Text      : " word word ... "  (padded, for phrase search)
%   Links     : [link(Word, Host), ...]

fired_indicators(Message, Fired) :-
    context(Message, Ctx),
    findall(fired(Name, Evidence),
            ( indicator(Name, _, _), once(fires(Name, Ctx, Evidence)) ),
            Fired).

context(Message, ctx(Sentences, Words, Text, Links)) :-
    normalise(Message, Sentences),
    append(Sentences, Words),
    atomic_list_concat(Words, ' ', Joined),
    atomic_list_concat([' ', Joined, ' '], TextAtom),
    atom_string(TextAtom, Text),
    findall(link(W, H), ( member(W, Words), link_host(W, H) ), Links).

% ---------------------------------------------------------------
% Normalisation
% ---------------------------------------------------------------

normalise(Message, Sentences) :-
    string_lower(Message, Lower),
    string_chars(Lower, Chars0),
    exclude([C]>>memberchk(C, ['\'', '\x2019\']), Chars0, Chars1),
    sentence_breaks(Chars1, Chars2),
    string_chars(Marked, Chars2),
    split_string(Marked, "|", "", Parts),
    maplist(words, Parts, Sentences0),
    exclude(==([]), Sentences0, Sentences).

% Mark sentence ends with '|'. A dot only ends a sentence when a space
% follows it, so links like bit.ly/x stay in one piece.
% A comma + space becomes a clause-break word "¦" ("20,000" is untouched).
sentence_breaks([], []).
sentence_breaks(['.', C|T], ['|'|R]) :- char_type(C, space), !, sentence_breaks(T, R).
sentence_breaks([',', C|T], [' ', '¦', ' '|R]) :- char_type(C, space), !, sentence_breaks(T, R).
sentence_breaks([C|T], ['|'|R]) :- memberchk(C, ['!', '?', ';', '\n', '\r']), !, sentence_breaks(T, R).
sentence_breaks([C|T], [C|R]) :- sentence_breaks(T, R).

words(Sentence, Words) :-
    split_string(Sentence, " \t,()[]{}<>\"*", "", Raw),
    maplist(trim_word, Raw, Trimmed),
    exclude(==(""), Trimmed, Words).

% strip punctuation stuck to the ends of a word ("now:" -> "now")
trim_word(Raw, Word) :-
    split_string(Raw, "", ".:-!?+", [Word]).

% ---------------------------------------------------------------
% Matching helpers
% ---------------------------------------------------------------

% mentions(+Ctx, +Keyword): a phrase is searched in the text,
% a single word must equal a whole word.
mentions(ctx(_, Words, Text, _), Keyword) :-
    in_words(Words, Text, Keyword).

in_words(Words, Text, Keyword) :-
    (   sub_string(Keyword, _, _, _, " ")
    ->  string_concat(" ", Keyword, K1),
        string_concat(K1, " ", Padded),
        sub_string(Text, _, _, _, Padded)
    ;   memberchk(Keyword, Words)
    ).

% same check on a slice of a sentence
in_slice(Slice, Keyword) :-
    atomic_list_concat(Slice, ' ', J),
    atomic_list_concat([' ', J, ' '], TA),
    atom_string(TA, Text),
    in_words(Slice, Text, Keyword).

% ---------------------------------------------------------------
% Links
% ---------------------------------------------------------------

% link_host(+Word, -Host): Word looks like a link. Words with http://,
% https:// or www. always count; bare words need a known TLD.
link_host(Word, Host) :-
    \+ sub_string(Word, _, _, _, "@"),      % email address, not a link
    (   strip_prefix(Word, ["https://", "http://"], W1) -> Explicit = true
    ;   W1 = Word, Explicit = false
    ),
    (   strip_prefix(W1, ["www."], W2) -> Explicit2 = true
    ;   W2 = W1, Explicit2 = Explicit
    ),
    (   sub_string(W2, B, _, _, "/") -> sub_string(W2, 0, B, _, Host)
    ;   Host = W2
    ),
    split_string(Host, ".", "", Parts),
    Parts = [_, _|_],
    \+ memberchk("", Parts),
    (   Explicit2 == true -> true
    ;   last(Parts, Tld), link_tld(Tld)
    ).

strip_prefix(S, Prefixes, Rest) :-
    member(P, Prefixes),
    string_concat(P, Rest, S), !.

official_host(Host) :-
    ( brand(_, D) ; official_domain(D) ),
    same_or_subdomain(Host, D), !.
official_host(Host) :-
    official_suffix(Suffix),
    string_concat(_, Suffix, Host), !.

same_or_subdomain(Host, Host) :- !.
same_or_subdomain(Host, D) :-
    string_concat(".", D, DotD),
    string_concat(_, DotD, Host).

unofficial_link(ctx(_, _, _, Links), Host) :-
    member(link(_, Host), Links),
    \+ official_host(Host).

% risky link: hides its target, fakes a brand, or uses a cheap TLD
risky_link(Ctx, Host) :-
    unofficial_link(Ctx, Host),
    (   short_link_host(Host)
    ;   host_has_brand(Host, _)
    ;   risky_tld_host(Host)
    ), !.

risky_tld_host(Host) :-
    split_string(Host, ".", "", Parts),
    last(Parts, Tld),
    risky_tld(Tld).

% host contains a brand name: whole part ("hbl-secure.info"), or anywhere
% for long names ("jazzcashpk.com"). Short names like "ubl" only as a whole
% part, so "public.com" does not count.
host_has_brand(Host, Name) :-
    brand(B, _), atom_string(B, Name),
    (   split_string(Host, ".-", "", Parts), memberchk(Name, Parts)
    ;   string_length(Name, L), L >= 6, sub_string(Host, _, _, _, Name)
    ), !.

mentions_brand(Ctx, Alias) :-
    brand_alias(_, Alias),
    mentions(Ctx, Alias), !.

% ---------------------------------------------------------------
% Request rule (otp_request, credential_request)
% ---------------------------------------------------------------

% A request verb, not negated and not a statement, with a sensitive object
% on the correct side of it, all inside one sentence.
request(ctx(Sentences, _, _, _), Indicator, [Verb, Object]) :-
    member(S, Sentences),
    nth0(I, S, Verb),
    request_verb(Verb, Side),
    \+ not_a_request(S, I),
    sensitive_object(Indicator, Object),
    object_side(S, I, Side, Object, Slice),
    \+ owned(Slice, Object),
    \+ excepted(Slice, Object), !.

owned(Slice, Object) :-
    own_marker(M),
    atomic_list_concat([M, ' ', Object], P), atom_string(P, Phrase),
    in_slice(Slice, Phrase), !.

excepted(Slice, Object) :-
    object_exception(Object, Phrase),
    in_slice(Slice, Phrase), !.

% the word right before or after the verb cancels the request
not_a_request(S, I) :-
    neighbour(S, I, -1, W), ( negation(W) ; statement_before(W) ), !.
not_a_request(S, I) :-
    neighbour(S, I, 1, W), ( negation(W) ; statement_after(W) ), !.
not_a_request(S, I) :-                       % "transfer kar deta hoon"
    neighbour(S, I, 1, H), urdu_helper(H),
    neighbour(S, I, 2, W), statement_after(W), !.

neighbour(S, I, Offset, W) :-
    J is I + Offset,
    J >= 0,
    nth0(J, S, W).

% Slice = the words on the side of the verb where the object was found
object_side(S, I, Side0, Object, Slice) :-
    urdu_style(S, I, Side0, Side),
    side_slice(S, I, Side, Slice),
    in_slice(Slice, Object).

% English verb + Urdu helper ("send kar dein") takes Urdu word order
urdu_style(S, I, after, before) :-
    neighbour(S, I, 1, H), urdu_helper(H), !.
urdu_style(_, _, Side, Side).

side_slice(S, I, Side, Slice) :-
    length(Before, I),
    append(Before, [_|After], S),
    (   Side == after  -> Slice = After
    ;   Side == before -> Slice = Before
    ;   member(Slice, [After, Before])
    ).

% ---------------------------------------------------------------
% Payment
% ---------------------------------------------------------------

% payment verb (not negated / not a statement) + money word,
% unless the message is a receipt
payment_request(Ctx, [Verb, Money]) :-
    Ctx = ctx(Sentences, _, _, _),
    \+ is_receipt(Ctx),
    member(S, Sentences),
    nth0(I, S, Verb), payment_verb(Verb, Side0),
    \+ not_a_request(S, I),
    urdu_style(S, I, Side0, Side),
    side_slice(S, I, Side, Slice0),
    same_clause(Side, Slice0, Slice),
    member(Money, Slice), money_word_or_amount(Money), !.

% keep only the words up to the nearest clause break ("¦") from the verb:
% in "send me your account number, I'll transfer the money" the money
% belongs to the second clause, not to "send".
same_clause(after, Slice0, Slice) :-
    (   append(Slice, ["¦"|_], Slice0) -> true ; Slice = Slice0 ).
same_clause(before, Slice0, Slice) :-
    (   append(_, ["¦"|Slice], Slice0), \+ memberchk("¦", Slice) -> true ; Slice = Slice0 ).
same_clause(either, Slice, Slice).

is_receipt(Ctx) :-
    receipt_word(W), mentions(Ctx, W), !.

% a mobile number written out, or inside a WhatsApp link (wa.me/0333...)
mobile_number(ctx(_, Words, _, _), Number) :-
    member(W, Words),
    (   personal_mobile(W) -> Number = W
    ;   sub_string(W, B, _, _, "wa.me/"),
        Start is B + 6,
        sub_string(W, Start, _, 0, Number),
        personal_mobile(Number)
    ), !.

money_word_or_amount(W) :- money_word(W), !.
money_word_or_amount(W) :-               % "rs500", "rs.500"
    sub_string(W, 0, 2, _, "rs"),
    sub_string(W, 2, 1, _, C),
    ( C == "." ; char_type_digit(C) ), !.

char_type_digit(S) :- string_chars(S, [C]), char_type(C, digit(_)).

% personal_mobile(+Word): Pakistani mobile number, 03xxxxxxxxx or 923xxxxxxxxx
personal_mobile(Word) :-
    split_string(Word, "-", "+", Pieces),
    atomic_list_concat(Pieces, Digits0),
    atom_string(Digits0, Digits),
    string_chars(Digits, Cs),
    forall(member(C, Cs), char_type(C, digit(_))),
    string_length(Digits, Len),
    (   Len =:= 11, sub_string(Digits, 0, 2, _, "03")
    ;   Len =:= 12, sub_string(Digits, 0, 3, _, "923")
    ;   Len =:= 10, sub_string(Digits, 0, 1, _, "3")   % leading 0 dropped
    ), !.

% Why a payment request counts as a scam
payment_context(Ctx, Host)   :- risky_link(Ctx, Host), !.
payment_context(Ctx, Number) :- mobile_number(Ctx, Number), !.
payment_context(Ctx, Prize) :- fires(prize_lottery, Ctx, [Prize|_]), !.
payment_context(Ctx, Phrase) :-
    scam_payment_phrase(Phrase), mentions(Ctx, Phrase), !.

% ---------------------------------------------------------------
% fires(+Indicator, +Ctx, -Evidence)
% ---------------------------------------------------------------

fires(otp_request, Ctx, Ev)        :- request(Ctx, otp_request, Ev).
fires(credential_request, Ctx, Ev) :- request(Ctx, credential_request, Ev).
fires(account_number_request, Ctx, Ev) :- request(Ctx, account_number_request, Ev).

fires(send_money, Ctx, Ev) :-
    payment_request(Ctx, Pay),
    payment_context(Ctx, Why),
    append(Pay, [Why], Ev).

fires(payment_mention, Ctx, Ev) :-
    payment_request(Ctx, Ev),
    \+ fires(send_money, Ctx, _).

% fake-brand domain ("hbl-secure.info"), or a brand message linking to a
% cheap-TLD site. A brand message with a normal unknown link (a bank promo
% linking to a shop) is not enough.
fires(suspicious_domain, Ctx, [Host]) :-
    unofficial_link(Ctx, Host),
    \+ short_link_host(Host),
    (   host_has_brand(Host, _)
    ;   mentions_brand(Ctx, _), risky_tld_host(Host)
    ), !.

% A personal mobile number + a reason to call it: an official name
% (banks, wallets, BISP never use 03xx numbers - they use UAN / short
% codes), a prize, or an account problem. A friend writing "call me at
% 0300..." has none of these.
fires(personal_number_bait, Ctx, [Bait, Number]) :-
    mobile_number(Ctx, Number),
    \+ ( transaction_id_word(W), mentions(Ctx, W) ),
    (   mentions_brand(Ctx, Bait)
    ;   fires(prize_lottery, Ctx, [Bait|_])
    ;   fires(account_blocked, Ctx, [Bait|_])
    ), !.

fires(account_blocked, Ctx, [Word, Noun]) :-
    blocked_word(Word), mentions(Ctx, Word),
    account_noun(Noun), mentions(Ctx, Noun), !.

% brand + action word + account noun: "verify your JazzCash account",
% not "JazzCash app update available".
fires(wallet_brand_bait, Ctx, [Alias, Action, Noun]) :-
    mentions_brand(Ctx, Alias),
    Ctx = ctx(_, Words, _, _),
    member(Action, Words), brand_action(Action),
    account_noun(Noun), mentions(Ctx, Noun), !.

fires(shortened_link, ctx(_, _, _, Links), [Host]) :-
    member(link(_, Host), Links),
    short_link_host(Host), !.

fires(raw_link_present, Ctx, [Host]) :-
    unofficial_link(Ctx, Host),
    \+ short_link_host(Host),
    \+ fires(suspicious_domain, Ctx, _), !.

% every other indicator: plain keywords
fires(Name, Ctx, Evidence) :-
    keyword(Name, _),
    findall(K, ( keyword(Name, K), mentions(Ctx, K) ), Evidence),
    Evidence \== [].
