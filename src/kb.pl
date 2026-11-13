/*  Tahaffuz - Knowledge base
    ---------------------------------------------------------------
    Facts only, no logic. Everything the expert "knows" lives here.

    To add a trigger word:   add one keyword/2 fact.
    To add a new indicator:  add indicator/3 (+ action_indicator/1 if it
                             is a direct request), then its keywords.

    All text is lowercase. A keyword with a space is a phrase; a keyword
    without a space must match a whole word.
*/
:- module(kb, [
    indicator/3, action_indicator/1,
    keyword/2, blocked_word/1, account_noun/1, sensitive_object/2,
    request_verb/2, negation/1, statement_before/1, statement_after/1,
    own_marker/1, object_exception/2, urdu_helper/1,
    payment_verb/2, money_word/1, scam_payment_phrase/1, receipt_word/1,
    transaction_id_word/1,
    brand/2, brand_alias/2, brand_action/1,
    official_domain/1, official_suffix/1,
    short_link_host/1, link_tld/1, risky_tld/1
]).

% ---------------------------------------------------------------
% indicator(Name, CF, Reason)
% ---------------------------------------------------------------
indicator(otp_request,        0.85, 'Asks you to share your OTP / PIN').
indicator(credential_request, 0.80, 'Requests sensitive personal or bank details').
indicator(send_money,         0.75, 'Asks you to pay through a hidden link, a personal number, or to unlock a prize').
indicator(suspicious_domain,  0.70, 'Link points to an unofficial / look-alike domain').
indicator(account_blocked,    0.70, 'Claims your account is blocked or suspended').
indicator(wallet_brand_bait,  0.70, 'Uses a bank / mobile-wallet name to make you act').
indicator(personal_number_bait, 0.70, 'Uses a prize, an account problem or an official name to make you contact a personal mobile number').
indicator(prize_lottery,      0.65, 'Prize / lottery bait').
indicator(shortened_link,     0.60, 'Uses a shortened link that hides where it goes').
indicator(threat_penalty,     0.55, 'Threatens a penalty to pressure you').
indicator(urgency,            0.35, 'Creates false urgency').   % brief: 0.50; alone it's not evidence ("call me urgently")
indicator(too_good_offer,     0.45, 'Offer that is too good to be true').
indicator(generic_greeting,   0.30, 'Generic, impersonal greeting').
indicator(spelling_errors,    0.30, 'Spelling mistakes in common or brand words').
indicator(payment_mention,    0.30, 'Mentions a payment').
indicator(account_number_request, 0.30, 'Asks for your bank account number').
indicator(raw_link_present,   0.25, 'Contains a link to an unknown website').

% Action indicators: the message directly asks for something of value.
% Gate rule: a "Scam" verdict needs at least one of these.
action_indicator(otp_request).
action_indicator(credential_request).
action_indicator(send_money).
action_indicator(suspicious_domain).
action_indicator(personal_number_bait).

% ---------------------------------------------------------------
% account_blocked = a blocked word + an account noun anywhere in the
% message, so "I blocked him" or "I locked the keys" don't count.
% ---------------------------------------------------------------
blocked_word("blocked").
blocked_word("suspended").
blocked_word("deactivated").
blocked_word("locked").
blocked_word("disabled").
blocked_word("frozen").
blocked_word("inactive").
blocked_word("deactivation").
blocked_word("inaccessible").
blocked_word("restricted").
blocked_word("halted").
blocked_word("on hold").
blocked_word("verify to restore").
blocked_word("band ho").                        % Roman Urdu: will be closed
blocked_word("band kar").
blocked_word("bandh ho").
blocked_word("block ho").
blocked_word("block kar").
blocked_word("bahal").                          % restore
blocked_word("bahaal").
blocked_word("muattal").                        % suspended
blocked_word("moattal").

account_noun("account").
account_noun("card").
account_noun("sim").
account_noun("wallet").
account_noun("number").
account_noun("profile").
account_noun("id").
account_noun("connection").
account_noun("subscription").
account_noun("membership").
account_noun("kyc").
account_noun("khata").                          % Roman Urdu: account

% ---------------------------------------------------------------
% keyword(Indicator, Phrase)  - plain keyword indicators
% Each keyword belongs to exactly one indicator.
% ---------------------------------------------------------------

% prize_lottery
% "congratulations" alone is not here: friends say it too ("congratulations
% on your new job"). Prize scams almost always also say won / winner / draw.
keyword(prize_lottery, "winner").
keyword(prize_lottery, "winners").
keyword(prize_lottery, "winnings").
keyword(prize_lottery, "you have won").
keyword(prize_lottery, "youve won").            % "you've won" (apostrophe removed)
keyword(prize_lottery, "you won").
keyword(prize_lottery, "has won").
keyword(prize_lottery, "number won").
keyword(prize_lottery, "prizes").
keyword(prize_lottery, "awarded").
keyword(prize_lottery, "selected to receive").
keyword(prize_lottery, "number is selected").
keyword(prize_lottery, "lucky pick").
keyword(prize_lottery, "you have been selected").
keyword(prize_lottery, "number has been selected").
keyword(prize_lottery, "lucky draw").
keyword(prize_lottery, "lottery").
keyword(prize_lottery, "jackpot").
keyword(prize_lottery, "prize").
keyword(prize_lottery, "inaam").                % Roman Urdu: prize
keyword(prize_lottery, "inam").
keyword(prize_lottery, "inaami").
keyword(prize_lottery, "jeet liya").            % have won
keyword(prize_lottery, "jeet liye").
keyword(prize_lottery, "jeet gaye").
keyword(prize_lottery, "jeeta hai").
keyword(prize_lottery, "qurandazi").            % lucky draw
keyword(prize_lottery, "qura andazi").

% threat_penalty
keyword(threat_penalty, "legal action").
keyword(threat_penalty, "penalty").
keyword(threat_penalty, "pay a fine").         % not "a fine": "like a fine wine"
keyword(threat_penalty, "fine of").
keyword(threat_penalty, "heavy fine").
keyword(threat_penalty, "will be closed").
keyword(threat_penalty, "permanently closed").
keyword(threat_penalty, "arrest").
keyword(threat_penalty, "warrant").
keyword(threat_penalty, "court case").
keyword(threat_penalty, "jurmana").             % Roman Urdu: fine
keyword(threat_penalty, "jurmaana").
keyword(threat_penalty, "qanooni karwai").      % legal action
keyword(threat_penalty, "qanuni karwai").
keyword(threat_penalty, "qanooni karrwai").

% urgency
keyword(urgency, "urgent").
keyword(urgency, "urgently").
keyword(urgency, "immediately").
keyword(urgency, "act now").
keyword(urgency, "within 24 hours").
keyword(urgency, "within 24 hrs").
keyword(urgency, "within 48 hours").
keyword(urgency, "last warning").
keyword(urgency, "final warning").
keyword(urgency, "expires today").
keyword(urgency, "asap").
keyword(urgency, "foran").                      % Roman Urdu: immediately
keyword(urgency, "fauran").
keyword(urgency, "foraan").
keyword(urgency, "24 ghante").                  % 24 hours
keyword(urgency, "24 ghanton").

% too_good_offer
keyword(too_good_offer, "100% guaranteed").
keyword(too_good_offer, "guaranteed profit").  % not bare "guaranteed"
keyword(too_good_offer, "guaranteed income").
keyword(too_good_offer, "guaranteed return").
keyword(too_good_offer, "double your money").
keyword(too_good_offer, "double amount").
keyword(too_good_offer, "as a double").
keyword(too_good_offer, "with the double").
keyword(too_good_offer, "cash reward").
keyword(too_good_offer, "free gift").
keyword(too_good_offer, "free iphone").
keyword(too_good_offer, "free laptop").
keyword(too_good_offer, "free bike").
keyword(too_good_offer, "risk free").
keyword(too_good_offer, "earn money from home").
keyword(too_good_offer, "daily income").
keyword(too_good_offer, "muft").                % Roman Urdu: free
keyword(too_good_offer, "muft mein").
keyword(too_good_offer, "bilkul muft").
keyword(too_good_offer, "paisay double").       % money doubled
keyword(too_good_offer, "raqam double").

% generic_greeting
keyword(generic_greeting, "dear customer").
keyword(generic_greeting, "dear user").
keyword(generic_greeting, "dear member").
keyword(generic_greeting, "dear client").
keyword(generic_greeting, "dear valued customer").
keyword(generic_greeting, "dear account holder").
keyword(generic_greeting, "mohtaram sarif").    % Roman Urdu: respected customer
keyword(generic_greeting, "mohtaram saarif").
keyword(generic_greeting, "piyare sarif").

% spelling_errors - a fixed list of known misspellings, not a spell-checker
keyword(spelling_errors, "acount").
keyword(spelling_errors, "accout").
keyword(spelling_errors, "verfy").
keyword(spelling_errors, "verifiy").
keyword(spelling_errors, "pasword").
keyword(spelling_errors, "passwrd").
keyword(spelling_errors, "jazcash").
keyword(spelling_errors, "easypesa").
keyword(spelling_errors, "esaypaisa").
keyword(spelling_errors, "recieve").
keyword(spelling_errors, "recieved").
keyword(spelling_errors, "suspened").
keyword(spelling_errors, "immediatly").
keyword(spelling_errors, "informaton").
keyword(spelling_errors, "tranfer").
keyword(spelling_errors, "wining").
keyword(spelling_errors, "verificaton").

% ---------------------------------------------------------------
% Request rules: request verb + sensitive object, not negated
% ---------------------------------------------------------------

% sensitive_object(Indicator, Phrase)
% Bare "pin" and "password" are not here: "send me the location pin" and
% "send me the wifi password" are normal. Only the owned / bank forms count.
sensitive_object(otp_request, "otp").
sensitive_object(otp_request, "mpin").
sensitive_object(otp_request, "pin code").
sensitive_object(otp_request, "pin number").
sensitive_object(otp_request, "your pin").
sensitive_object(otp_request, "apna pin").
sensitive_object(otp_request, "apni pin").
sensitive_object(otp_request, "atm pin").
sensitive_object(otp_request, "card pin").
sensitive_object(otp_request, "one-time password").
sensitive_object(otp_request, "one time password").
sensitive_object(otp_request, "verification code").
sensitive_object(otp_request, "security code").
sensitive_object(otp_request, "digit code").            % "the 6 digit code"
sensitive_object(otp_request, "code sent to").          % "the code sent to your phone"
sensitive_object(otp_request, "code we sent").

sensitive_object(credential_request, "your password").
sensitive_object(credential_request, "apna password").
sensitive_object(credential_request, "account password").
sensitive_object(credential_request, "login password").
sensitive_object(credential_request, "bank password").
sensitive_object(credential_request, "cnic").
% Account number is weak on its own: it only lets someone pay you, which is
% why friends ask for it ("send me your account number, I'll transfer").
% It adds to other evidence but can't make a Scam verdict alone.
sensitive_object(account_number_request, "account number").
sensitive_object(account_number_request, "account no").
sensitive_object(account_number_request, "iban").
sensitive_object(credential_request, "card number").
sensitive_object(credential_request, "cvv").
sensitive_object(credential_request, "cvc").
sensitive_object(credential_request, "card details").
sensitive_object(credential_request, "bank details").
sensitive_object(credential_request, "login details").
sensitive_object(credential_request, "shanakhti card").   % Roman Urdu: ID card

% request_verb(Verb, Side) - Side says where the object must appear.
%   after : English word order, verb then object   ("send your OTP")
%   before: Urdu word order, object then verb      ("OTP bhejein")
%   either: used both ways                         ("share your OTP" / "OTP share karein")
% "enter", "verify" and "update" are deliberately NOT here:
% real bank OTPs say "enter this code" / "OTP to verify".
request_verb("send",     after).
request_verb("provide",  after).
request_verb("confirm",  after).
request_verb("tell",     after).
request_verb("give",     after).
request_verb("submit",   after).
request_verb("forward",  after).
request_verb("reply",    after).
request_verb("need",     after).                % "we need your ATM PIN"
request_verb("require",  after).
request_verb("sharing",  after).                % "by sharing your account number"
request_verb("sending",  after).
request_verb("providing", after).
request_verb("giving",   after).
request_verb("share",    either).
request_verb("bhejein",  before).               % Roman Urdu: send
request_verb("bhejen",   before).
request_verb("bhejo",    before).
request_verb("bhej",     before).
request_verb("batayein", before).               % tell
request_verb("bataen",   before).
request_verb("batain",   before).
request_verb("batao",    before).
request_verb("dein",     before).               % give
request_verb("dijiye",   before).

% negation(Word) - checked immediately before or after the verb
negation("not").
negation("never").
negation("dont").
negation("na").                                 % Roman Urdu
negation("nahi").
negation("nahin").
negation("mat").

% A verb is a statement, not a request, when it follows "will"/"have"/"am"
% ("we will send you an OTP") or, in Urdu, is followed by a tense word.
% Not "we": "we need your PIN" is a request.
% ("OTP bhej raha hoon" = I am sending the OTP).
statement_before("will").
statement_before("shall").
statement_before("would").
statement_before("well").                       % we'll (apostrophe removed)
statement_before("ill").                        % I'll
statement_before("am").                         % "I am sending", "we have sent"
statement_before("im").
statement_before("is").
statement_before("are").
statement_before("was").
statement_before("were").
statement_before("have").
statement_before("has").
statement_before("had").
statement_before("ive").
statement_before("weve").
statement_after("raha").                        % Roman Urdu: -ing
statement_after("rahi").
statement_after("rahe").
statement_after("diya").                        % did / have sent
statement_after("diye").
statement_after("chuka").                       % already
statement_after("chuki").
statement_after("dunga").                       % will
statement_after("dungi").
statement_after("deta").                        % "bhej deta hoon" = I'll send
statement_after("deti").
statement_after("dete").

% helper verb skipped when looking for the tense word:
% "transfer kar deta hoon", "share kar diya"
% An English verb followed by one of these is used Urdu-style, so its
% object comes before it: "paise transfer karo", "OTP send kar dein".
urdu_helper("kar").
urdu_helper("kr").
urdu_helper("karo").
urdu_helper("karein").
urdu_helper("karen").
urdu_helper("krein").
urdu_helper("kardo").
urdu_helper("kardein").
urdu_helper("kijiye").

% "my account number" / "mera CNIC" = the sender offering their own
% details, not asking for yours.
own_marker("my").
own_marker("mera").
own_marker("meri").
own_marker("mere").

% object_exception(Object, Phrase): Phrase means the object is not a
% credential request. A CNIC *copy* is a normal document request
% (jobs, forms); scams ask for the CNIC *number* with a PIN / OTP.
object_exception("cnic", "cnic copy").
object_exception("cnic", "copy of cnic").
object_exception("cnic", "copy of your cnic").
object_exception("cnic", "cnic ki copy").
object_exception("cnic", "cnic picture").
object_exception("cnic", "cnic pic").
object_exception("cnic", "cnic photo").
object_exception("cnic", "cnic scan").

% ---------------------------------------------------------------
% Payment
% payment_verb(Verb, Side): the money word must be on that side of the
% verb, same as request_verb ("pay Rs 500" / "500 rupay bhejein").
% ---------------------------------------------------------------
payment_verb("pay", after).
payment_verb("send", after).
payment_verb("transfer", after).
payment_verb("deposit", after).
payment_verb("depositing", after).              % "by depositing Rs 5000"
payment_verb("sending", after).
payment_verb("paying", after).
payment_verb("bhejein", before).                        % Roman Urdu: send
payment_verb("bhejen", before).
payment_verb("bhejo", before).
payment_verb("bhej", before).
payment_verb("jama", before).                           % deposit ("jama karwayen")
payment_verb("ada", before).                            % pay ("ada karein")

money_word("rs").
money_word("pkr").
money_word("rupees").
money_word("rupay").
money_word("fee").
money_word("fees").
money_word("charges").
money_word("amount").
money_word("payment").
money_word("balance").
money_word("raqam").                            % Roman Urdu: amount
money_word("rakam").
money_word("paisay").
money_word("paise").
money_word("money").
money_word("cash").
money_word("lakh").                             % 1 lakh = 100,000
money_word("lac").

% Phrases that make a payment request a scam on their own
scam_payment_phrase("processing fee").
scam_payment_phrase("registration fee").
scam_payment_phrase("activation fee").
scam_payment_phrase("clearance fee").
scam_payment_phrase("customs fee").
scam_payment_phrase("pay to claim").
scam_payment_phrase("to claim").

% A receipt reports a payment, it doesn't ask for one
% ("Transfer of Rs 500 to 0300... was successful").
receipt_word("successful").
receipt_word("successfully").
receipt_word("tid").
receipt_word("trx id").
receipt_word("transaction id").

% A transaction ID is the stronger sign of a real receipt. Only this
% cancels personal_number_bait: "your application has been successful,
% WhatsApp us at 0309..." is a BISP scam, not a receipt.
transaction_id_word("tid").
transaction_id_word("trx id").
transaction_id_word("transaction id").

% ---------------------------------------------------------------
% Brands, official domains, links
% ---------------------------------------------------------------

% brand(Name, OfficialDomain) - a brand may have several domains
brand(jazzcash,  "jazzcash.com.pk").
brand(easypaisa, "easypaisa.com.pk").
brand(sadapay,   "sadapay.pk").
brand(nayapay,   "nayapay.com").
brand(hbl,       "hbl.com").
brand(meezan,    "meezanbank.com").
brand(ubl,       "ubldigital.com").
brand(ubl,       "ubl.com.pk").
brand(mcb,       "mcb.com.pk").
brand(alfalah,   "bankalfalah.com").
brand(bisp,      "bisp.gov.pk").                % government bodies often impersonated
brand(nadra,     "nadra.gov.pk").
brand(pta,       "pta.gov.pk").
brand(fbr,       "fbr.gov.pk").
brand(sbp,       "sbp.org.pk").                 % State Bank of Pakistan
brand(ary,       "arydigital.tv").              % "Jeeto Pakistan" prize-show scams

% brand_alias(Name, HowItIsWritten)
brand_alias(jazzcash,  "jazzcash").
brand_alias(jazzcash,  "jazz cash").
brand_alias(easypaisa, "easypaisa").
brand_alias(easypaisa, "easy paisa").
brand_alias(sadapay,   "sadapay").
brand_alias(nayapay,   "nayapay").
brand_alias(hbl,       "hbl").
brand_alias(meezan,    "meezan").
brand_alias(ubl,       "ubl").
brand_alias(mcb,       "mcb").
brand_alias(alfalah,   "alfalah").
brand_alias(bisp,      "bisp").
brand_alias(bisp,      "benazir income support").
brand_alias(bisp,      "benazir").
brand_alias(bisp,      "ehsaas").               % Ehsaas programme
brand_alias(bisp,      "8171").                 % official BISP short code
brand_alias(sbp,       "state bank").
brand_alias(ary,       "jeeto pakistan").
brand_alias(nadra,     "nadra").
% no alias for pta: "pta" is also Roman Urdu for "pata" (mujhe nahi pta)
brand_alias(fbr,       "fbr").

% Words that turn a brand mention into bait.
% "confirm" is left out: genuine wallet OTPs say "to confirm your transaction".
brand_action("verify").
brand_action("update").
brand_action("activate").
brand_action("reactivate").
brand_action("unblock").
brand_action("restore").
brand_action("tasdeeq").                        % Roman Urdu: verify
brand_action("tasdiq").

% Trusted non-brand sites (links to these are not counted as links)
official_domain("daraz.pk").
official_domain("foodpanda.pk").
official_domain("careem.com").
official_domain("tcs.com.pk").
official_domain("leopardscourier.com").
official_domain("ke.com.pk").
official_domain("ptcl.com.pk").
official_domain("jazz.com.pk").
official_domain("zong.com.pk").
official_domain("telenor.com.pk").
official_suffix(".gov.pk").
official_suffix(".edu.pk").

short_link_host("bit.ly").
short_link_host("tinyurl.com").
short_link_host("cutt.ly").
short_link_host("t.ly").
short_link_host("rebrand.ly").
short_link_host("is.gd").
short_link_host("goo.gl").
short_link_host("shorturl.at").
short_link_host("t.co").
short_link_host("ow.ly").

% TLDs that make a bare token (no http://) count as a link
link_tld("com").  link_tld("pk").    link_tld("net").  link_tld("org").
link_tld("info"). link_tld("xyz").   link_tld("top").  link_tld("site").
link_tld("online"). link_tld("link"). link_tld("ly").  link_tld("me").
link_tld("co").   link_tld("io").    link_tld("click"). link_tld("gd").
link_tld("gl").   link_tld("cc").    link_tld("live"). link_tld("app").
link_tld("biz").  link_tld("shop").  link_tld("store"). link_tld("vip").
link_tld("icu").  link_tld("at").    link_tld("in").   link_tld("uk").

% Cheap TLDs popular with phishing sites. An unknown .com is just a link;
% an unknown .xyz / .top used to collect payment is a red flag.
risky_tld("xyz").  risky_tld("top").  risky_tld("site").  risky_tld("online").
risky_tld("info"). risky_tld("click"). risky_tld("icu").  risky_tld("vip").
risky_tld("live"). risky_tld("shop"). risky_tld("cc").   risky_tld("link").
