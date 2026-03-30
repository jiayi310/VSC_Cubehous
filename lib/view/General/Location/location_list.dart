import 'package:flutter/material.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/status_badge.dart';
import '../../../common/session_manager.dart';
import '../../../models/location.dart';
import 'location_detail.dart';

class LocationListPage extends StatefulWidget {
  const LocationListPage({super.key});

  @override
  State<LocationListPage> createState() => _LocationListPageState();
}

class _LocationListPageState extends State<LocationListPage> {
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  List<Location> _locations = [];
  List<Location> _filtered = [];
  bool _isLoading = false;
  String? _error;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    await _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getLocationList,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
        },
      );
      final list = (response as List<dynamic>)
          .map((e) => Location.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => (a.location ?? '').compareTo(b.location ?? ''));
      setState(() {
        _locations = list;
        _filtered = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _searchQuery = q;
      _filtered = q.isEmpty
          ? _locations
          : (_locations.where((l) {
              return (l.location ?? '').toLowerCase().contains(q) ||
                  (l.address1 ?? '').toLowerCase().contains(q) ||
                  (l.phone1 ?? '').toLowerCase().contains(q);
            }).toList()
            ..sort((a, b) => (a.location ?? '').compareTo(b.location ?? '')));
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onDoubleTap: () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
          child: const Text('Locations',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search locations...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearSearch,
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: DotsLoading());
    if (_error != null) return _buildError();
    if (_filtered.isEmpty) return _buildEmpty();
    return _buildList();
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _fetchLocations,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _filtered.length,
        itemBuilder: (context, i) => _LocationTile(
          location: _filtered[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LocationDetailPage(location: _filtered[i]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
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
            const Text('Failed to load locations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
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
              onPressed: _fetchLocations,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warehouse_outlined,
                size: 52,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No locations found',
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
}

// ─────────────────────────────────────────────────────────────────────
// Location tile
// ─────────────────────────────────────────────────────────────────────

class _LocationTile extends StatelessWidget {
  final Location location;
  final VoidCallback onTap;

  const _LocationTile({required this.location, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = location.location ?? '';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            // Avatar
            _LocationAvatar(name: name),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge.active(location.isActive),
                    ],
                  ),
                  const SizedBox(height: 2),
                    _IconRow(
                      icon: Icons.phone_outlined,
                      text: location.phone1?? '-',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationAvatar extends StatelessWidget {
  final String name;
  const _LocationAvatar({required this.name});

  static const _palette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF29B6F6),
    Color(0xFFFF7043),
    Color(0xFF66BB6A),
    Color(0xFFEC407A),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = name.isNotEmpty
        ? _palette[name.codeUnitAt(0) % _palette.length]
        : _palette[0];
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
