# Project: Cubehous Mobile App

## Overview
Cubehous is a Flutter mobile app (Android & iOS) for warehouse management and sales management. It is a large-scale project and will be built incrementally, starting from core features. The app connects entirely to a backend API — no data is stored locally on the device.

Backend website: https://app.cubehous.com
All data is fetched and submitted via API. API URLs are stored in the `api/` folder.

## Design Guidelines
- Dark theme and light theme support
- Multi-language support
- Simple, clean, and user-friendly UI
- QR code / Barcode scanner integration for item entry [Scan -> Call API -> API return value]
- QR code / Barcode scanner for storage/location

## Project Structure
- `models/` — data model classes
- `api/` — to store all API endpoint URLs
- `common/` — shared/reusable methods and utilities across classes

## Modules Included in App

### Sales
- **Quotation** — create and manage quotations
- **Sales Order** — manage sales orders
- **Collection** — collect payment

### Warehouse — Inbound
- **Good Receive Note (GRN)** — receive incoming stock
- **Put Away** — assign received stock to storage locations

### Warehouse — Outbound
- **Picking** — pick items for orders
- **Packing** — pack picked items

### Warehouse — General
- **Stock Take** — perform stock counts
- **Stock Transfer** — transfer stock between locations/storage
- **Stock Adjustment** — adjust stock quantities

### Master Data
- **Customer** — Create / Edit / View / Delete
- **Supplier** — View only
- **Location / Storage** — View only
- **Item List** — View only

### Analytics & Reporting
- TBC

## Modules NOT in App (backend website only)
- Item Creation
- Supplier Creation
- Sales Agent Creation
- Purchase Order 

## Development Approach
Build step by step, starting with the most basic functions first before moving to advanced features.

## Commands
```bash
# Install dependencies
flutter pub get

# Run on a connected device / simulator
flutter run

# Build
flutter build apk          # Android
flutter build ios          # iOS

# Lint / static analysis
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart
```

