import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cubehous'),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              // TODO: Implement language switch
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Language switch coming soon')),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Cubehous Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Inbound'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Inbound page
              },
            ),
            ListTile(
              leading: const Icon(Icons.outbound),
              title: const Text('Outbound'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Outbound page
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text('Stock List'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Stock List
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Customers'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Customers
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Suppliers'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Suppliers
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Locations'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Locations
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to Reports
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement logout
              },
            ),
          ],
        ),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: [
          _buildModuleCard(
            context,
            'Inbound',
            Icons.arrow_downward,
            Colors.green,
            () {
              // TODO: Navigate to Inbound
            },
          ),
          _buildModuleCard(
            context,
            'Outbound',
            Icons.arrow_upward,
            Colors.blue,
            () {
              // TODO: Navigate to Outbound
            },
          ),
          _buildModuleCard(
            context,
            'Inventory',
            Icons.inventory,
            Colors.orange,
            () {
              // TODO: Navigate to Inventory
            },
          ),
          _buildModuleCard(
            context,
            'Sales',
            Icons.shopping_cart,
            Colors.purple,
            () {
              // TODO: Navigate to Sales
            },
          ),
          _buildModuleCard(
            context,
            'Customers',
            Icons.people,
            Colors.teal,
            () {
              // TODO: Navigate to Customers
            },
          ),
          _buildModuleCard(
            context,
            'Suppliers',
            Icons.business,
            Colors.indigo,
            () {
              // TODO: Navigate to Suppliers
            },
          ),
          _buildModuleCard(
            context,
            'Locations',
            Icons.location_on,
            Colors.red,
            () {
              // TODO: Navigate to Locations
            },
          ),
          _buildModuleCard(
            context,
            'Reports',
            Icons.analytics,
            Colors.amber,
            () {
              // TODO: Navigate to Reports
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
