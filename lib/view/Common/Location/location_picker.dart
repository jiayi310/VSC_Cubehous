import 'package:cubehous/api/api_endpoints.dart';
import 'package:cubehous/api/base_client.dart';
import 'package:cubehous/common/dots_loading.dart';
import 'package:cubehous/models/storage.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────
// Location Picker Page
// ─────────────────────────────────────────────────────────────────────

class LocationPickerPage extends StatefulWidget {
  final String module;
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const LocationPickerPage({
    super.key,
    required this.module,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await BaseClient.post(
        ApiEndpoints.getLocationList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
        },
      );
      if (resp is List<dynamic>) {
        setState(() {
          _locations = resp.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() {
          _locations = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: DotsLoading())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _locations.length,
                  itemBuilder: (_, i) {
                    final loc = _locations[i];
                    final id = (loc['locationID'] as int?) ?? 0;
                    final name = (loc['location'] as String?) ?? '';
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.location_on_outlined,
                            size: 20, color: primary),
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      onTap: () => Navigator.pop(
                          context, (locationID: id, locationName: name)),
                    );
                  },
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Storage Picker Page
// ─────────────────────────────────────────────────────────────────────

class StoragePickerPage extends StatefulWidget {
  final String module;
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;
  final int locationID;

  const StoragePickerPage({
    super.key,
    required this.module,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
    required this.locationID,
  });

  @override
  State<StoragePickerPage> createState() => _StoragePickerPageState();
}

class _StoragePickerPageState extends State<StoragePickerPage> {
  
  List<StorageDropdownDto> _storages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getLocationWithStorage,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'locationID': widget.locationID,
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
        _storages = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Storage',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: DotsLoading())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _storages.isEmpty
                  ? Center(
                      child: Text('No storages found',
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4))),
                    )
                  : ListView.builder(
                      itemCount: _storages.length,
                      itemBuilder: (_, i) {
                        final s = _storages[i];
                        final disabled = s.isDisabled;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: disabled
                                  ? Colors.grey.withValues(alpha: 0.1)
                                  : primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.warehouse_outlined,
                                size: 20,
                                color: disabled ? Colors.grey : primary),
                          ),
                          title: Text(
                            s.storageCode ?? '',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: disabled
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.35)
                                    : null),
                          ),
                          subtitle: disabled
                              ? Text('Disabled',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey
                                          .withValues(alpha: 0.6)))
                              : null,
                          enabled: !disabled,
                          onTap: disabled
                              ? null
                              : () => Navigator.pop(context, s),
                        );
                      },
                    ),
    );
  }
}