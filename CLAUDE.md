# Project: Cubehous Mobile App

## Overview
Flutter mobile app (Android & iOS) for warehouse + sales management. Backend API only — no local data storage.

- Backend: https://app.cubehous.com
- API base URL: `http://52.187.89.101:9000/api` (in `lib/api/base_client.dart`)
- All endpoints: `lib/api/api_endpoints.dart`

## Project Structure
```
lib/
  api/           — BaseClient (HTTP) + ApiEndpoints (all URL paths)
  common/        — SessionManager, DotsLoading, MyColor, ThemeNotifier,
                   DatePill, DirectionChip, StatusBadge, PaginationBar
  models/        — Dart model classes with fromJson factories
  view/
    Sales/       — Quotation, SalesOrder, Collection, CustomerHistory
    General/     — Customer, Supplier, Location, Stock
    Warehouse/   — StockTake, Receiving
    Common/      — Shared pickers (CustomerPicker, ItemPicker, LocationPicker, etc.)
```

## Module Status (as of 2026-03-26)

| Module | Status | Notes |
|---|---|---|
| Auth / Login | ✅ | Remember me, session restore, splash |
| Customer | ✅ | List, Detail, Create, Edit (full CRUD) |
| Supplier | ✅ | List, Detail (view only) |
| Location | ✅ | List, Detail + Storage tab (view only) |
| Stock / Item List | ✅ | List, Detail (view only) |
| Quotation | ✅ | List, Detail, Create, Edit, Delete + draft save + PDF download + transfer to Sales |
| Sales Order | ✅ | List, Detail, Create |
| Customer History | ✅ | From Sales Order AppBar — date range → items |
| Collection | ✅ | List, Detail, Create, Edit + draft save + multi-order + payment distribution + photo upload |
| Purchase Order | ✅ | List, Detail (view only — create on web only) |
| Stock Take | ✅ | List, Detail, Create/Edit (QR scanner + manual, draft save) |
| Receiving | ✅ | List, Detail, Create (PO picker, auto-fill items) |
| GRN, Put Away | ❌ Not started | |
| Picking, Packing | ❌ Not started | |
| Transfer, Adjustment | ❌ Not started | |

**Web only (not in app):** Item Creation, Supplier Creation, Sales Agent Creation

---

## API & Auth

### Standard POST body (4 auth fields):
```dart
'apiKey': _apiKey, 'companyGUID': _companyGUID,
'userID': _userID, 'userSessionID': _userSessionID,
```
Load via `Future.wait([SessionManager.getApiKey(), ...])` in `_init()`.

### Exceptions (apiKey + companyGUID only):
`GetCollectListByCompany`, `GetCollection`, `GetPaymentTypeList`

### HTTP methods:
- `BaseClient.post(url, body: {...})` — POST
- `BaseClient.postBytes(url, body: {...})` — POST returning raw bytes (PDF)
- `BaseClient.get(url)` — GET
- Timeout: 30s. Errors: `BadRequestException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `InternalServerException`, `TimeoutException`

---

## Coding Conventions

### Models (`lib/models/`)
- `fromJson` factory constructors, top-level `_toD(dynamic v)` for safe double parsing
- Name collision: `import '...' hide SomeClass;`

### Pagination (list pages)
Reference: `receiving_list.dart`, `stock_take_list.dart`

**State variables:**
```dart
int _currentPage = 0;
int _totalPages  = 1;
int _totalCount  = 0;
int _itemsPerPage = 20; // override with await SessionManager.getItemsPerPage()
```

**API request body fields** (sent every page load):
```dart
'pageIndex': page,          // 0-based
'pageSize': _itemsPerPage,
'sortBy': _sortBy,
'isSortByAscending': _sortAsc,
'searchTerm': _searchQuery.isEmpty ? null : _searchQuery,
```

**Parsing the response** (`paginationOpt` / `pagination` field on the response model):
```dart
final totalRecord = result.pagination?.totalRecord ?? items.length;
final pageSize    = result.pagination?.pageSize    ?? _itemsPerPage;
_totalCount = totalRecord;
_totalPages = pageSize > 0 ? (totalRecord / pageSize).ceil() : 1;
if (_totalPages < 1) _totalPages = 1;
```
`Pagination` model fields: `totalRecord`, `pageIndex`, `pageSize`, `sortBy`, `isSortByAscending`, `searchTerm`.

**PaginationBar widget** (below the ListView, inside a Column):
```dart
PaginationBar(
  currentPage: _currentPage,
  totalPages:  _totalPages,
  isLoading:   _isLoading,
  primary:     primary,
  onPrev: _currentPage > 0        ? () => _fetch(page: _currentPage - 1) : null,
  onNext: _currentPage < _totalPages - 1 ? () => _fetch(page: _currentPage + 1) : null,
),
```

**"Showing X–Y of Z records" footer** — rendered as the last item in `ListView.builder` (`i == _items.length`):
```dart
final start = _currentPage * _itemsPerPage + 1;
final end   = ((_currentPage + 1) * _itemsPerPage).clamp(0, _totalCount);
// in itemBuilder when i == _items.length:
Text('Showing $start–$end of $_totalCount records',
  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)))
```

**Reset on search/filter/sort change:** call `_fetch(page: 0)` and scroll to top via `_scrollController.jumpTo(0)`.

### Common widgets (`lib/common/`)
- **Loading**: always `DotsLoading()` — never `CircularProgressIndicator`
- **Date filter row**: `DatePill(label, date, onTap, primary)` — two pills (From/To)
- **Sort direction**: `DirectionChip(label, icon, selected, onTap)`
- **Status badges**: `StatusBadge(label, color)` / `StatusBadge.active(bool)` / `.voidBadge()` / `.merged()` / `.adjusted()`
- **Form section header**: `FormSectionHeader(icon, title, expanded, onToggle, badge?)` — collapsible section with optional badge count
- **Form total summary row**: `FormTotalPriceSummaryRow(label, value, muted, valueColor?)` — label + right-aligned value with optional color
- **Form input decoration**: `formInputDeco(context, prefixText?)` — standard text field decoration for form sheets
- **Sheet input decoration**: `sheetInputDeco(context)` — compact decoration for bottom sheet fields

### Draft save pattern (new forms only)
Reference: `quotation_form.dart`, `stock_take_form.dart`, `collection_form.dart`
1. `_hasChanges` getter — checks if form has unsaved data
2. `_saveDraft()` — `jsonEncode` form state → `SessionManager.saveXxxDraft()`
3. `_restoreDraft(j)` — restore from decoded JSON on init
4. `_checkAndRestoreDraft()` — called in `_init()` (skip if edit mode)
5. `PopScope` + `_onWillPop()` — shows Save Draft / Discard dialog on back
6. Clear draft on successful save: `SessionManager.clearXxxDraft()`
- Draft keys in SessionManager: `quotation_draft`, `stock_take_draft`, `collection_draft`

### List page pattern
Reference: `purchase_list.dart`, `stock_take_list.dart`
- AppBar: title + add button (access right check) + date pills + search field + filter button
- Filter badge (orange dot with count) over filter icon
- `Slidable` tiles with swipe-to-delete (access right check → confirm dialog → API → remove from list)
- `DraggableScrollableSheet` sort bottom sheet with `DropdownButtonFormField` + `DirectionChip` row

### Detail page pattern
Reference: `purchase_detail.dart`, `stock_take_detail.dart`, `quotation_detail.dart`
- `TabBar` + `TabBarView` (3 tabs: Info / Supplier or Location / Items)
- Status bar above tabs (totals or item count + status badges)
- VOID badge in AppBar actions when `isVoid`
- `PopupMenuButton` for PDF download + delete + edit (access right check per action)
- Delete: confirm dialog → API → `Navigator.pop(context, true)` so list page can refresh
- Error display: `e is BadRequestException ? e.message : 'Failed: $e'` — show only body for 400 errors
- `_SectionHeader`, `_DetailRow`, `_AddressBlock` helper widgets

### Form page pattern
Reference: `quotation_form.dart`, `stock_take_form.dart`, `receiving_form.dart`
- `PopScope(canPop: false)` with `_onWillPop()` for back-press handling
- Collapsible sections with `AnimatedSize`
- Pickers: push full page (CustomerPicker, ItemPicker, LocationPicker) or bottom sheet
- `Slidable` line items with swipe-to-delete
- Save button in AppBar (TextButton) or full-width `FilledButton` at bottom

### Line item card design
Reference: `_LineItemCard` in `quotation_form.dart`, `_ItemTile` in `quotation_detail.dart`
- Container: `BorderRadius.circular(12)`, `cs.outline.withValues(alpha: 0.18)` border
- Leading: 40×40 circle index badge OR 50×50 product image
- Row 1: stockCode (bold, primary) | qty (bold, primary)
- Row 2: description (muted, fontSize 12, ellipsis)
- Row 3: UOM + inline badges (discount=orange, tax=teal) + Spacer + total
- Tap to expand price breakdown

### Access rights
Check with `_accessRights.contains('MODULE_ACTION')`. Show `_showNoAccessDialog()` if denied.
Common patterns: `PURCHASE_DELETE`, `RECEIVING_ADD`, `RECEIVING_DELETE`, `STOCKTAKE_ADD`, `QUOTATION_ADD`, `QUOTATION_EDIT`, `QUOTATION_DELETE`, `QUOTATION_TRANSFERSALES`, `COLLECT_EDIT`.

### Collection form specifics
Reference: `collection_form.dart`, `collection_form_sales_picker.dart`
- Payment distribution: `_distributePayment()` allocates `_paymentTotalCtrl` value across orders in sequence
- Outstanding summary: `sum(sale.outstanding) - paymentTotal` — can be negative (overpayment), green if positive, orange if negative
- Auto-fill payment total: only when current value is `0` after picking orders
- `CollectionSalesPickerPage` — full-page picker with pagination, search, sort filter sheet; returns `List<SalesListItem>`
- Slidable order cards: swipe to remove order without touching payment total input

---

## Session Manager — key fields
```dart
SessionManager.getApiKey()            // String
SessionManager.getCompanyGUID()       // String
SessionManager.getUserID()            // int
SessionManager.getUserSessionID()     // String
SessionManager.getUserMappingID()     // int
SessionManager.getCompanyID()         // int
SessionManager.getDefaultLocationID() // int
SessionManager.getCompanyName()       // String
SessionManager.getUsername()          // String
SessionManager.getIsEnableTax()       // bool
SessionManager.getSalesDecimalPoint() // int (default 2)
SessionManager.getItemsPerPage()      // int
SessionManager.getImageMode()         // String ('show'|'hide')
SessionManager.getUserAccessRight()   // List<String>
// Draft methods: saveXxxDraft / getXxxDraft / clearXxxDraft / hasXxxDraft (quotation, stock_take, collection)
```

---

## Design Guidelines
- Light + dark theme. Primary: `#153D81` (navy), Accent: `#FF9700` (orange)
- Dark bg: `#0F1923`, dark surface: `#1A2740`
- `Mycolor.discountTextColor` (orange), `Mycolor.taxTextColor` (teal)
- Border radius: 12px cards, 4–6px badges
- Currency: `NumberFormat('#,##0.00')` | Qty: `NumberFormat('#,##0.##')`
- QR/Barcode: scan → API → returns stock/storage data

## Commands
```bash
flutter pub get && flutter run
flutter build apk  # Android
flutter analyze    # Lint
```
