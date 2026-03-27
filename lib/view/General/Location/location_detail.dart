import 'package:flutter/material.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/status_badge.dart';
import '../../../common/session_manager.dart';
import '../../../models/location.dart';
import '../../../models/storage.dart' hide Location;

class LocationDetailPage extends StatefulWidget {
  final Location location;
  const LocationDetailPage({super.key, required this.location});

  @override
  State<LocationDetailPage> createState() => _LocationDetailPageState();
}

class _LocationDetailPageState extends State<LocationDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _infoScrollController = ScrollController();
  final _storageScrollController = ScrollController();

  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  List<StorageDropdownDto> _storageList = [];
  bool _storageLoading = true;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _infoScrollController.dispose();
    _storageScrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    await _loadStorage();
  }

  Future<void> _loadStorage() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    setState(() {
      _storageLoading = true;
      _storageError = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getLocationWithStorage,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'locationID': widget.location.locationID,
        },
      );

      List<StorageDropdownDto> items = [];
      if (response is List<dynamic> && response.isNotEmpty) {
        final first = response.first as Map<String, dynamic>;
        final raw = first['storageDropdownDtoList'];
        if (raw is List<dynamic>) {
          items = raw
              .map((e) =>
                  StorageDropdownDto.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      setState(() {
        _storageList = items;
        _storageLoading = false;
      });
    } catch (e) {
      setState(() {
        _storageLoading = false;
        _storageError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onDoubleTap: () {
            final sc = _tabController.index == 0
                ? _infoScrollController
                : _storageScrollController;
            if (sc.hasClients) {
              sc.animateTo(0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut);
            }
          },
          child: Text(
            loc.location ?? 'Location',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.info_outline, size: 18),
              text: 'Info',
              iconMargin: EdgeInsets.only(bottom: 2),
            ),
            Tab(
              icon: Icon(Icons.shelves, size: 18),
              text: 'Storage',
              iconMargin: EdgeInsets.only(bottom: 2),
            ),
          ],
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 2.5,
          labelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(loc),
          _buildStorageTab(),
        ],
      ),
    );
  }

  // ── Info Tab ────────────────────────────────────────────────────────

  Widget _buildInfoTab(Location loc) {
    final address = [
      loc.address1,
      loc.address2,
      loc.address3,
      loc.address4,
    ].where((p) => p != null && p.isNotEmpty).join('\n');

    return ListView(
      controller: _infoScrollController,
      children: [
        _SectionHeader(title: 'GENERAL'),
        _DetailRow(label: 'Location', value: loc.location ?? '—'),
        _DetailRow(
          label: 'Status',
          valueWidget: Align(
            alignment: Alignment.centerRight,
            child: StatusBadge.active(loc.isActive),
          ),
        ),
        if (address.isNotEmpty) ...[
          _SectionHeader(title: 'ADDRESS'),
          _DetailRow(label: 'Address', value: address),
          if ((loc.postCode ?? '').isNotEmpty)
            _DetailRow(label: 'Post Code', value: loc.postCode!),
        ],
        if ((loc.phone1 ?? '').isNotEmpty ||
            (loc.phone2 ?? '').isNotEmpty ||
            (loc.fax1 ?? '').isNotEmpty ||
            (loc.fax2 ?? '').isNotEmpty) ...[
          _SectionHeader(title: 'CONTACT'),
          if ((loc.phone1 ?? '').isNotEmpty)
            _DetailRow(label: 'Phone 1', value: loc.phone1!),
          if ((loc.phone2 ?? '').isNotEmpty)
            _DetailRow(label: 'Phone 2', value: loc.phone2!),
          if ((loc.fax1 ?? '').isNotEmpty)
            _DetailRow(label: 'Fax 1', value: loc.fax1!),
          if ((loc.fax2 ?? '').isNotEmpty)
            _DetailRow(label: 'Fax 2', value: loc.fax2!),
        ],
      ],
    );
  }

  // ── Storage Tab ─────────────────────────────────────────────────────

  Widget _buildStorageTab() {
    if (_storageLoading) {
      return const Center(child: DotsLoading());
    }

    if (_storageError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 52,
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.6)),
              const SizedBox(height: 14),
              const Text('Failed to load storage',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                _storageError ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadStorage,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_storageList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shelves,
                  size: 52,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2)),
              const SizedBox(height: 14),
              Text(
                'No storage found',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _storageScrollController,
      itemCount: _storageList.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08)),
      itemBuilder: (context, i) {
        final s = _storageList[i];
        return _StorageTile(storage: s);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Storage tile
// ─────────────────────────────────────────────────────────────────────

class _StorageTile extends StatelessWidget {
  final StorageDropdownDto storage;
  const _StorageTile({required this.storage});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shelves, size: 22, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storage.storageCode ?? '—',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (storage.isDisabled)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Disabled',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _DetailRow({required this.label, this.value, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                  ),
            ),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value ?? '—',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.right,
                ),
          ),
        ],
      ),
    );
  }
}
