/*  Tahaffuz - Diagnosis and decision support
    ---------------------------------------------------------------
    The inference engine says HOW LIKELY a message is a scam. This module
    says WHICH KIND of scam it is (diagnosis) and WHAT THE USER SHOULD DO
    (decision support), like MYCIN naming the organism and recommending
    a treatment.

      fired indicators --diagnosis rules--> scam types
      verdict + scam types --decision rules--> recommended action + advice

    Facts here are expert knowledge, same as kb.pl; the diagnosis rules
    are the only logic.
*/
:- module(diagnosis, [
    diagnose/3,             % +Verdict, +IndicatorNames, -Types
    scam_type/3,            % ?Type, ?Name, ?Description
    decision_support/4      % +Verdict, +Types, -Action, -Advice
]).

% ---------------------------------------------------------------
% scam_type(Type, Name, Description) - listed in priority order:
% when several match, the first one is the main diagnosis.
% ---------------------------------------------------------------
scam_type(otp_theft,      'OTP / PIN theft',
          'Tries to get the one-time code or PIN that unlocks your bank account or wallet.').
scam_type(details_theft,  'Personal-details theft',
          'Asks for your CNIC number, card number, CVV or password.').
scam_type(prize_fee,      'Fake prize / lottery',
          'Says you have won something, then asks for a fee or a call to a personal number to claim it.').
scam_type(fake_helpline,  'Fake official helpline',
          'Pretends to be a bank, wallet or government programme and gives a personal mobile number.').
scam_type(money_request,  'Money request to a personal number or link',
          'Asks you to send money through a hidden link or to a personal number, often pretending to be a relative.').
scam_type(phishing_link,  'Phishing link',
          'Sends you to a fake or hidden website to steal your details.').
scam_type(account_scare,  'Account-blocked scare',
          'Claims your account, card or SIM is blocked so you panic and act fast.').
scam_type(too_good_offer, 'Too-good-to-be-true offer',
          'Promises easy money, free gifts or guaranteed profit - usually a job or investment scam.').

% ---------------------------------------------------------------
% Diagnosis rules: diagnosis(Type, Fired)
%   Fired = names of the indicators that fired for this message
% ---------------------------------------------------------------
diagnosis(otp_theft, F)      :- has(otp_request, F).
diagnosis(details_theft, F)  :- has(credential_request, F).
diagnosis(prize_fee, F)      :- has(prize_lottery, F),
                                ( has(send_money, F) ; has(personal_number_bait, F) ).
diagnosis(fake_helpline, F)  :- has(personal_number_bait, F), \+ has(prize_lottery, F).
diagnosis(money_request, F)  :- has(send_money, F), \+ has(prize_lottery, F).
diagnosis(phishing_link, F)  :- has(suspicious_domain, F).
diagnosis(phishing_link, F)  :- has(shortened_link, F),
                                ( has(account_blocked, F) ; has(wallet_brand_bait, F) ).
diagnosis(account_scare, F)  :- has(account_blocked, F).
diagnosis(too_good_offer, F) :- has(too_good_offer, F).

has(Indicator, Fired) :- memberchk(Indicator, Fired).

% A Safe message gets no diagnosis: there is nothing to diagnose.
diagnose(safe, _, []) :- !.
diagnose(_, Fired, Types) :-
    findall(T, ( scam_type(T, _, _), once(diagnosis(T, Fired)) ), Types).

% ---------------------------------------------------------------
% Decision support
% ---------------------------------------------------------------

% recommended_action(Verdict, Action, Text) - the decision table
recommended_action(scam,       block_and_report,
    'Do not reply, click, call or pay. Delete the message, block the sender and report it to your mobile operator.').
recommended_action(suspicious, verify_first,
    'Do not act on it yet. Check with the company or person through a number or app you already trust.').
recommended_action(safe,       no_action,
    'No scam signs found. No action needed.').

% advice(Type, Tip) - what to do for each kind of scam
advice(otp_theft,      'Never share an OTP or PIN with anyone. Banks, JazzCash, Easypaisa and BISP never ask for it.').
advice(otp_theft,      'If you already shared it, call your bank on the number printed on your card or in its app and block your account.').
advice(details_theft,  'Never send your CNIC number, card number, CVV or password by SMS or WhatsApp.').
advice(prize_fee,      'Real prizes never ask you to pay a fee or call a personal number to claim them.').
advice(fake_helpline,  'Official helplines use short codes or UAN numbers, never 03xx mobile numbers. BISP only messages from 8171.').
advice(fake_helpline,  'Call the official number from the card, app or website instead of the number in the message.').
advice(money_request,  'If someone says they are a relative on a new number, call them on their old number before sending anything.').
advice(phishing_link,  'Do not open the link. Type the official website address yourself or use the official app.').
advice(account_scare,  'Banks do not unblock accounts through SMS links or personal numbers. Check your account in the official app.').
advice(too_good_offer, 'Guaranteed earnings and free gifts are bait. Never pay a joining or registration fee.').

general_advice(safe,       'Even so, never share an OTP or PIN with anyone.').
general_advice(suspicious, 'If it claims to be from a bank or company, contact them through their official app or helpline.').
general_advice(scam,       'Never share an OTP or PIN with anyone.').

% decision_support(+Verdict, +Types, -action(Action, Text), -Advice)
% Advice = the tips for each diagnosed type (main diagnosis first),
% or a general tip when there is no diagnosis.
decision_support(Verdict, Types, action(Action, Text), Advice) :-
    recommended_action(Verdict, Action, Text),
    findall(Tip, ( member(T, Types), advice(T, Tip) ), Tips0),
    list_to_set(Tips0, Tips),
    (   Tips == []
    ->  general_advice(Verdict, G), Advice = [G]
    ;   Advice = Tips
    ).
