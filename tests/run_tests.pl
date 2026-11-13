/*  Tahaffuz - tests

    swipl tests/run_tests.pl

    1. plunit unit tests for the matcher and inference engine
    2. a results table for every message in messages.pl

    Scoring:
      scam    message -> pass if scam;  suspicious = soft miss;  safe = miss
      genuine message -> pass if safe;  suspicious = soft FP;    scam = FP (worst)
*/
:- use_module(library(plunit)).
:- use_module('../src/kb').
:- use_module('../src/matcher').
:- use_module('../src/inference').
:- use_module('../src/explain').
:- use_module('../src/diagnosis').
:- use_module(messages).

:- initialization(main, main).

main :-
    ( run_tests -> true ; true ),
    report.

% ---------------------------------------------------------------
% Unit tests
% ---------------------------------------------------------------

fires(Msg, Name) :-
    fired_indicators(Msg, F), memberchk(fired(Name, _), F).

:- begin_tests(matcher).

test(whole_word_pin, [fail])     :- fires("Going shopping, send me your opinion", otp_request).
test(whole_word_fee, [fail])     :- fires("Pay for the coffee and send feedback", send_money).
test(otp_request)                :- fires("Please send your OTP now", otp_request).
test(negated_english, [fail])    :- fires("Do not share your OTP with anyone", otp_request).
test(negated_urdu, [fail])       :- fires("OTP kisi ko share na karein", otp_request).
test(negated_urdu_before, [fail]):- fires("Apna PIN kisi ko mat batayein", otp_request).
test(not_negated_dont_wait)      :- fires("Don't wait, send your OTP now", otp_request).
test(otp_to_confirm, [fail])     :- fires("1234 is your OTP to confirm the transaction", otp_request).
test(urdu_word_order)            :- fires("Apna OTP code humein bhejein", otp_request).
test(credential_request)         :- fires("Confirm your CNIC number today", credential_request).
test(password_changed, [fail])   :- fires("Your password was changed successfully", credential_request).
test(bare_short_link)            :- fires("Click bit.ly/xy12", shortened_link).
test(number_not_link, [fail])    :- fires("Total Rs 5.00 or 3,200", raw_link_present).
test(official_link, [fail])      :- fires("Track at daraz.pk/orders", raw_link_present).
test(lookalike_domain)           :- fires("Login at jazzcash-verify.xyz", suspicious_domain).
test(ubl_not_in_public, [fail])  :- fires("Read more at publicnews.com", suspicious_domain).
test(bill_not_send_money, [fail]):- fires("Please pay Rs 3,200 by the 28th", send_money).
test(bill_payment_mention)       :- fires("Please pay Rs 3,200 by the 28th", payment_mention).
test(pay_to_mobile)              :- fires("Send Rs 500 to 0300-1234567", send_money).
test(pay_via_short_link)         :- fires("Pay the fee at tinyurl.com/x", send_money).
test(mobile_number)              :- personal_mobile("03001234567"), personal_mobile("+923001234567").
test(statement_we_will, [fail])  :- fires("We will send you an OTP", otp_request).
test(statement_urdu, [fail])     :- fires("Main OTP bhej raha hoon", otp_request).
test(location_pin, [fail])       :- fires("Send me the location pin", otp_request).
test(your_pin)                   :- fires("Send your PIN now", otp_request).
test(wifi_password, [fail])      :- fires("Send me the wifi password", credential_request).
test(blocked_needs_account, [fail]) :- fires("I blocked him yesterday", account_blocked).
test(blocked_account)            :- fires("Your account is blocked", account_blocked).
test(receipt_not_payment, [fail]):- fires("Transfer of Rs 500 to 03001234567 successful", send_money).
test(unknown_com_not_risky, [fail]) :- fires("Pay Rs 500 at ticketwala.com", send_money).
test(risky_tld_payment)          :- fires("Pay Rs 500 at ticket-pk.xyz", send_money).
test(brand_promo_link, [fail])   :- fires("HBL card 20% off at khaadi.com", suspicious_domain).
test(email_not_link, [fail])     :- fires("Email support@hbl.com", raw_link_present).
test(brand_mobile)               :- fires("JazzCash helpline: call 03001234567", personal_number_bait).
test(pta_is_not_a_brand, [fail]) :- fires("Mujhe nahi pta, 03001234567 pe call karo", personal_number_bait).
test(cnic_copy, [fail])          :- fires("Please send your CNIC copy for the form", credential_request).
test(cnic_number)                :- fires("Send your CNIC number now", credential_request).
test(my_account_number, [fail])  :- fires("Should I send you my account number", credential_request).
test(your_account_number)        :- fires("Send me your account number", account_number_request).
test(account_number_weak, [fail]):- fires("Send me your account number", credential_request).
test(friend_account_number)      :- analyse("Send me your account number, I'll transfer the money", _, safe, _).
test(account_number_plus_pin)    :- analyse("Send your account number and PIN code now", _, scam, _).
test(urdu_will_pay, [fail])      :- fires("Main 500 rupay transfer kar deta hoon", payment_mention).
test(urdu_shared, [fail])        :- fires("Maine OTP share kar diya", otp_request).
test(we_will_send_money, [fail]) :- fires("We will send Rs 500 to 03001234567", send_money).
test(send_account_not_money, [fail]) :- fires("Account number bhej do, paise kal milenge", payment_mention).
test(urdu_style_english_verb)    :- fires("Foran 5000 rupay transfer karo 03001234567 par", send_money).
test(urdu_style_otp)             :- fires("Apna OTP send kar dein", otp_request).
test(prize_whatsapp_number)      :- fires("You won a prize! WhatsApp us at 03314447777", personal_number_bait).
test(blocked_call_number)        :- fires("Your ATM card is inactive. Call 03228413221", personal_number_bait).
test(friend_call_me, [fail])     :- fires("Call me at 03001234567 when you reach", personal_number_bait).
test(wa_me_link)                 :- fires("Job selected! Contact https://wa.me/03336787665 for prize", personal_number_bait).
test(ten_digit_mobile)           :- personal_mobile("3425319315").
test(youve_won)                  :- fires("You've won big money", prize_lottery).
test(we_need_pin)                :- fires("We need your ATM PIN urgently", otp_request).
test(we_have_sent, [fail])       :- fires("We have sent your OTP", otp_request).
test(fine_wine, [fail])          :- fires("Friendship is like a fine wine", threat_penalty).
test(guaranteed_lead, [fail])    :- fires("A lead is guaranteed with a strong partnership", too_good_offer).
test(ehsaas_brand)               :- fires("Your Ehsaas aid is approved, call 03445678901", personal_number_bait).
test(application_successful)     :- fires("Your Benazir Income Support application has been successful. WhatsApp 03095556666", personal_number_bait).
test(receipt_still_receipt, [fail]) :- fires("Transfer of Rs 500 to 03001234567 was successful", send_money).
test(card_restricted)            :- fires("Your ATM card usage has been restricted", account_blocked).
test(app_update, [fail])         :- fires("JazzCash app update available. Update now", wallet_brand_bait).
test(account_update)             :- fires("Update your JazzCash account now", wallet_brand_bait).
test(urgency_alone_safe)         :- analyse("Call me urgently", _, safe, _).

:- end_tests(matcher).

:- begin_tests(inference).

test(mycin_fold) :-
    combine_all([0.85, 0.6, 0.5], S),
    abs(S - 0.97) < 0.001.
test(order_independent) :-
    combine_all([0.85, 0.6, 0.5], A),
    combine_all([0.5, 0.85, 0.6], B),
    abs(A - B) < 1.0e-9.
% band/2 uses cuts, so test it with the band unbound
test(band_edges) :-
    band(0.3999, A), A == safe, band(0.40, B), B == suspicious,
    band(0.6999, C), C == suspicious, band(0.70, D), D == scam.
test(not_capped_below_scam_band, [fail]) :-
    capped(0.55, suspicious).
test(capped_in_scam_band) :-
    capped(0.94, suspicious).
test(gate_caps) :-
    verdict(0.71, [generic_greeting, too_good_offer, raw_link_present], suspicious).
test(gate_allows) :-
    verdict(0.71, [otp_request], scam).
test(contributions_sum) :-
    analyse("Your JazzCash account is blocked. Verify now: bit.ly/xy12 and send your OTP.", S, _, Rs),
    foldl([reason(_, _, C, _, _), A0, A]>>(A is A0 + C), Rs, 0, Sum),
    abs(Sum - S) < 0.001.

:- end_tests(inference).

types(Msg, Types) :- assess(Msg, _, _, _, Types, _, _).
action(Msg, A)    :- assess(Msg, _, _, _, _, action(A, _), _).

:- begin_tests(diagnosis).

test(otp_theft)       :- types("Please send your OTP now", [otp_theft|_]).
test(prize_fee)       :- types("You won a prize! Pay Rs 500 processing fee to claim", Ts), memberchk(prize_fee, Ts).
test(fake_helpline)   :- types("Your HBL card is blocked. Call 03012345678", Ts), memberchk(fake_helpline, Ts).
test(money_request)   :- types("Ammi foran 10,000 rupay bhej do 03451122334", [money_request|_]).
test(phishing_link)   :- types("Your account is blocked. Login at jazzcash-verify.xyz", Ts), memberchk(phishing_link, Ts).
test(safe_no_diagnosis) :- types("Hey, are we still meeting at 5?", []).
test(main_diagnosis_first) :-       % OTP theft outranks the account scare
    types("Your account is blocked. Send your OTP now", [otp_theft|_]).
test(action_scam)       :- action("Please send your OTP now", block_and_report).
test(action_suspicious) :- action("Dear customer, limited time offer, act now!", verify_first).
test(action_safe)       :- action("Ammi ne kaha hai doodh le aana", no_action).
test(always_advice) :-
    forall(member(M, ["Send your OTP", "Dear customer, act now!", "Hello"]),
           ( assess(M, _, _, _, _, _, Advice), Advice \== [] )).

:- end_tests(diagnosis).

% ---------------------------------------------------------------
% Results table
% ---------------------------------------------------------------

outcome(scam,    scam,       pass).
outcome(scam,    suspicious, soft_miss).
outcome(scam,    safe,       miss).
outcome(genuine, safe,       pass).
outcome(genuine, suspicious, soft_fp).
outcome(genuine, scam,       fp).

report :-
    format("~n~w~n", ['=== Message results ===']),
    format("~w~t~6|~w~t~15|~w~t~19|~w~t~28|~w~t~40|~w~t~47|~w~t~58|~w~n",
           ['Id', 'Set', 'Lng', 'Label', 'Verdict', 'Score', 'Result', 'Fired']),
    forall(test_message(Id, Label, Set, Lang, Text), row(Id, Label, Set, Lang, Text)),
    summary(tune),
    summary(holdout).

row(Id, Label, Set, Lang, Text) :-
    analyse(Text, Score, Verdict, Reasons),
    outcome(Label, Verdict, Result),
    findall(N, member(reason(N, _, _, _, _), Reasons), Names),
    atomic_list_concat(Names, ' ', Fired),
    ( Result == pass -> Mark = 'ok' ; Mark = Result ),
    format("~w~t~6|~w~t~15|~w~t~19|~w~t~28|~w~t~40|~2f~t~47|~w~t~58|~w~n",
           [Id, Set, Lang, Label, Verdict, Score, Mark, Fired]).

summary(Set) :-
    findall(L-R, ( test_message(_, L, Set, _, T),
                   analyse(T, _, V, _), outcome(L, V, R) ), Rs),
    count(scam-_, Rs, NS),     count(scam-pass, Rs, SP),
    count(scam-soft_miss, Rs, SSM), count(scam-miss, Rs, SM),
    count(genuine-_, Rs, NG),  count(genuine-pass, Rs, GP),
    count(genuine-soft_fp, Rs, GSF), count(genuine-fp, Rs, GF),
    format("~n--- ~w set ---~n", [Set]),
    format("Scam    (~w): caught ~w, soft miss ~w, missed ~w~n", [NS, SP, SSM, SM]),
    format("Genuine (~w): safe ~w, soft FP ~w, false positive (scam) ~w~n", [NG, GP, GSF, GF]).

count(Pattern, List, N) :-
    aggregate_all(count, member(Pattern, List), N).
