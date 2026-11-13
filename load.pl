/*  Tahaffuz - console entry point

    swipl load.pl
    ?- explain("Your JazzCash account is blocked. Verify now: bit.ly/xy12 and send your OTP.").
    ?- analyse("...", Score, Verdict, Reasons).
*/
:- use_module(src/kb).
:- use_module(src/matcher).
:- use_module(src/inference).
:- use_module(src/explain).
:- use_module(src/diagnosis).
