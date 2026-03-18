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

## Module Status (as of 2026-03-18)

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
  - Discount color: `Mycolor.discountTextColor` (orange)
  - Tax color: `Mycolor.taxTextColor` (teal/green)
- **Border radius**: 12px for cards/containers, 4px for inline badges
- **Padding**: 16px horizontal, 14px vertical for list tiles; `fromLTRB(12, 4, 12, 24)` for card list views
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
- **Qty format**: `NumberFormat('#,##0.##')` for quantities (trims trailing zeros)
- **Badges**: small colored containers (orange for filter count, navy-tinted for type labels)
- **Avatars**: initials in colored circle (navy bg, white text)
- **VOID / inactive**: red badge shown inline in list tile and AppBar

---

### Line Item Card Design (use for any document with line items)
Reference implementation: `_LineItemCard` in `lib/view/Sales/quotation_form.dart`
Reference detail card: `_ItemTile` / `_ItemGridCard` in `lib/view/Sales/quotation_detail.dart`

**Card container:**
```dart
Container(
  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
  decoration: BoxDecoration(
    color: (cardTheme.color ?? cs.surface).withValues(alpha: 0.5),
    border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
    borderRadius: BorderRadius.circular(12),
  ),
)
```

**Card layout — 3 rows in content area (leading = index badge or 50×50 image):**
- Row 1: `stockCode` (small, bold, primary, left) | `x qty` (bold, primary, right)
- Row 2: `description` (fontSize 12, muted, maxLines 1, ellipsis)
- Row 3: `uom` (muted, small) + inline badges + `Spacer()` + line total (bold, primary)

**Index badge (when no image):**
```dart
Container(
  width: 40, height: 40,
  decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), shape: BoxShape.circle),
  child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primary))),
)
```

**Inline badges (Row 3):**
```dart
// Discount badge (orange) — shown when discount > 0
Container(
  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
  child: Text('-10%', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
)
// Tax badge (teal) — shown when taxCode is set
Container(
  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
  child: Text('SR6', style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.w600)),
)
```

**Tap-to-expand breakdown (appended inside the column, below Row 3):**
```dart
if (_expanded) ...[
  const SizedBox(height: 8),
  Divider(height: 1, color: cs.outline.withValues(alpha: 0.2)),
  const SizedBox(height: 8),
  _breakdownRow('Subtotal', fmt.format(qty * unitPrice), cs),
  if (discAmt > 0) ...[
    const SizedBox(height: 3),
    _breakdownRow('Discount (10%)', '- ${fmt.format(discAmt)}', cs, valueColor: Colors.orange),
  ],
  if (taxCode != null) ...[
    const SizedBox(height: 3),
    _breakdownRow('Tax (SR 6%)', '+ ${fmt.format(taxAmt)}', cs, valueColor: Colors.teal),
  ],
]
// _breakdownRow helper:
Widget _breakdownRow(String label, String value, ColorScheme cs, {Color? valueColor}) => Row(
  children: [
    Text(label, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
    const Spacer(),
    Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
        color: valueColor ?? cs.onSurface.withValues(alpha: 0.65))),
  ],
);
```

**Form list padding:** `const EdgeInsets.fromLTRB(12, 4, 12, 24)` with `ListView.builder` (no separator — cards have `Padding(bottom: 10)` built-in).

---

### Document Detail Page Structure (List + Detail + Create form)
Reference: `lib/view/Sales/quotation_list.dart`, `quotation_detail.dart`, `quotation_form.dart`

**Detail page tabs:** Info | Customer | Items (use `TabBar` + `TabBarView`)
- **Info tab**: DOCUMENT section (doc fields) → CUSTOMER section → TOTAL section
- **TOTAL section layout** (`_PriceSummaryRow` for each line):
  - Subtotal
  - Discount (orange, `Mycolor.discountTextColor`) — only if > 0
  - Tax Amt (teal, `Mycolor.taxTextColor`) — only if != 0
  - Taxable Amt — only if != 0
  - Divider
  - **Total Amt** (bold, primary, fontSize 18)
- Discount amount computed from line items: `doc.lines.fold(0.0, (s, l) => s + l.qty * l.unitPrice * l.discount / 100)`

**Totals bar** (above tabs): shows `Total Amt` with large bold amount — quick glance without opening Info tab.

**Items tab display modes** (toggle in AppBar):
- List mode: `_ItemTile` cards with index badge
- Image mode: `_ItemGridCard` cards with 50×50 product image

---

### Discount Field (compound discount support)
Field label: `Discount` (not "Discount %"). Keyboard: `TextInputType.text`. Formatter: `[\d.+%]`.
- `10` → 10% off (backward compat — plain number = percentage)
- `10%` → 10% off
- `10%+5` → 10% off first, then RM5 fixed off remainder
- `10%+5%` → chain: 10% then 5% off remainder
Parser lives in `_LineItem._parseDiscountAmt(String text, double subtotal)` in `quotation_form.dart`.

---

### Quantity Field Rules
- Minimum qty = 1 (cannot be 0)
- Stepper clamps to `1.0` minimum
- Text field calls `_clampQty()` on `onEditingComplete` and `onTapOutside`

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
