import 'package:flutter/material.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/customer.dart';
import 'customer_form.dart';

class CustomerDetailPage extends StatefulWidget {
  final String customerCode;

  const CustomerDetailPage({super.key, required this.customerCode});

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  Customer? _customer;
  bool _isLoading = true;
  String? _error;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    await _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getCustomer,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'customerCode': widget.customerCode,
        },
      );
      final customer = Customer.fromJson(response as Map<String, dynamic>);
      setState(() {
        _customer = customer;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _openEdit() async {
    if (_customer == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormPage(customer: _customer),
      ),
    );
    if (updated == true) {
      _loadCustomer();
    }
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
          child: const Text('Customer',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        centerTitle: true,
        actions: [
          if (_customer != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: _openEdit,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: DotsLoading());
    }
    if (_error != null) {
      return _buildError();
    }
    if (_customer == null) {
      return const Center(child: Text('Customer not found'));
    }
    return _buildDetail(_customer!);
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
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            const Text('Failed to load customer',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadCustomer,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(Customer c) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card with avatar + code + type badge
          _buildHeaderCard(c),
          const SizedBox(height: 16),

          // General info
          _buildSection('General', [
            _buildRow('Customer Code', c.customerCode),
            _buildRow('Name', c.name),
            if (c.name2.isNotEmpty) _buildRow('Name 2', c.name2),
            _buildRow('Customer Type', c.customerType.isNotEmpty ? c.customerType : '-'),
            _buildRow('Sales Agent', c.salesAgent.isNotEmpty ? c.salesAgent : '-'),
            _buildRow('Price Category', 'Category ${c.priceCategory}'),
          ]),
          const SizedBox(height: 16),

          // Contact
          _buildSection('Contact', [
            _buildRow('Phone 1', c.phone1 ?? '-'),
            _buildRow('Phone 2', c.phone2 ?? '-'),
            _buildRow('Fax 1', c.fax1 ?? '-'),
            _buildRow('Fax 2', c.fax2 ?? '-'),
            _buildRow('Email', c.email ?? '-'),
            _buildRow('Attention', c.attention ?? '-'),
          ]),
          const SizedBox(height: 16),

          // Billing address
          _buildSection('Billing Address', [
            _buildRow('Address 1', c.address1 ?? '-'),
            _buildRow('Address 2', c.address2 ?? '-'),
            _buildRow('Address 3', c.address3 ?? '-'),
            _buildRow('Address 4', c.address4 ?? '-'),
            _buildRow('Post Code', c.postCode ?? '-'),
          ]),
          const SizedBox(height: 16),

          // Delivery address
          _buildSection('Delivery Address', [
            _buildRow('Address 1', c.deliverAddr1 ?? '-'),
            _buildRow('Address 2', c.deliverAddr2 ?? '-'),
            _buildRow('Address 3', c.deliverAddr3 ?? '-'),
            _buildRow('Address 4', c.deliverAddr4 ?? '-'),
            _buildRow('Post Code', c.deliverPostCode ?? '-'),
          ]),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Customer c) {
    final primary = Theme.of(context).colorScheme.primary;
    const palette = [
      Color(0xFF5C6BC0), Color(0xFF26A69A), Color(0xFFEF5350),
      Color(0xFFAB47BC), Color(0xFF29B6F6), Color(0xFFFF7043),
      Color(0xFF66BB6A), Color(0xFFEC407A),
    ];
    final color = c.name.isNotEmpty
        ? palette[c.name.codeUnitAt(0) % palette.length]
        : primary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c.customerCode,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primary),
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 6),
                Text(c.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
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
                child: Text(
                  value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}
