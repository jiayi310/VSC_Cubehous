# Project: Cubehous Mobile App

## Overview
Cubehous is a Flutter mobile app (Android & iOS) for warehouse management and sales management. It is a large-scale project and will be built incrementally, starting from core features. The app connects entirely to a backend API — no data is stored locally on the device.

Backend website: https://app.cubehous.com
API base URL: `http://52.187.89.101:9000/api` (defined in `lib/api/base_client.dart`)
All API endpoint paths are in `lib/api/api_endpoints.dart`.

## Project Structure
```
lib/
  api/           — BaseClient (HTTP) + ApiEndpoints (all URL paths)
  common/        — SessionManager, DotsLoading, MyColor, ThemeNotifier, NetworkAwareWrapper
  models/        — Dart model classes with fromJson factories
  view/
    Sales/       — Quotation, SalesOrder, Collection pages
    General/     — Customer, Supplier, Location, Stock pages
    Warehouse/   — GRN, PutAway, Picking, Packing, StockTake, etc.
```

## Module Status (as of 2026-03-13)

### Done
| Module | Status | Notes |
|---|---|---|
| Auth / Login | ✅ | Remember me, session restore, splash screen |
| Customer | ✅ | List, Detail, Create, Edit (full CRUD) |
| Supplier | ✅ | List, Detail (view only) |
| Location | ✅ | List, Detail + Storage tab (view only) |
| Stock / Item List | ✅ | List, Detail (view only) |
| Quotation | ✅ | List, Detail, Create form |
| Sales Order | ✅ | List, Detail, Create form |
| Customer History | ✅ | Pick customer + date range → purchased items list (accessed from Sales Order AppBar) |
| Collection | ✅ | List, Detail, Create form (multi-order payment, photo upload) |

### Pending
| Module | Status |
|---|---|
| GRN, Put Away | ❌ Not started |
| Picking, Packing | ❌ Not started |
| Stock Take, Transfer, Adjustment | ❌ Not started |

## Modules NOT in App (backend website only)
- Item Creation, Supplier Creation, Sales Agent Creation, Purchase Order

---

## API & Auth Patterns

### Most POST requests include all four auth fields:
```dart
'apiKey': _apiKey,
'companyGUID': _companyGUID,
'userID': _userID,
'userSessionID': _userSessionID,
```
Load these at the top of every StatefulWidget that calls APIs:
```dart
_apiKey        = await SessionManager.getApiKey();
_companyGUID   = await SessionManager.getCompanyGUID();
_userID        = await SessionManager.getUserID();
_userSessionID = await SessionManager.getUserSessionID();
```

### Exceptions — some endpoints only need apiKey + companyGUID (no userID/userSessionID):
- `GetCollectListByCompany`
- `GetCollection`
- `GetPaymentTypeList`

### Payment type list parsing
`GetPaymentTypeList` may return a plain string array (`["Cash","Bank Transfer"]`) or an object array. Always handle both:
```dart
final raw = response as List<dynamic>;
final list = raw.map((e) {
  if (e is String) return PaymentTypeItem(paymentType: e);
  if (e is Map<String, dynamic>) return PaymentTypeItem.fromJson(e);
  return PaymentTypeItem(paymentType: e.toString());
}).where((pt) => pt.paymentType.isNotEmpty).toList();
```

### HTTP methods (via BaseClient):
- `BaseClient.get(url)` — for GET requests
- `BaseClient.post(url, body: {...})` — for POST requests
- Timeout: 30s. Error classes: `BadRequestException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `InternalServerException`, `TimeoutException`

### Parallel API calls:
```dart
final results = await Future.wait([apiCall1(), apiCall2()]);
```

---

## Coding Conventions

### Models
- All model files in `lib/models/` use `fromJson` factory constructors
- Use private helpers for safe type parsing, e.g.:
  ```dart
  static double _toD(dynamic v) => v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
  ```
- If two model files define the same class name, use `hide` to resolve:
  ```dart
  import '../models/Storage.dart' hide Location;
  ```

### Pagination (list views)
- Page size: 20 (`_pageSize = 20`)
- State vars: `_currentPage`, `_totalCount`, `_isLoading`, `_isLoadingMore`
- Infinite scroll: listen to `_scrollController`, trigger load when 200px from bottom
- Guard: `if (_isLoading || _isLoadingMore || !_hasMore) return;`
- Reset to page 0 on new search/filter/sort
- API response includes `Pagination` object with `totalRecord`, `pageIndex`, `pageSize`

### Loading Indicator
Always use `DotsLoading()` (never `CircularProgressIndicator`):
```dart
import 'package:cubehous/common/dots_loading.dart';
// Initial load:
Center(child: DotsLoading())
// Load more (bottom of list):
if (_isLoadingMore) Padding(padding: ..., child: DotsLoading())
```

### UI / Design Patterns
- **Theme**: Light + dark. Colors defined in `lib/common/my_color.dart`
  - Primary: `#153D81` (navy blue)
  - Secondary/accent: `#FF9700` (amber orange)
  - Dark background: `#0F1923`, dark surface: `#1A2740`
- **Border radius**: 12px for cards/containers, 10px for chips
- **Padding**: 16px horizontal, 14px vertical for list tiles
- **Sort/Filter**: `DraggableScrollableSheet` inside `showModalBottomSheet`
- **Pickers**: bottom sheet with paginated search (see `_CustomerPickerSheet` in `quotation_form.dart`)
- **Image pick**: use `image_picker` package. Show a bottom sheet with Camera / Gallery options:
  ```dart
  import 'package:image_picker/image_picker.dart';
  import 'dart:convert'; import 'dart:io';
  final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
  // Convert to base64 for API:
  final bytes = await File(file!.path).readAsBytes();
  final base64Str = base64Encode(bytes);
  ```
- **Date filter**: two `_DatePill` widgets (From / To), each opens `showDatePicker`. Default fromDate = first day of current month: `DateTime(DateTime.now().year, DateTime.now().month, 1)`
- **Currency**: `NumberFormat('#,##0.00')` from `intl` package
- **Badges**: small colored containers (orange for filter count, navy-tinted for type labels)
- **Avatars**: initials in colored circle (navy bg, white text)
- **VOID / inactive**: red badge shown inline in list tile and AppBar

### Session Manager (key fields)
```dart
SessionManager.getUserID()           // int
SessionManager.getUserMappingID()    // int
SessionManager.getCompanyID()        // int
SessionManager.getDefaultLocationID() // int
SessionManager.getUserSessionID()    // String
SessionManager.getCompanyGUID()      // String
SessionManager.getApiKey()           // String
SessionManager.getCompanyName()      // String
SessionManager.getUsername()         // String
SessionManager.getIsEnableTax()      // bool
SessionManager.getSalesDecimalPoint() // int (default 2)
```

---

## Design Guidelines
- Dark theme and light theme support
- Multi-language support
- Simple, clean, and user-friendly UI
- QR code / Barcode scanner: Scan → Call API → API returns value (for items and storage/location)

---

## Commands
```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/simulator
flutter build apk        # Android build
flutter build ios        # iOS build
flutter analyze          # Lint / static analysis
flutter test             # Run all tests
```
