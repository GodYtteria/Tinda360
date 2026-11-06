# Tinda 360

An offline point of sale for sari-sari stores in the Philippines, made by
Bukluran ng Kalinga ng Mamamayang Distrito Singko Inc.

Many stores are minded by a relative or a neighbour while the owner is away.
Counting stock is hard, utang lives in a notebook, and the owner cannot tell if
the earnings are right or the cash drawer is short. Tinda 360 is a simple phone
app that works without internet, so the person at the counter can sell, count
stock and write utang correctly.

Version 1.0.0 is an MVP. We are glad to hear what real stores need next.

## What it does

- Sell with cash, e-wallet or utang, with split payment and an optional interest
- Stock that cannot be oversold, expiry dates and a shopping list
- Utang per suki with history, reminders and a way to fix a wrong line
- Reports, returns and an end of day cash count
- A PIN for sensitive actions and a bantay name on every sale
- Backup to your own Google Drive or to a file
- Filipino and English, and no internet needed

## Build it

You need Flutter. From the project folder:

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter test
flutter build apk --release --dart-define-from-file=config/dart_defines.json
```

Signing: copy your own keystore details into `android/key.properties`
(this file is never committed). Google backup needs your own Google Cloud
OAuth client. Put its web client id in `config/dart_defines.json`.

## Your data

Sales, stock and utang stay on the phone. They leave it only if you turn on
Google Drive backup (your private app folder) or export a file yourself.
There is no tracking and there are no ads.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
The Bukluran and Tinda 360 names and logos are not covered by the license.
