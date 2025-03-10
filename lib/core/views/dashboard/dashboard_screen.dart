import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../pigs/pigpen_management_screen.dart';
import '../feeds/feeds_screen.dart';
import '../events/events_screen.dart';
import '../expenses/expenses_screen.dart';
import '../sales/sales_screen.dart';
import '../reports/reports_screen.dart';
import '../../widgets/dashboard_card.dart';
import '../../models/pigpen_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box pigpenBox;
  int totalPigs = 0;

  @override
  void initState() {
    super.initState();
    _loadTotalPigs();

    // Listen for changes in the Hive box
    Hive.box('pigpens').listenable().addListener(_loadTotalPigs);
  }

  Future<void> _loadTotalPigs() async {
    pigpenBox = Hive.box('pigpens');
    int count = 0;

    for (int i = 0; i < pigpenBox.length; i++) {
      final pigpen = pigpenBox.getAt(i) as Pigpen;
      count += pigpen.pigs?.length ?? 0;
    }

    setState(() {
      totalPigs = count; // Update UI when pig count changes
    });
  }

  @override
  void dispose() {
    // Remove the listener when the screen is closed
    Hive.box('pigpens').listenable().removeListener(_loadTotalPigs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PigCare"),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
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
                      builder: (context) => PigpenManagementScreen()),
                );
              },
              count: totalPigs, // Show total pigs from all pigpens
            ),
            DashboardCard(
              title: "Feeds",
              icon: Icons.food_bank,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => FeedsScreen()));
              },
            ),
            DashboardCard(
              title: "Events",
              icon: Icons.event,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => EventsScreen()));
              },
            ),
            DashboardCard(
              title: "Expenses",
              icon: Icons.attach_money,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => ExpensesScreen()));
              },
            ),
            DashboardCard(
              title: "Sales",
              icon: Icons.shopping_cart,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => SalesScreen()));
              },
            ),
            DashboardCard(
              title: "Reports",
              icon: Icons.bar_chart,
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => ReportsScreen()));
              },
            ),
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
        ],
      ),
    );
  }
}
