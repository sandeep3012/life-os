<!--
The source of the published privacy policy. `scripts/build_site.py` turns
this into docs/site/privacy/index.html; see that script for how to publish.
It describes what the app does as of November 2026 and is not legal advice.
If the app starts collecting anything new, update this first.
-->

# PersonalOS Privacy Policy

**Effective date:** 21 November 2026

PersonalOS is an app for managing your money, habits, tasks, notes,
documents and calendar. It is published by Sandeep Choudhary ("we", "us"),
based in India.

The short version:

- Everything you put in PersonalOS is stored on your phone. You don't need an
  account, and without one nothing you enter leaves your phone.
- The app currently has no ads, no analytics and no tracking. If that ever
  changes, this policy will be updated before it does.
- If you turn on sync, your data is encrypted on your phone before it is
  uploaded.
- If you use voice entry, the sentence you speak is sent to an AI service to
  be understood. You are asked before this happens the first time.

## 1. Data that stays on your phone

Everything you enter — accounts, transactions, budgets, habits, tasks, notes,
documents and their files, events, goals, reminders and settings — is kept in
the app's own storage on your phone. We cannot see it.

This data is removed when you clear the app's data or uninstall the app.

**App lock.** If you turn on fingerprint or face unlock, the check is done by
your phone. PersonalOS only learns whether it passed; it never receives your
fingerprint or face data.

**Backups you make.** Settings → Export creates a file containing your data.
You choose where it goes and whether to protect it with a password. We never
receive it.

## 2. If you create an account

An account is optional. It is needed only for sync and voice entry.

When you sign up we store:

- your email address;
- your name, if you give one;
- a password, stored only in hashed form;
- if you sign in with Google or Apple instead, the email address and name
  that service gives us.

We use these to sign you in, to send you account emails (confirming your
address, resetting your password), and to know which plan your account has.

## 3. If you turn on sync

Sync copies your data between your phones through our server.

**What is uploaded.** Each record is encrypted on your phone before it is
sent. Our server stores the encrypted record together with a few technical
details it needs to do its job: a random-looking record id, the time of the
change, whether the record was deleted, and which of your devices sent it.
For each device it keeps a general label ("Android phone" or "iPhone") and
when it last synced.

The files of your documents (photos, PDFs) are **not** uploaded. Only the
document's details are.

**Who can read it.** That depends on the recovery option you choose in
Sync & account:

- **Standard.** Our server keeps a copy of your encryption key in a protected
  vault so that signing in is enough to get your data back on a new phone.
  This means our server is technically able to decrypt your synced data. We
  do not do so.
- **Maximum privacy.** No copy of your key is kept on our server. We cannot
  read your synced data. If you lose every phone, your phone's own backup of
  the key, and your recovery key, your synced data cannot be recovered by
  anyone, including us.

You can switch between these at any time.

**Your phone's key backup.** A copy of your encryption key is also saved to
your phone's own protected backup (iCloud Keychain on iPhone; Google's Block
Store on Android), so a new or restored phone can unlock your data. That
backup is run by Apple or Google under their own privacy policies.

## 4. If you use voice entry

Voice entry is optional and asks for your agreement the first time.

- **Turning speech into text** is done by your phone's own speech service
  (on Android, usually Google's). To help it recognise them, the app gives
  that service the names of your accounts and categories. Depending on your
  phone's settings, the service may send audio and those names to its
  provider. PersonalOS never receives or stores the audio.
- **Understanding the sentence.** The text of what you said is sent to our
  server and passed to an AI service, Anthropic, together with the names of
  your accounts and categories, the current date and time, your time zone
  and your currency, so it can suggest the right entry. Nothing else from
  your data is sent.
- We do not keep the sentence or the suggestions on our server. We keep only
  a count of how many voice entries your account has used, to apply your
  plan's limit.
- Anthropic processes the text to produce the answer under its commercial
  terms, which do not permit using it to train its models. See
  [Anthropic's privacy policy](https://www.anthropic.com/legal/privacy).

## 5. If you subscribe to PersonalOS Plus

Payments are handled by Google Play. We never see your card or bank details.

To know that your subscription is active, we use a subscription service,
RevenueCat, which receives your purchase details from Google Play together
with your PersonalOS account id. We store which plan your account has and
when it ends.

## 6. Permissions the app asks for

| Permission | What it is used for |
|---|---|
| Internet | Sync, sign-in, checking your plan and voice entry. |
| Microphone | Voice entry only, while you are speaking. |
| Camera | Scanning the code that links a new phone, and taking a photo of a document or receipt when you choose to. |
| Notifications, alarms, full-screen alerts, vibration | Reminders and alarms you set. |
| Start at boot | Putting your reminders back after the phone restarts. |
| Fingerprint / face | App lock, if you turn it on. |

## 7. Who else handles your data

We do not sell your data or share it for advertising. These services process
data for us, only to provide the features above:

| Service | What it handles | Where |
|---|---|---|
| Supabase | Account details and encrypted sync data; account emails | Servers in Seoul, South Korea |
| Anthropic | The text of voice entries, as described in section 4 | United States |
| Google Play and RevenueCat | Subscription purchases | United States |

We may disclose information if the law requires it. Under Maximum privacy we
have nothing readable to disclose beyond your account details.

## 8. How long we keep it

- Data on your phone stays until you delete it or remove the app.
- Account and sync data stay on our server until you delete your account.
- If your PersonalOS Plus subscription ends, your synced data is kept on our
  server for 90 days, so it is still there if you come back, and may then be
  deleted. The copy on your phone is not affected.

## 9. Deleting your account and data

In the app: **Sync & account → Delete account.** This permanently deletes
your account and everything stored for it on our server — your encrypted
data, your keys, your device list and your usage counts. It does not delete
the data on your phone.

If you can't use the app, use the
[account deletion page](../delete-account/) or email
sand.it.support@gmail.com from the address on your account, and we will
delete it within 30 days.

## 10. Your choices and rights

You can:

- use PersonalOS without an account, so that nothing leaves your phone;
- turn sync off, or sign out, at any time;
- withdraw your agreement to voice entry by not using it;
- export all your data from Settings;
- correct anything by editing it in the app;
- ask us for a copy of the account details we hold, or to delete them.

To exercise any of these, or to complain about how your data is handled,
write to sand.it.support@gmail.com. We reply within 30 days.

## 11. Children

PersonalOS is not directed at children. You must be 18 or older to create an account. We do not knowingly
collect data from anyone younger; if you believe a child has created an
account, write to us and we will delete it.

## 12. Security

Sync data is encrypted on your phone (XChaCha20-Poly1305) and travels over
encrypted connections. Keys are kept in your phone's secure storage. No
system is perfectly secure; if a breach affects your data we will tell you as
the law requires.

## 13. Changes to this policy

If we change this policy we will update the date at the top. For changes
that matter, we will also email account holders before they take effect.

## 14. Contact

Sandeep Choudhary

sand.it.support@gmail.com
