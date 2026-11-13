/*  Tahaffuz - Inference engine
    ---------------------------------------------------------------
    Combines certainty factors with the MYCIN formula for positive
    evidence, maps the score to a band, then applies the gate rule.

        combined = CF1 + CF2 * (1 - CF1)

    The formula is commutative and associative, so the final score does
    not depend on the order the indicators are combined in.
*/
:- module(inference, [
    combine/3,          % +CF1, +CF2, -CF
    combine_all/2,      % +CFs, -Score
    band/2,             % +Score, -Band
    verdict/3,          % +Score, +IndicatorNames, -Verdict
    capped/2            % +Score, +Verdict
]).
:- use_module(kb).

combine(CF1, CF2, CF) :-
    CF is CF1 + CF2 * (1 - CF1).

% fold over every fired CF, starting from 0
combine_all(CFs, Score) :-
    foldl(combine_step, CFs, 0, Score).

combine_step(CF, Acc0, Acc) :-
    combine(Acc0, CF, Acc).

band(S, safe)       :- S < 0.40, !.
band(S, suspicious) :- S < 0.70, !.
band(_, scam).

% Gate rule: "scam" needs at least one action indicator
% (asks for OTP, credentials, money, or links to a fake brand site).
% Without one, the verdict is capped at "suspicious".
verdict(Score, Names, Verdict) :-
    band(Score, Band),
    (   Band == scam, \+ has_action(Names)
    ->  Verdict = suspicious
    ;   Verdict = Band
    ).

has_action(Names) :-
    member(N, Names), action_indicator(N), !.

% the gate lowered the verdict.
% band/2 uses cuts, so it must be called with the band unbound:
% band(0.55, scam) would wrongly succeed through its last clause.
capped(Score, suspicious) :-
    band(Score, Band),
    Band == scam.
