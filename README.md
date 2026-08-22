# C-Shield AIP Flutter SDK

C-Shield AIP (API Integrity Protection) Flutter SDK provides two protection solutions for Flutter applications: **API Protection** (request/response signing) and **SSL Pinning** (certificate pinning), securing the communication between the app and the server.


---

## Table of Contents

1. [Integrating the SDK](#1-integrating-the-sdk)
   - 1.1 [Add dependency to pubspec.yaml](#11-add-dependency-to-pubspecyaml)
   - 1.2 [Android configuration](#12-android-configuration)
   - 1.3 [iOS configuration](#13-ios-configuration)
2. [Initializing the SDK](#2-initializing-the-sdk)
3. [API Protection](#3-api-protection)
   - 3.1 [Automatic mode — CShieldInterceptor (http)](#31-automatic-mode--cshieldinterceptor-http)
   - 3.2 [Automatic mode — CShieldDioInterceptor (Dio)](#32-automatic-mode--cshielddiointerceptor-dio)
   - 3.3 [Manual mode — CShieldAP](#33-manual-mode--cshieldap)
   - 3.4 [Signing protocol](#34-signing-protocol)
4. [SSL — Certificate Pinning](#4-ssl--certificate-pinning)
   - 4.1 [Obtaining pin values](#41-obtaining-pin-values)
   - 4.2 [Configuring CShieldSSL](#42-configuring-cshieldssl)
   - 4.3 [Integrating with the http package](#43-integrating-with-the-http-package)
   - 4.4 [Integrating with Dio](#44-integrating-with-dio)
   - 4.5 [Manual verification](#45-manual-verification)
   - 4.6 [Capabilities, limitations, and recommendations](#46-capabilities-limitations-and-recommendations)
5. [Exceptions](#5-exceptions)

---

## 1. Integrating the SDK

### 1.1 Add dependency to pubspec.yaml

Add `c_shield_aip` to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  c_shield_aip: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### 1.2 Android configuration

#### Step 1 — Obtain the AAR files from CMC CShield

The Android SDK is built per customer, using the certificate hash of your signed app. Contact CMC CShield's team to receive the AAR files matching your app's signing certificate.

#### Step 2 — Place the AAR files into the project

Create a `libs/` folder under `android/app/` and place the AAR files there:

```
your_app_flutter/
└── android/
    └── app/
        └── libs/  ← place the AAR files here
            └── cshield-embedded-release.aar
            └── cshield-embedded-debug.aar
```

#### Step 3 — Declare the dependency in build.gradle

Open `android/app/build.gradle.kts` (or `build.gradle`) and add:

```kotlin
android {
    defaultConfig {
        minSdk = 24       // minimum required by the SDK
    }
    compileSdk = 34       // minimum required by the SDK
}

dependencies {
    // Android SDK — AAR files provided by CMC CShield
    debugImplementation(files("libs/cshield-embedded-debug.aar"))
    releaseImplementation(files("libs/cshield-embedded-release.aar"))
}
```

> No other transitive dependencies are needed — the SDK ships no native UI (no RASP popups), so it doesn't depend on Compose/Retrofit.

#### Step 4 — Build the release AAB

```bash
flutter build appbundle --release
```

### 1.3 iOS configuration

Please follow the steps in the [iOS Integration Guide](https://github.com/CMC-Cyber-Security/C-Shield-AIP-Flutter/blob/main/doc/ios-host-app-integration.md).

---

## 2. Initializing the SDK

Call `CShieldAIP.initialize()` **before `runApp()`** in your `main()` function:

```dart
import 'package:c_shield_aip/c_shield_aip.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CShieldAIP.initialize();
  runApp(const MyApp());
}
```

If `initialize()` isn't called before using the other APIs, native behavior isn't guaranteed — always call it before any `CShieldSSL`/`CShieldAP` call.

---

## 3. API Protection

API Protection signs every request sent to the server and verifies the signature of every response received, preventing MITM and replay attacks.

The SDK offers two integration modes:

- **Automatic mode (recommended):** Use `CShieldInterceptor` (for the `http` package) or `CShieldDioInterceptor` (for Dio - recommended). Signing/verification happens fully automatically.
- **Manual mode:** Use `CShieldAP` directly for full control over payload and timing.

### 3.1 Automatic mode — CShieldInterceptor (http)

```dart
import 'package:c_shield_aip/c_shield_aip.dart';
import 'package:http/http.dart' as http;

// Create once, reuse across the whole app
final client = CShieldInterceptor();

// Or combine with SSL pinning:
final client = CShieldInterceptor(
  inner: CShieldSSL.createIOClient(),
);

// Use just like a regular http.Client:
final response = await client.post(
  Uri.parse('https://api.example.com/users'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'name': 'Alice'}),
);
// cs-timestamp / cs-signature are attached to the request automatically.
// The response signature is verified automatically before it's returned.
```

**`CShieldInterceptor` parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `inner` | `http.Client?` | `http.Client()` | Inner HTTP client (pass a client with SSL pinning to combine both) |
| `verifyResponses` | `bool` | `true` | Verify the response signature; set `false` if the server doesn't sign responses yet |

### 3.2 Automatic mode — CShieldDioInterceptor (Dio) - Recommended

```dart
import 'package:c_shield_aip/c_shield_aip.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// Add the API Protection interceptor
dio.interceptors.add(const CShieldDioInterceptor());

// Combine with SSL pinning:
dio.httpClientAdapter = CShieldSSL.createDioAdapter();
dio.interceptors.add(const CShieldDioInterceptor());

// Use normally
final response = await dio.post('/api/v1/login', data: {'user': 'alice'});
```

**`CShieldDioInterceptor` parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `verifyResponses` | `bool` | `true` | Verify the response signature; set `false` if the server doesn't sign responses |

> When `verifyResponses: true`, the interceptor temporarily forces `ResponseType.bytes` to read the raw bytes for verification, then decodes back to the original type before returning to the caller.

### 3.3 Manual mode — CShieldAP

Use this when you need full control — WebSocket, a custom HTTP client, or detailed payload logging.

```dart
import 'package:c_shield_aip/c_shield_aip.dart';

// 1. Sign a request manually
final apHeaders = await CShieldAP.signRequest(
  method: 'POST',
  path: '/api/v1/login',    // path only, no query string
  body: Uint8List.fromList(utf8.encode(jsonEncode({'user': 'alice'}))),
  contentType: 'application/json',
);
// apHeaders = {'cs-timestamp': '...', 'cs-signature': '...'}
// Attach these to the request before sending

// 2. Verify a response manually
await CShieldAP.verifyResponse(
  statusCode: 200,
  path: '/api/v1/login',
  headers: response.headers,
  body: responseBytes,
);
// No throw = valid; throws CShieldException on failure

// 3. Sign a raw payload (advanced)
final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
final norm = await CShieldAP.normalizeBody(
  body: bodyBytes,
  contentType: 'application/json',
);
final payload = 'POST./api/v1/login.$ts.${norm['hash']}';
final signature = await CShieldAP.sign(payload);

// 4. Verify a raw signature
await CShieldAP.verify(payload: payload, signature: signature);
```

**`CShieldAP` API:**

| Method | Description |
|---|---|
| `signRequest(method, path, body, contentType)` | Signs a request and returns a map `{'cs-timestamp', 'cs-signature'}` |
| `verifyResponse(statusCode, path, headers, body)` | Verifies the response signature; throws `CShieldException` on failure |
| `sign(payload)` | Signs a raw payload; the caller builds the payload string |
| `verify(payload, signature)` | Verifies a raw payload's signature |
| `normalizeBody(body, contentType)` | Normalizes the body and computes its hash; returns `{'normalizedString', 'sizeInBytes', 'hash'}` |

### 3.4 Signing protocol

**Request — sent by the client to the server:**

Attached headers:
```
cs-timestamp: <unix_seconds>
cs-signature: <RSA_signature>
```

Signed payload:
```
{METHOD}.{path}.{timestamp}.{SHA256(body)}
```

Example:
```
POST./api/v1/login.1746700000.e3b0c44298fc1c149afbf4c8996fb924...
```

**Response — returned by the server:**

Headers the server must attach:
```
cs-timestamp: <unix_seconds>
cs-signature: <RSA_signature>
```

Payload the server signs:
```
{statusCode}.{path}.{timestamp}.{SHA256(responseBody)}
```

**Rules:**
- The timestamp must fall within a **±30 second** window of the device clock.
- `path` is the URL path without the query string (`/api/v1/login`, not `/api/v1/login?token=abc`).
- The SHA-256 hash of the body is lowercase hex.

**Body normalization:**

| Content-Type | Handling |
|---|---|
| `application/json` / text | Body bytes are used verbatim |
| `multipart/form-data` | Only text fields are used (file parts are ignored), sorted by field name, serialized as JSON |

---

## 4. SSL — Certificate Pinning

Certificate pinning ensures the app only accepts the known, correct server certificate, preventing MITM even when the device trusts a rogue CA.

### 4.1 Obtaining pin values

A pin is the SHA-256 hash of the certificate's SPKI (Subject Public Key Info), base64-encoded:

```bash
# Get the pin directly from the server
openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl base64

# Prefix the result with "sha256/"
# Example: sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
```

**Recommendation: always provide at least 2 pins** (primary + backup) to avoid lockout when the certificate rotates.

#### Pin the intermediate CA to survive rotation

Leaf certificates are usually **reissued periodically** (Let's Encrypt/Google Trust Services ~90 days) and **may change key on each reissue** → a leaf pin will go stale and **the app will be blocked from connecting** until an update ships. To avoid this, pin the **public key of a stable intermediate CA** (rarely changes for years) instead of, or alongside, the leaf. `createDioAdapter()` matches the pin against the **entire chain**, so any single certificate in the chain matching is enough.

```bash
# View the full chain (leaf + intermediate + root)
openssl s_client -connect api.example.com:443 -servername api.example.com -showcerts </dev/null 2>/dev/null

# For each "BEGIN CERTIFICATE" block (cert #1 = intermediate), compute the SPKI pin:
openssl x509 -in intermediate.pem -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary | openssl base64
```

> ⚠️ **Only the Dio path (`createDioAdapter`) matches the whole chain.** The `http` path and `verifyPin` only compare the leaf (see [4.6](#46-capabilities-limitations-and-recommendations)) — pinning the intermediate will **not** match on those two paths.

### 4.2 Configuring CShieldSSL

Call `configure()` after `initialize()`, before making any network request:

```dart
await CShieldSSL.configure(
  pins: [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // primary
    'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // backup
  ],
  hostname: 'api.example.com',
);
```

**`CShieldSSL` API:**

| Method | Description |
|---|---|
| `configure(pins, hostname)` | Configures pinning; throws `ArgumentError`/`CShieldException(invalidArgument)` if pins are empty, hostname is blank, or a pin lacks the `sha256/` prefix |
| `updatePins(pins, hostname)` | Updates the pins after the server rotates its certificate (alias for `configure`) |
| `isConfigured()` | Returns `true` if already configured |
| `createDioAdapter()` | **(Recommended)** Creates an `HttpClientAdapter` for Dio. Requests to `hostname` are made at the **native** layer (OkHttp/URLSession) → pinning runs at the TLS layer against the **full chain** (leaf/intermediate/root). Other hosts go through the default adapter. |
| `createHttpClient()` | Creates an `HttpClient` (dart:io) with SPKI pinning via `badCertificateCallback`. **Leaf-only, pure Dart** — see the warning in [4.6](#46-capabilities-limitations-and-recommendations) |
| `createIOClient()` | Creates an `IOClient` (http package) — a drop-in for `http.Client()`. **Leaf-only, pure Dart** |
| `verifyPin(certDerBase64, host)` | Manually verifies a single certificate DER, base64-encoded. **Checks only the leaf's SPKI** (Dart can only pass the leaf) |

### 4.3 Integrating with the http package

> ⚠️ **Not recommended for sensitive APIs.** The `http` path uses `badCertificateCallback`, which **only fires when the certificate fails default validation**. A MITM certificate chaining to a trusted CA (even a CA the victim installed themselves) will **pass without pin checking**. It also **only compares the leaf**, so intermediate pinning isn't possible. For sensitive data, use **Dio + `createDioAdapter()`** ([4.4](#44-integrating-with-dio)).

```dart
import 'package:c_shield_aip/c_shield_aip.dart';

// Setup (once, in main() or app init)
await CShieldSSL.configure(
  pins: ['sha256/...'],
  hostname: 'api.example.com',
);

// Create the client (reuse it, don't recreate per request)
final client = CShieldSSL.createIOClient();

// Use like a regular http.Client
final response = await client.get(
  Uri.parse('https://api.example.com/data'),
);
```

**Combining SSL pinning + API Protection:**

```dart
final client = CShieldInterceptor(
  inner: CShieldSSL.createIOClient(), // SSL pinning at the inner layer
);
// client now has both certificate pinning and automatic API Protection signing/verification
```

### 4.4 Integrating with Dio

```dart
import 'package:c_shield_aip/c_shield_aip.dart';
import 'package:dio/dio.dart';

await CShieldSSL.configure(
  pins: ['sha256/...'],
  hostname: 'api.example.com',
);

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// Attach SSL pinning to Dio. For a configured host, requests are made
// at the NATIVE layer (OkHttp on Android, URLSession on iOS) — where
// the full certificate chain is visible — so pinning can match
// intermediate/root as well. Other hosts go through the default
// adapter (unaffected).
dio.httpClientAdapter = CShieldSSL.createDioAdapter();

// Combine with API Protection
dio.interceptors.add(const CShieldDioInterceptor());
```

> **Buffered, not streaming.** Requests/responses are passed through native as a whole. Upload/download progress, `ResponseType.stream`, and SSE are not supported on a pinned host — see [4.6](#46-capabilities-limitations-and-recommendations).

### 4.5 Manual verification

> ⚠️ `verifyPin()` **only checks the leaf certificate's SPKI** (Dart can only pass the leaf down to native) and does not perform full CA chain validation. Treat it as a secondary utility, not the primary pinning mechanism. The complete mechanism (full chain + CA validation) is `createDioAdapter()`.

Use `verifyPin()` in a custom interceptor or WebSocket:

```dart
// Get the DER bytes of the leaf certificate from the TLS connection
final certDerBase64 = base64.encode(peerCertificateDerBytes);

final trusted = await CShieldSSL.verifyPin(
  certDerBase64: certDerBase64,
  host: 'api.example.com',
);

if (!trusted) {
  throw const CShieldException(
    CShieldErrorCode.sslPinMismatch,
    'Certificate pin mismatch for api.example.com',
  );
}
```

### 4.6 Capabilities, limitations, and recommendations

A fundamental Flutter constraint: `dart:io` **only exposes the leaf certificate** — there's no pure-Dart API to obtain the full chain. Because of this, the SDK **delegates transport to native** (OkHttp/URLSession) on the Dio path so pinning runs where the full chain is visible — this is considered the most reliable model available in Flutter.

#### What works today

| Capability | `createDioAdapter` (Dio) | `createIOClient` (http) | `verifyPin` |
|---|---|---|---|
| Matches SPKI across the **full chain** (leaf/intermediate/root) | ✅ | ❌ leaf only | ❌ leaf only |
| Pin the intermediate → resilient to rotation | ✅ | ❌ | ❌ |
| System CA validation (fail-closed) | ✅ (native) | partial¹ | partial |
| Blocks user-installed CAs (Burp/Charles) | ✅ (native) | ❌² | — |

¹ `badCertificateCallback` only runs when default validation fails.
² A MITM cert chaining to a trusted CA will pass through (the callback never fires).

#### Limitations

**A. Inherent to Flutter — nothing the SDK can do about these:**
- **Narrow coverage**: only traffic going through the exact Dio instance with the adapter attached, and only to the configured `hostname`. Pinning does **NOT** cover WebView (`webview_flutter`), image loading (`Image.network`, `CachedNetworkImage`), other HTTP libraries, or third-party plugins. → Route sensitive API calls through the pinned Dio instance.
- **Web builds**: browsers don't allow app-level pinning.
- **Rotation/expiry management**: a pinned certificate that expires breaks the app. Mitigate by pinning the **intermediate** ([4.1](#pin-the-intermediate-ca-to-survive-rotation)) plus a backup pin.

**B. Due to the implementation (native transport on the Dio path):**
- **Buffered, not streaming**: no upload/download progress, no `ResponseType.stream`, no SSE. Large files can consume significant RAM → use a non-pinned Dio instance for these cases.
- **`CancelToken` can't cancel the native request**: Dio cancels on the Dart side, but the native request keeps running until it completes.
- **iOS merges multi-value headers**: `HTTPURLResponse` merges multiple headers with the same name (especially `Set-Cookie`) into a single string → a cookie-parsing interceptor may parse this incorrectly. Android returns the correct list.
- **iOS `followRedirects=false` is best-effort**: URLSession still follows redirects by default.

**C. The `http` package path and `verifyPin`**: leaf-only, not a strong security guarantee — **do not use them for sensitive data** (see the warnings in [4.3](#43-integrating-with-the-http-package) and [4.5](#45-manual-verification)).

#### Quick recommendations

- For sensitive data → **Dio + `createDioAdapter()`**, pinning the **intermediate + a backup**.
- Don't rely on `createIOClient`/`verifyPin` as the primary security layer.

---

## 5. Exceptions

All errors from the SDK are thrown as `CShieldException`:

```dart
class CShieldException implements Exception {
  final CShieldErrorCode code;    // error code enum
  final String message;           // error description
  final Object? nativeCause;      // underlying native error, if any
}
```

**`CShieldErrorCode`:**

| Code | Cause |
|---|---|
| `apMissingHeader` | Response is missing the `cs-timestamp` or `cs-signature` header |
| `apTimestampExpired` | Timestamp falls outside the ±30 second window |
| `apInvalidSignature` | The response signature is invalid (response was tampered with) |
| `apSigningFailed` | Failed to sign the request (private key not ready) |
| `apDetectProxyCA` | Proxy CA detected — API Protection refuses to process |
| `sslNotConfigured` | `createHttpClient()`/`createIOClient()`/`createDioAdapter()` was called before `CShieldSSL.configure()` |
| `sslPinMismatch` | The server's certificate doesn't match the configured pin |
| `notInitialized` | An API was called before `CShieldAIP.initialize()` |
| `invalidArgument` | An invalid argument was provided |
| `nativeError` | An unspecified error from the native SDK |

**Catching errors:**

```dart
try {
  final response = await client.post(Uri.parse('https://api.example.com/login'), ...);
} on CShieldException catch (e) {
  switch (e.code) {
    case CShieldErrorCode.apTimestampExpired:
      // Clock skew or a replay attack
      _showError('Time verification error');
      break;
    case CShieldErrorCode.apInvalidSignature:
      // Response was tampered with
      _logSecurityEvent('Response tampered');
      break;
    case CShieldErrorCode.sslPinMismatch:
      // Certificate mismatch — MITM or the pin needs rotating
      _logSecurityEvent('SSL pin mismatch');
      break;
    default:
      _showError('Security error: ${e.message}');
  }
}
```

---

## Typical Integration Flow

```
main()
  +-- WidgetsFlutterBinding.ensureInitialized()
  +-- CShieldAIP.initialize()                   // required — before runApp()
  +-- CShieldSSL.configure(pins, host)          // if using certificate pinning
  +-- runApp()

Initialize the HTTP client (singleton)
  +-- CShieldInterceptor(inner: CShieldSSL.createIOClient())   // http package
      // or Dio:
  +-- dio.httpClientAdapter = CShieldSSL.createDioAdapter()
  +-- dio.interceptors.add(CShieldDioInterceptor())
```
