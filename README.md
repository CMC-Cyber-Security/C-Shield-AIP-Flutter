# C-Shield Embedded Flutter SDK

C-Shield Embedded Flutter SDK là bản thu gọn của [C-Shield Flutter SDK](https://github.com/cmccsmobile/C-Shield-Flutter), chỉ tập trung vào một lớp bảo vệ:

- **AIP (API Integrity Protection):** Bảo vệ giao tiếp giữa app và server thông qua certificate pinning và ký số request/response.

SDK bọc native AAR (Android) và XCFramework (iOS), đảm bảo tầng ký/xác thực chạy ở native.

---

## Mục lục

1. [Tích hợp SDK](#1-tích-hợp-sdk)
   - 1.1 [Thêm dependency vào pubspec.yaml](#11-thêm-dependency-vào-pubspecyaml)
   - 1.2 [Cấu hình Android](#12-cấu-hình-android)
   - 1.3 [Cấu hình iOS](#13-cấu-hình-ios)
2. [Khởi tạo SDK](#2-khởi-tạo-sdk)
3. [AIP — API Integrity Protection](#3-aip--api-integrity-protection)
   - 3.1 [Chế độ tự động — CShieldInterceptor (http)](#31-chế-độ-tự-động--cshieldinterceptor-http)
   - 3.2 [Chế độ tự động — CShieldDioInterceptor (Dio)](#32-chế-độ-tự-động--cshielddiointerceptor-dio)
   - 3.3 [Chế độ thủ công — CShieldAIP](#33-chế-độ-thủ-công--cshieldaip)
   - 3.4 [Giao thức ký số](#34-giao-thức-ký-số)
4. [SSL — Certificate Pinning](#4-ssl--certificate-pinning)
   - 4.1 [Lấy giá trị pin](#41-lấy-giá-trị-pin)
   - 4.2 [Cấu hình CShieldSSL](#42-cấu-hình-cshieldssl)
   - 4.3 [Tích hợp với http package](#43-tích-hợp-với-http-package)
   - 4.4 [Tích hợp với Dio](#44-tích-hợp-với-dio)
   - 4.5 [Xác minh thủ công](#45-xác-minh-thủ-công)
   - 4.6 [Khả năng, hạn chế và khuyến nghị](#46-khả-năng-hạn-chế-và-khuyến-nghị)
5. [Exceptions](#5-exceptions)

---

## 1. Tích hợp SDK

### 1.1 Thêm dependency vào pubspec.yaml

Thêm `c_shield_embedded` vào `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  c_shield_embedded: ^1.0.0
```

Sau đó chạy:

```bash
flutter pub get
```

### 1.2 Cấu hình Android

#### Bước 1 — Nhận các file AAR từ CMC CShield

C-Shield Embedded SDK Android được build riêng cho từng khách hàng với certificate hash của app đã ký. Liên hệ CMC CShield để nhận file AAR tương ứng với signing certificate của bạn.

#### Bước 2 — Đặt các file AAR vào project

Tạo thư mục `libs/` trong `android/app/` và đặt file AAR vào đó:

```
your_app_flutter/
└── android/
    └── app/
        └── libs/  ← đặt file AAR vào đây
            └── cshield-embedded-release.aar
            └── cshield-embedded-debug.aar
```

#### Bước 3 — Khai báo dependency trong build.gradle

Mở `android/app/build.gradle.kts` (hoặc `build.gradle`) và thêm:

```kotlin
android {
    defaultConfig {
        minSdk = 24       // yêu cầu tối thiểu của C-Shield Embedded SDK
    }
    compileSdk = 36       // yêu cầu tối thiểu của C-Shield Embedded SDK
}

dependencies {
    // C-Shield Embedded Android SDK — file AAR do CMC CShield cung cấp
    debugImplementation(files("libs/cshield-embedded-debug.aar"))
    releaseImplementation(files("libs/cshield-embedded-release.aar"))
}
```

> Không cần khai thêm dependency transitive nào khác — bản embedded không có UI native (không RASP popup) nên không phụ thuộc Compose/Retrofit như bản đầy đủ `c_shield_sdk`.

#### Bước 4 — Build AAB khi release

```bash
flutter build appbundle --release
```

### 1.3 Cấu hình iOS

Vui lòng đọc và làm theo các bước tại [iOS Integration Guide](doc/ios-host-app-integration.md).

---

## 2. Khởi tạo SDK

Gọi `CShieldEmbedded.initialize()` **trước `runApp()`** trong hàm `main()`:

```dart
import 'package:c_shield_embedded/c_shield_embedded.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CShieldEmbedded.initialize();
  runApp(const MyApp());
}
```

Nếu không gọi `initialize()` trước khi dùng các API khác, hành vi native không được đảm bảo — luôn gọi trước mọi lệnh gọi `CShieldSSL`/`CShieldAIP` khác.

---

## 3. AIP — API Integrity Protection

AIP ký số mỗi request gửi lên server và xác thực chữ ký của mỗi response nhận về, ngăn chặn MITM và replay attack.

SDK cung cấp hai cách tích hợp:

- **Chế độ tự động (khuyến nghị):** Dùng `CShieldInterceptor` (cho `http` package) hoặc `CShieldDioInterceptor` (cho Dio). Sign/verify diễn ra hoàn toàn tự động.
- **Chế độ thủ công:** Dùng `CShieldAIP` trực tiếp để kiểm soát hoàn toàn payload và timing.

### 3.1 Chế độ tự động — CShieldInterceptor (http)

```dart
import 'package:c_shield_embedded/c_shield_embedded.dart';
import 'package:http/http.dart' as http;

// Khởi tạo một lần, tái sử dụng cho toàn bộ app
final client = CShieldInterceptor();

// Hoặc kết hợp với SSL pinning:
final client = CShieldInterceptor(
  inner: CShieldSSL.createIOClient(),
);

// Sử dụng như http.Client thông thường:
final response = await client.post(
  Uri.parse('https://api.example.com/users'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'name': 'Alice'}),
);
// cs-timestamp / cs-signature được đính kèm tự động vào request.
// Response signature được xác thực tự động trước khi trả về.
```

**Tham số `CShieldInterceptor`:**

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `inner` | `http.Client?` | `http.Client()` | HTTP client bên trong (truyền client có SSL pinning để kết hợp) |
| `verifyResponses` | `bool` | `true` | Xác thực chữ ký response; đặt `false` nếu server chưa tích hợp ký response |

### 3.2 Chế độ tự động — CShieldDioInterceptor (Dio)

```dart
import 'package:c_shield_embedded/c_shield_embedded.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// Thêm AIP interceptor
dio.interceptors.add(const CShieldDioInterceptor());

// Kết hợp với SSL pinning:
dio.httpClientAdapter = CShieldSSL.createDioAdapter();
dio.interceptors.add(const CShieldDioInterceptor());

// Sử dụng bình thường
final response = await dio.post('/api/v1/login', data: {'user': 'alice'});
```

**Tham số `CShieldDioInterceptor`:**

| Tham số | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `verifyResponses` | `bool` | `true` | Xác thực chữ ký response; đặt `false` nếu server chưa ký response |

> Khi `verifyResponses: true`, interceptor tạm thời force `ResponseType.bytes` để đọc raw bytes xác thực, sau đó decode lại sang kiểu gốc trước khi trả về caller.

### 3.3 Chế độ thủ công — CShieldAIP

Dùng khi cần kiểm soát hoàn toàn — WebSocket, custom HTTP client, hoặc khi cần log chi tiết payload.

```dart
import 'package:c_shield_embedded/c_shield_embedded.dart';

// 1. Ký request thủ công
final aipHeaders = await CShieldAIP.signRequest(
  method: 'POST',
  path: '/api/v1/login',    // chỉ path, không có query string
  body: Uint8List.fromList(utf8.encode(jsonEncode({'user': 'alice'}))),
  contentType: 'application/json',
);
// aipHeaders = {'cs-timestamp': '...', 'cs-signature': '...'}
// Đính kèm vào request trước khi gửi

// 2. Xác thực response thủ công
await CShieldAIP.verifyResponse(
  statusCode: 200,
  path: '/api/v1/login',
  headers: response.headers,
  body: responseBytes,
);
// Không throw = hợp lệ; throw CShieldException nếu thất bại

// 3. Ký payload thô (nâng cao)
final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
final norm = await CShieldAIP.normalizeBody(
  body: bodyBytes,
  contentType: 'application/json',
);
final payload = 'POST./api/v1/login.$ts.${norm['hash']}';
final signature = await CShieldAIP.sign(payload);

// 4. Xác thực chữ ký thô
await CShieldAIP.verify(payload: payload, signature: signature);
```

**API `CShieldAIP`:**

| Phương thức | Mô tả |
|---|---|
| `signRequest(method, path, body, contentType)` | Ký request và trả về map `{'cs-timestamp', 'cs-signature'}` |
| `verifyResponse(statusCode, path, headers, body)` | Xác thực chữ ký response; throw `CShieldException` nếu thất bại |
| `sign(payload)` | Ký payload thô; caller tự xây dựng payload string |
| `verify(payload, signature)` | Xác thực chữ ký payload thô |
| `normalizeBody(body, contentType)` | Chuẩn hoá body và tính hash; trả về `{'normalizedString', 'sizeInBytes', 'hash'}` |

### 3.4 Giao thức ký số

**Request — client gửi lên server:**

Headers đính kèm:
```
cs-timestamp: <unix_seconds>
cs-signature: <RSA_signature>
```

Payload được ký:
```
{METHOD}.{path}.{timestamp}.{SHA256(body)}
```

Ví dụ:
```
POST./api/v1/login.1746700000.e3b0c44298fc1c149afbf4c8996fb924...
```

**Response — server trả về:**

Headers mà server phải đính kèm:
```
cs-timestamp: <unix_seconds>
cs-signature: <RSA_signature>
```

Payload server ký:
```
{statusCode}.{path}.{timestamp}.{SHA256(responseBody)}
```

**Quy tắc:**
- Timestamp phải nằm trong cửa sổ **+-30 giây** so với giờ thiết bị.
- `path` là URL path không bao gồm query string (`/api/v1/login`, không phải `/api/v1/login?token=abc`).
- SHA-256 của body là lowercase hex.

**Body normalization:**

| Content-Type | Cách xử lý |
|---|---|
| `application/json` / text | Body bytes dùng nguyên văn |
| `multipart/form-data` | Chỉ lấy text fields (bỏ qua file parts), sắp xếp theo tên field, serialize JSON |

---

## 4. SSL — Certificate Pinning

Certificate pinning đảm bảo app chỉ chấp nhận đúng chứng chỉ của server đã biết, ngăn chặn MITM kể cả khi thiết bị tin tưởng CA giả.

### 4.1 Lấy giá trị pin

Pin là SHA-256 của SPKI (Subject Public Key Info) của certificate, encode base64:

```bash
# Lấy pin từ server trực tiếp
openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl base64

# Thêm prefix "sha256/" vào kết quả
# Ví dụ: sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
```

**Khuyến nghị: luôn cung cấp tối thiểu 2 pin** (primary + backup) để tránh lockout khi rotate certificate.

#### Pin intermediate CA để sống sót qua rotation

Certificate leaf thường được **cấp lại định kỳ** (Let's Encrypt/Google Trust Services ~90 ngày) và **có thể đổi key mỗi lần** → pin leaf sẽ lệch và **app bị chặn kết nối** cho tới khi ra bản update. Để tránh, hãy pin **public key của một intermediate CA ổn định** (ít đổi trong nhiều năm) thay vì/bên cạnh leaf. `createDioAdapter()` khớp pin trên **toàn bộ chain**, nên chỉ cần một cert bất kỳ trong chain khớp là hợp lệ.

```bash
# Xem toàn bộ chain (leaf + intermediate + root)
openssl s_client -connect api.example.com:443 -servername api.example.com -showcerts </dev/null 2>/dev/null

# Với mỗi block "BEGIN CERTIFICATE" (cert #1 = intermediate), tính SPKI pin:
openssl x509 -in intermediate.pem -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary | openssl base64
```

> ⚠️ **Chỉ đường Dio (`createDioAdapter`) mới khớp cả chain.** Đường `http` và `verifyPin` chỉ so leaf (xem [4.6](#46-khả-năng-hạn-chế-và-khuyến-nghị)) — pin intermediate sẽ **không** khớp ở hai đường đó.

### 4.2 Cấu hình CShieldSSL

Gọi `configure()` sau `initialize()`, trước khi thực hiện bất kỳ network request nào:

```dart
await CShieldSSL.configure(
  pins: [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // primary
    'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // backup
  ],
  hostname: 'api.example.com',
);
```

**API `CShieldSSL`:**

| Phương thức | Mô tả |
|---|---|
| `configure(pins, hostname)` | Cấu hình pinning; throw `ArgumentError`/`CShieldException(invalidArgument)` nếu pin rỗng, hostname trống, hoặc pin không có prefix `sha256/` |
| `updatePins(pins, hostname)` | Cập nhật pin mới sau khi server rotate certificate (alias của `configure`) |
| `isConfigured()` | Trả về `true` nếu đã cấu hình |
| `createDioAdapter()` | **(Khuyến nghị)** Tạo `HttpClientAdapter` cho Dio. Request tới `hostname` được thực hiện ở **native** (OkHttp/URLSession) → pinning chạy ở tầng TLS với **full chain** (khớp leaf/intermediate/root). Host khác đi qua adapter mặc định. |
| `createHttpClient()` | Tạo `HttpClient` (dart:io) với SPKI pinning qua `badCertificateCallback`. **Leaf-only, thuần Dart** — xem cảnh báo [4.6](#46-khả-năng-hạn-chế-và-khuyến-nghị) |
| `createIOClient()` | Tạo `IOClient` (http package) — drop-in cho `http.Client()`. **Leaf-only, thuần Dart** |
| `verifyPin(certDerBase64, host)` | Xác minh thủ công một certificate DER base64. **Chỉ kiểm SPKI của leaf** (Dart chỉ truyền được leaf) |

### 4.3 Tích hợp với http package

> ⚠️ **Không khuyến nghị cho API nhạy cảm.** Đường `http` dùng `badCertificateCallback` — callback này **chỉ kích hoạt khi cert FAIL validation mặc định**. Một cert MITM chain hợp lệ tới CA được tin (kể cả CA do nạn nhân tự cài) sẽ **pass mà không bị kiểm pin**. Ngoài ra nó **chỉ so leaf**, không pin được intermediate. Với dữ liệu nhạy cảm hãy dùng **Dio + `createDioAdapter()`** ([4.4](#44-tích-hợp-với-dio)).

```dart
import 'package:c_shield_embedded/c_shield_embedded.dart';

// Setup (một lần trong main() hoặc khởi tạo app)
await CShieldSSL.configure(
  pins: ['sha256/...'],
  hostname: 'api.example.com',
);

// Tạo client (tái sử dụng, không tạo lại mỗi request)
final client = CShieldSSL.createIOClient();

// Sử dụng giống http.Client thông thường
final response = await client.get(
  Uri.parse('https://api.example.com/data'),
);
```

**Kết hợp SSL pinning + AIP:**

```dart
final client = CShieldInterceptor(
  inner: CShieldSSL.createIOClient(), // SSL pinning ở lớp trong
);
// client vừa có certificate pinning vừa ký/xác thực AIP tự động
```

### 4.4 Tích hợp với Dio

```dart
import 'package:c_shield_embedded/c_shield_embedded.dart';
import 'package:dio/dio.dart';

await CShieldSSL.configure(
  pins: ['sha256/...'],
  hostname: 'api.example.com',
);

final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// Gắn SSL pinning vào Dio. Với host đã configure, request được thực hiện
// ở NATIVE (OkHttp trên Android, URLSession trên iOS) — nơi thấy full
// certificate chain — nên pinning khớp được cả intermediate/root.
// Host khác đi qua adapter mặc định (không ảnh hưởng).
dio.httpClientAdapter = CShieldSSL.createDioAdapter();

// Kết hợp với AIP
dio.interceptors.add(const CShieldDioInterceptor());
```

> **Buffered (không streaming).** Request/response được truyền trọn gói qua native. Không hỗ trợ upload/download progress, `ResponseType.stream`, hay SSE trên host được pin — xem [4.6](#46-khả-năng-hạn-chế-và-khuyến-nghị).

### 4.5 Xác minh thủ công

> ⚠️ `verifyPin()` **chỉ kiểm SPKI của leaf certificate** (Dart chỉ truyền được leaf xuống native) và không thực hiện CA chain validation đầy đủ. Coi đây là tiện ích phụ, không phải cơ chế pinning chính. Cơ chế đầy đủ (full chain + CA validation) là `createDioAdapter()`.

Dùng `verifyPin()` trong interceptor tuỳ chỉnh hoặc WebSocket:

```dart
// Lấy DER bytes của leaf certificate từ kết nối TLS
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

### 4.6 Khả năng, hạn chế và khuyến nghị

Ràng buộc gốc của Flutter: `dart:io` **chỉ expose leaf certificate**, không có API thuần Dart nào lấy được full chain. Vì vậy SDK **uỷ quyền transport cho native** (OkHttp/URLSession) ở đường Dio để pinning chạy đúng nơi có full chain — đây là mô hình được xem là chuẩn nhất cho Flutter.

#### Đang làm được gì

| Năng lực | `createDioAdapter` (Dio) | `createIOClient` (http) | `verifyPin` |
|---|---|---|---|
| Khớp SPKI **full chain** (leaf/intermediate/root) | ✅ | ❌ chỉ leaf | ❌ chỉ leaf |
| Pin intermediate → chống rotation | ✅ | ❌ | ❌ |
| System CA validation (fail-closed) | ✅ (native) | một phần¹ | một phần |
| Chặn user-installed CA (Burp/Charles) | ✅ (native) | ❌² | — |

¹ `badCertificateCallback` chỉ chạy khi validation mặc định thất bại.
² MITM có cert chain hợp lệ tới CA được tin sẽ lọt (callback không kích hoạt).

#### Hạn chế khi sử dụng

**A. Bẩm sinh của Flutter — không cách nào trong SDK thoát được:**
- **Phạm vi phủ hẹp**: chỉ traffic đi qua đúng Dio instance có adapter, và chỉ tới `hostname` đã config. **KHÔNG** pin: WebView (`webview_flutter`), tải ảnh (`Image.network`, `CachedNetworkImage`), thư viện HTTP khác, plugin bên thứ ba. → Dồn API nhạy cảm về Dio instance đã gắn adapter.
- **Web build**: trình duyệt không cho app-level pinning.
- **Quản lý rotation/expiry**: cert hết hạn còn pin → app chết. Giảm nhẹ bằng pin **intermediate** ([4.1](#pin-intermediate-ca-để-sống-sót-qua-rotation)) + backup pin.

**B. Do cách hiện thực (đường Dio native transport):**
- **Buffered, không streaming**: no upload/download progress, no `ResponseType.stream`, no SSE. File lớn dễ tốn RAM → dùng Dio instance không-pin cho các ca này.
- **`CancelToken` chưa huỷ được request native**: Dio huỷ ở phía Dart nhưng request native vẫn chạy tới khi xong.
- **iOS gộp header đa giá trị**: `HTTPURLResponse` gộp nhiều header cùng tên (đặc biệt `Set-Cookie`) thành một chuỗi → interceptor cookie có thể parse sai. Android trả đúng list.
- **iOS `followRedirects=false` là best-effort**: URLSession mặc định vẫn follow redirect.

**C. Đường `http` package và `verifyPin`**: leaf-only, không đảm bảo an toàn — **không dùng cho dữ liệu nhạy cảm** (xem cảnh báo [4.3](#43-tích-hợp-với-http-package), [4.5](#45-xác-minh-thủ-công)).

#### Khuyến nghị nhanh

- Dữ liệu nhạy cảm → **Dio + `createDioAdapter()`**, pin **intermediate + backup**.
- Không dựa vào `createIOClient`/`verifyPin` như lớp bảo mật chính.

---

## 5. Exceptions

Tất cả lỗi từ SDK đều được throw dưới dạng `CShieldException`:

```dart
class CShieldException implements Exception {
  final CShieldErrorCode code;    // enum mã lỗi
  final String message;           // mô tả lỗi
  final Object? nativeCause;      // lỗi gốc từ native (nếu có)
}
```

**`CShieldErrorCode`:**

| Code | Nguyên nhân |
|---|---|
| `aipMissingHeader` | Response thiếu header `cs-timestamp` hoặc `cs-signature` |
| `aipTimestampExpired` | Timestamp nằm ngoài cửa sổ +-30 giây |
| `aipInvalidSignature` | Chữ ký response không hợp lệ (response bị tampering) |
| `aipSigningFailed` | Lỗi ký request (private key chưa sẵn sàng) |
| `aipDetectProxyCA` | Phát hiện proxy CA — AIP từ chối xử lý |
| `sslNotConfigured` | Gọi `createHttpClient()`/`createIOClient()`/`createDioAdapter()` trước khi gọi `CShieldSSL.configure()` |
| `sslPinMismatch` | Certificate của server không khớp với pin đã cấu hình |
| `notInitialized` | Gọi API trước khi gọi `CShieldEmbedded.initialize()` |
| `invalidArgument` | Tham số không hợp lệ |
| `nativeError` | Lỗi không xác định từ native SDK |

**Cách bắt lỗi:**

```dart
try {
  final response = await client.post(Uri.parse('https://api.example.com/login'), ...);
} on CShieldException catch (e) {
  switch (e.code) {
    case CShieldErrorCode.aipTimestampExpired:
      // Đồng hồ lệch hoặc bị replay attack
      _showError('Lỗi xác thực thời gian');
      break;
    case CShieldErrorCode.aipInvalidSignature:
      // Response bị can thiệp
      _logSecurityEvent('Response tampered');
      break;
    case CShieldErrorCode.sslPinMismatch:
      // Certificate không khớp — MITM hoặc cần rotate pin
      _logSecurityEvent('SSL pin mismatch');
      break;
    default:
      _showError('Lỗi bảo mật: ${e.message}');
  }
}
```

---

## Luồng tích hợp điển hình

```
main()
  +-- WidgetsFlutterBinding.ensureInitialized()
  +-- CShieldEmbedded.initialize()              // bắt buộc — trước runApp()
  +-- CShieldSSL.configure(pins, host)          // nếu dùng certificate pinning
  +-- runApp()

Khởi tạo HTTP client (singleton)
  +-- CShieldInterceptor(inner: CShieldSSL.createIOClient())   // http package
      // hoặc Dio:
  +-- dio.httpClientAdapter = CShieldSSL.createDioAdapter()
  +-- dio.interceptors.add(CShieldDioInterceptor())
```
