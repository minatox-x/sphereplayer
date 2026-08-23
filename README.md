# Sphere Player

A minimal Flutter companion app for StreamWorld — handles Cloudflare Turnstile verification and loads the player securely via the `streamplayer://` custom protocol.

---

## How it works

```
streamplayer://play?url=…&cookie=<token>&<any params>
        │
        ▼
  Sphere Player opens
        │
        ▼
  Shows ONLY Cloudflare Turnstile iframe (studyspark.study hidden entirely)
        │
        ▼
  User solves challenge → token captured via JS bridge
        │
        ▼
  POST token to streamworld.vercel.app/player2 (with query params + cookie injected)
        │
        ▼
  Player loads in-app WebView
        │
        ▼  (any link or navigation away from /player2)
  Opens in system browser
```

---

## Protocol: `streamplayer://`

Trigger the player from any browser or web page with:

```
streamplayer://play?<params>
```

### Supported parameters

| Parameter     | Description                                                      |
|---------------|------------------------------------------------------------------|
| `url`         | (or any key) Forwarded as query param to `/player2`             |
| `cookie`      | Cookie **value** to set on `streamworld.vercel.app` before load  |
| `cookie_name` | Cookie **name** (default: `session`)                             |
| `*`           | Any other key–value pair is appended to the player2 URL          |

### Examples

```
streamplayer://play?url=https%3A%2F%2Fexample.com%2Fstream.m3u8&cookie=abc123

streamplayer://play?id=movie-42&season=1&episode=3&cookie=mytoken&cookie_name=auth
```

This results in a POST to:
```
https://streamworld.vercel.app/player2?id=movie-42&season=1&episode=3
```
With cookie `auth=mytoken` set on `streamworld.vercel.app`.

---

## Navigation policy

| URL host / path                          | Behaviour                         |
|------------------------------------------|-----------------------------------|
| `streamworld.vercel.app/player2*`        | Stays in WebView                  |
| Anything else (incl. `/generate`, links) | Opens in system default browser   |

---

## Platform setup

### Android

Protocol is registered automatically via `AndroidManifest.xml` — no extra steps.

To trigger from a web page:
```html
<a href="streamplayer://play?cookie=TOKEN&url=ENCODED_URL">Open in Sphere Player</a>
```

Or via JavaScript:
```js
window.location.href = 'streamplayer://play?cookie=' + token + '&url=' + encodeURIComponent(url);
```

### Windows

The app self-registers the `streamplayer://` protocol in `HKEY_CURRENT_USER\Software\Classes\streamplayer` on every launch — **no admin rights required**, no installer needed.

---

## Building

### Prerequisites

- Flutter 3.22+ (`flutter --version`)
- Android SDK (for APK builds)
- Windows + Visual Studio 2022 with "Desktop development with C++" (for Windows builds)

### Local build

```bash
# Android APK
flutter build apk --release

# Windows EXE
flutter config --enable-windows-desktop
flutter build windows --release
```

### GitHub Actions (CI/CD)

Push to `main` or open a PR → builds run automatically.

To create a release with downloadable artifacts, tag a commit:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers the release job which attaches:
- `app-release.apk` (universal)
- `app-arm64-v8a-release.apk`
- `app-armeabi-v7a-release.apk`
- `SpherePlayer-Windows.zip`

---

## Project structure

```
sphere_player/
├── lib/
│   ├── main.dart                  # Entry point
│   ├── app.dart                   # Root widget + protocol init
│   ├── models/
│   │   └── player_params.dart     # URI parsing
│   ├── screens/
│   │   ├── home_screen.dart       # Shown when no protocol params
│   │   └── player_screen.dart     # Turnstile → token → player flow
│   └── services/
│       └── protocol_handler.dart  # app_links stream listener
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml    # streamplayer:// intent-filter
│       └── ...
├── windows/
│   └── runner/
│       └── main.cpp               # Protocol registry self-registration
└── .github/workflows/
    └── build.yml                  # CI: Android + Windows builds + releases
```

---

## Security notes

- The `studyspark.study` origin is never shown to the user. The Turnstile HTML is rendered with `baseUrl` set to that origin so Cloudflare accepts the token, but the UI is a bare `302×70` iframe centred in our own dark screen.
- Navigation inside the player WebView is locked to `streamworld.vercel.app/player2*`. Every other URL is ejected to the system browser.
- Cookies are injected via `flutter_inappwebview`'s `CookieManager` before the player loads, so the server can perform its own session check normally.
