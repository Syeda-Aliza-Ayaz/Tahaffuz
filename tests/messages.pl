/*  Tahaffuz - labelled test messages
    ---------------------------------------------------------------
    test_message(Id, Label, Set, Lang, Text)
      Label : scam | genuine
      Set   : tune    - may be used while adjusting CFs / keywords
              holdout - never tuned against; reported separately
      Lang  : en | ur (Roman Urdu)

    Source: messages are hand-written for this project, modelled on
    common Pakistani scam patterns (wallet/bank impersonation, BISP,
    parcel/customs, "relative in trouble", prize draws) and on typical
    genuine bank, wallet, delivery and personal messages. Names,
    numbers and links are made up. The first 4 scams and 3 genuine
    messages are from the project brief.
*/
:- module(test_messages, [test_message/5]).

% ---------------- Scam, English ----------------
test_message(s01, scam, tune, en, "Your JazzCash account is blocked. Verify now: bit.ly/xy12 and send your OTP.").
test_message(s02, scam, tune, en, "Congratulations! You won Rs 50,000 in the lucky draw. Pay Rs 500 processing fee to claim.").
test_message(s03, scam, tune, en, "Dear customer, your HBL account will be closed. Confirm your CNIC and PIN immediately.").
test_message(s04, scam, tune, en, "URGENT: your parcel is held. Pay customs fee at tinyurl.com/abc within 24 hours.").
test_message(s05, scam, tune, en, "Dear Easypaisa user, your account has been suspended due to incomplete KYC. Update now at easypaisa-kyc.com to avoid permanent closure.").
test_message(s06, scam, holdout, en, "HBL Alert: Unusual login detected. Verify your identity at hbl-secure-login.info within 24 hours or your card will be blocked.").
test_message(s07, scam, tune, en, "Your Meezan Bank debit card will expire today. Reply with your card number and CVV to renew.").
test_message(s08, scam, tune, en, "Assalam o Alaikum, I am calling from JazzCash head office. You have won Rs 25,000 in our lucky draw. Send your MPIN to claim your prize.").
test_message(s09, scam, tune, en, "Pakistan Post: Your package could not be delivered due to an incomplete address. Pay Rs 150 redelivery charges at pakpost-track.top").
test_message(s10, scam, tune, en, "Congratulations! Your mobile number has been selected for a free iPhone 15. Pay Rs 999 delivery charges to 03451234567 to receive it.").
test_message(s11, scam, holdout, en, "FBR Notice: You have a pending tax refund of Rs 18,750. Submit your CNIC and bank account number at fbr-refund.online to receive it.").
test_message(s12, scam, tune, en, "Earn Rs 5000 daily income from home! 100% guaranteed. Join now: bit.ly/earnpk").
test_message(s13, scam, tune, en, "Dear user, your SIM will be blocked within 24 hours due to PTA biometric re-verification. Call 03001112233 immediately.").
test_message(s14, scam, tune, en, "Your NADRA CNIC has been flagged. To avoid legal action, provide your CNIC number and mother's name immediately.").
test_message(s15, scam, tune, en, "Hi mum, I lost my phone, this is my new number. Please send Rs 20,000 urgently to 03219876543, I will explain later.").
test_message(s16, scam, tune, en, "UBL: Your account has been temporarily locked. Click https://ubl-verify.co to unlock and keep your funds safe.").
test_message(s17, scam, holdout, en, "Amazon: your order #4421 was charged $499. If this wasn't you, call our refund desk and share the one-time password we send you.").
test_message(s18, scam, tune, en, "Win a brand new Honda bike! Lucky draw winners announced. Register with Rs 300 registration fee via JazzCash to 03001234567.").
test_message(s19, scam, tune, en, "Your Netflix subscription has been suspended. Update your payment details at netflix-billing-help.com").
test_message(s20, scam, tune, en, "Final warning: unpaid traffic challan of Rs 2,500. Pay now at echallan-pk.site or face a fine of Rs 10,000 and vehicle impound.").
test_message(s21, scam, holdout, en, "Investment opportunity: double your money in 30 days. Deposit Rs 10,000 to account 0301-5556677 and receive Rs 20,000.").
test_message(s22, scam, tune, en, "Dear customer, kindly share the 6 digit code sent to your phone to complete the verification of your account.").
test_message(s23, scam, tune, en, "Your Daraz account has been compromised. Confirm your password at daraz-security.xyz now.").
test_message(s24, scam, tune, en, "Telenor: You have won 50GB free internet. To claim, send your PIN code to 7337.").

% ---------------- Scam, Roman Urdu ----------------
test_message(u01, scam, tune, ur, "Mubarak ho! Aap ka number Jazz lucky draw mein select hua hai. Aap ne 50,000 inaam jeet liya hai. Apna inaam hasil karne ke liye 500 rupay processing fee 03001234567 par bhejein.").
test_message(u02, scam, tune, ur, "Mohtaram sarif, aap ka JazzCash account band ho jayega. Foran apna PIN code aur CNIC number humein bhejein.").
test_message(u03, scam, tune, ur, "BISP 8171: Aap ki 25,000 ki raqam aa gayi hai. Raqam hasil karne ke liye apna CNIC aur OTP code is number par batayein 03111234567.").
test_message(u04, scam, tune, ur, "Aap ka Easypaisa account muattal kar diya gaya hai. Bahal karne ke liye is link par click karein: easypaisa-bahal.com").
test_message(u05, scam, holdout, ur, "Ammi main naye number se baat kar raha hoon, mera phone kho gaya. Foran 10,000 rupay is number pe bhej do 03451122334, bohat zaroori hai.").
test_message(u06, scam, tune, ur, "Aap ka parcel custom mein ruka hua hai. 24 ghante mein 1,200 rupay clearance fee jama karwayen warna parcel wapis chala jayega. Link: tinyurl.com/pkparcel").
test_message(u07, scam, tune, ur, "Ghar baithe rozana 3000 rupay kamayein! Bilkul muft registration. Abhi join karein: bit.ly/kamaipk").
test_message(u08, scam, holdout, ur, "Aap ke HBL card par qanooni karwai ho sakti hai. Apna card number aur pin code humein SMS kar dein.").

% ---------------- Genuine, English ----------------
test_message(g01, genuine, tune, en, "Hey, are we still meeting at 5 for the project?").
test_message(g02, genuine, tune, en, "Your Careem ride with Ali has arrived.").
test_message(g03, genuine, tune, en, "Reminder: your electricity bill of Rs 3,200 is due on the 28th.").
test_message(g04, genuine, tune, en, "Your OTP is 4821. Do not share it with anyone.").
test_message(g05, genuine, tune, en, "Use 739201 as your one-time password to confirm the transaction of Rs 5,000 at Daraz. Never share your OTP with anyone.").
test_message(g06, genuine, tune, en, "JazzCash: You have received Rs 2,500 from Ahmed Khan (0300****567). Your new balance is Rs 7,830.").
test_message(g07, genuine, tune, en, "Dear Customer, your Jazz balance is low. Recharge now to continue enjoying our services.").
test_message(g08, genuine, tune, en, "Your Daraz order #10293 has been shipped and will be delivered by TCS within 3 days. Track at daraz.pk/orders").
test_message(g09, genuine, tune, en, "K-Electric: Your bill of Rs 4,560 for October is due on 15 Nov. Pay via the KE app or at ke.com.pk to avoid late payment surcharge.").
test_message(g10, genuine, tune, en, "Can you send me the notes from today's lecture?").
test_message(g11, genuine, tune, en, "Congratulations on your new job! So proud of you.").
test_message(g12, genuine, holdout, en, "Your HBL debit card ending 4421 was used for Rs 3,450 at Imtiaz Supermarket. If this was not you, call 111-111-425.").
test_message(g13, genuine, tune, en, "Reminder: Your dentist appointment is tomorrow at 4 pm. Reply C to confirm or R to reschedule.").
test_message(g14, genuine, tune, en, "Your Careem verification code is 5521. Do not share it.").
test_message(g15, genuine, tune, en, "Meeting moved to 3 pm, please send the updated slides before then.").
test_message(g16, genuine, tune, en, "foodpanda: Your order from Student Biryani is on the way! Rider: Imran.").
test_message(g17, genuine, tune, en, "Hey, I transferred Rs 1,500 for the dinner yesterday, check your account.").
test_message(g18, genuine, holdout, en, "Your PTCL bill is ready. Amount due: Rs 2,199. Pay before 20 Nov at ptcl.com.pk to avoid disconnection.").
test_message(g19, genuine, tune, en, "Bank Alfalah: Your account statement for October is now available in the Alfalah app.").
test_message(g20, genuine, tune, en, "Dear Student, the IAI quiz will be held on Monday. Please bring your university ID card.").
test_message(g21, genuine, holdout, en, "Please pay the rent of Rs 45,000 by the 5th into the usual account.").
test_message(g22, genuine, holdout, en, "Limited time offer: get 50% off on all shoes at our store. Visit https://www.servis.com").

% ---------------- Genuine, Roman Urdu ----------------
test_message(r01, genuine, tune, ur, "Kal university kitne baje pohanchna hai? Mujhe bata dena.").
test_message(r02, genuine, tune, ur, "Ammi ne kaha hai ghar aate hue doodh le aana.").
test_message(r03, genuine, tune, ur, "JazzCash: Aap ke account mein Rs 3,000 Ali Raza ki taraf se aa gaye hain.").
test_message(r04, genuine, tune, ur, "Apna OTP kisi ko na batayein. JazzCash kabhi bhi aap se OTP nahi mangta.").
test_message(r05, genuine, holdout, ur, "Yaar mujhe 500 rupay bhej do easypaisa pe, kal wapis kar doon ga.").
test_message(r06, genuine, holdout, ur, "Bijli ka bill 28 tareekh tak jama karwana hai, warna jurmana lagega.").
test_message(r07, genuine, tune, ur, "Eid Mubarak! Allah aap ko aur aap ki family ko khush rakhe.").
test_message(r08, genuine, tune, ur, "Bhai project ki file jaldi bhej do, kal submit karni hai.").

% ---------------- Added 27 Oct: adversarial probes (tune) ----------------
% Written to break specific rules; kept so the fixes stay fixed.
test_message(p01, genuine, tune, en, "We will send you an OTP to verify your number.").
test_message(p02, genuine, tune, en, "Send me the location pin, I can't find your house.").
test_message(p03, genuine, tune, en, "Can you send me the wifi password?").
test_message(p04, genuine, tune, en, "I blocked him on WhatsApp, he was annoying.").
test_message(p05, genuine, tune, en, "Sorry, I locked the keys inside the car.").
test_message(p06, genuine, tune, ur, "Main aap ko OTP bhej raha hoon, check karo.").
test_message(p07, genuine, tune, en, "HBL card holders get 20% off at khaadi.com this weekend.").
test_message(p08, genuine, tune, en, "For queries email support@hbl.com").
test_message(p09, genuine, tune, en, "Transfer of Rs 500 to 03001234567 was successful.").
test_message(p10, genuine, tune, ur, "Dukaan aaj band ho gayi hai, kal aana.").
test_message(p11, scam,    tune, ur, "Apna OTP code send kar dein foran.").
test_message(p12, scam,    tune, ur, "Apna PIN share karein warna account band ho jayega.").
test_message(p13, scam,    tune, en, "Don't ignore this! Send your OTP now.").
test_message(p14, scam,    tune, en, "Your account is blocked. Login at https://jazzcash.com.pk.verify-login.xyz").
test_message(p15, scam,    tune, en, "Your Easypaisa wallet is suspended. Call 03001234567 to restore.").
test_message(p16, scam,    tune, ur, "Sir galti se aap ke number par OTP chala gaya, please wapis bhej do.").
test_message(p17, genuine, tune, en, "Please send your CNIC copy for the internship form.").
test_message(p18, genuine, tune, en, "Should I send you my account number for the refund?").
test_message(p19, genuine, tune, en, "JazzCash app update available. Update now from the Play Store.").
test_message(p20, genuine, tune, en, "Call me urgently when you're free, it's about the assignment.").
test_message(p21, scam,    tune, en, "Send your CNIC number and PIN code to verify your identity.").
test_message(p22, scam,    tune, ur, "BISP: apni CNIC ki copy aur OTP is number par bhejein 03001234567.").
test_message(p23, scam,    tune, en, "Your JazzCash account needs KYC. Update your account now or it will be blocked.").
test_message(p24, genuine, tune, en, "Send me your account number, I'll transfer your share of the trip money.").
test_message(p25, genuine, tune, ur, "Apna account number bhej do, main paise transfer kar deta hoon.").
test_message(p26, scam,    tune, en, "To release your prize money, send your account number and CNIC number to 03001234567.").
