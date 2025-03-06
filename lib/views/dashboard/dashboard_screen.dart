import 'package:flutter/material.dart';
import '../pigs/pigpen_management_screen.dart';
import '../feeds/feeds_screen.dart';
import '../events/events_screen.dart';
import '../expenses/expenses_screen.dart';
import '../sales/sales_screen.dart';
import '../reports/reports_screen.dart';
import '../../widgets/dashboard_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PigCare"),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Handle notification click
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2, // Two columns
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            DashboardCard(
                title: "Pigs",
                icon: Icons.pets,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PigpenManagementScreen()));
                }),
            DashboardCard(
                title: "Feeds",
                icon: Icons.food_bank,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => FeedsScreen()));
                }),
            DashboardCard(
                title: "Events",
                icon: Icons.event,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => EventsScreen()));
                }),
            DashboardCard(
                title: "Expenses",
                icon: Icons.attach_money,
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ExpensesScreen()));
                }),
            DashboardCard(
                title: "Sales",
                icon: Icons.shopping_cart,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => SalesScreen()));
                }),
            DashboardCard(
                title: "Reports",
                icon: Icons.bar_chart,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => ReportsScreen()));
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.green[700]),
            child: const Text(
              'Menu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
