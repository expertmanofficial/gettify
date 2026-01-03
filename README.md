![Gettify logo](https://imgur.com/a/4t0NavY) # Gettify

Gettify is a fork and continuation of the original Obtanium app, designed to obtain and update Android apps directly from custom sources like GitHub, GitLab, F-Droid, and more — bypassing traditional app stores for greater freedom and control.

## History

The story of Gettify begins with the original Obtanium app, an open-source tool created to help users fetch and update FOSS (Free and Open-Source Software) Android apps from their developers' own repositories. Obtanium was born out of a desire to maintain independence from centralized app stores like Google Play, allowing users to get the latest versions directly from sources such as GitHub releases or F-Droid indexes. It was licensed under GPL-3.0 and gained popularity in privacy-focused communities for its simplicity and extensibility, supporting over 20 source types including GitHub, GitLab, Codeberg, F-Droid, IzzyOnDroid, APKPure, APKMirror (for tracking), Telegram channels, and even custom HTML/JSON scraping.

However, in August 2025, Google announced a major policy change that effectively spelled the end for apps like Obtanium on certified Android devices. Starting in late 2026 (initially September in select countries like Brazil, Indonesia, Singapore, and Thailand, with global rollout expected by 2027), all apps — including sideloaded ones — must be registered by developers with verified identities to be installable on certified Android devices. This requires developers to submit personal identification (government ID), pay a fee, provide evidence of their private signing keys, and list all app identifiers directly to Google. The policy aims to combat malware and improve security by ensuring only "verified" developers can distribute apps, but it has significant implications for open-source and independent development.

As noted in Obtanium's final in-app message, the developers chose not to comply with this requirement, stating: "Google has announced that, starting in 2026/2027, all apps on 'certified' Android devices will require the developer to submit personal identity details directly to Google." Since the Obtanium team did not agree to this central registration, the app will no longer function on certified devices after the policy takes effect. The message further explains that while unverified ("non-compliant") apps might still be installable through an "advanced flow" process Google has promised, details are unclear, and it may not truly preserve user freedoms. This move by Google is seen as a significant step toward the end of free, general-purpose computing for individuals, ceding control of software distribution to a single corporation.

This policy sparked widespread backlash from the Android community, developers, and privacy advocates. Organizations like F-Droid warned that it could end their project, as independent FOSS developers often prioritize anonymity and refuse to share personal data with Google. The "Keep Android Open" campaign (keepandroidopen.org) emerged as a focal point of opposition, arguing that the policy undermines Android's open nature, threatens digital sovereignty, and gives Google opaque control over what software users can run. They highlight how it affects sideloading, direct sharing of apps, and open-source distribution, potentially impacting businesses, governments, and individuals reliant on custom software.

In response to Obtanium's impending discontinuation, Gettify was forked to continue its mission. Created by me, Gettify maintains the core functionality of obtaining apps from diverse sources while enhancing user experience with a modern Material You UI, persistent settings (like update check intervals and WiFi-only checks), and plans for even more extensibility. The fork was motivated by the need to preserve user freedoms on non-certified devices or through workarounds, and to adapt to a world where certified Android might limit independent app distribution. While Gettify won't work on certified devices post-2026 without verification (which we won't pursue to stay true to the spirit of openness), it encourages users to explore alternatives like GrapheneOS or other non-certified OSes for full compatibility.

For more on Google's policy and the backlash, visit [Keep Android Open](https://keepandroidopen.org/) or read discussions on GrapheneOS forums and Reddit (e.g., r/privacy, r/androiddev).

## Features

- Fetch and update apps from 20+ sources (GitHub, GitLab, F-Droid, IzzyOnDroid, APKPure, APKMirror, Telegram, HTML scraping, etc.)
- Modern, responsive UI with Material You design
- Persistent settings: customizable update check intervals (1h to 48h), WiFi-only checks
- Export/import app lists as JSON
- Background update checks (coming soon)
- Real app icons from sources
- And more — open to contributions!

## Build and Installation

Gettify is built with Flutter, so you'll need Flutter SDK to build from source. We recommend Flutter 3.27.4 or later.

### Prerequisites
- Flutter SDK (install from [flutter.dev](https://flutter.dev/docs/get-started/install))
- Android SDK (via Android Studio)
- Git

### Step 1: Clone the Repo
```
git clone https://github.com/expertmanofficial/gettify.git
cd gettify
```

### Step 2: Get Dependencies
```
flutter pub get
```

### Step 3: Build APK
- For debug (testing):
  ```
  flutter build apk --debug
  ```
  - Output: `build/app/outputs/flutter-apk/app-debug.apk`

- For release (production):
  ```
  flutter build apk --release
  ```
  - Output: `build/app/outputs/flutter-apk/app-release.apk`

### Step 4: Install on Device
- Enable USB debugging on your Android device (Settings → About → Tap Build 7x → Developer options → USB debugging)
- Connect via USB
- Install:
  ```
  flutter install
  ```
- Or transfer APK and install manually.

### Step 5: Run in Emulator
- Start emulator in Android Studio (AVD Manager → Pixel 7 → Android 14)
- ```
  flutter run
  ```

### Contributing
Fork the repo, make changes, commit/push, open Pull Request. See CONTRIBUTING.md for details.

### License
GPL-3.0 (same as original Obtanium)

For questions, contact me on X at [@imorisune](https://x.com/imorisune) or open an issue.
