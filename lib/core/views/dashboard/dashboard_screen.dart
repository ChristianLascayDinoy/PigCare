import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../pigs/pigpen_management_screen.dart';
import '../feeds/feeds_screen.dart';
import '../events/events_screen.dart';
import '../expenses/expenses_screen.dart';
import '../sales/sales_screen.dart';
import '../reports/reports_screen.dart';
import '../../widgets/dashboard_card.dart';
import '../../models/pig_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box<Pig> pigsBox;

  @override
  void initState() {
    super.initState();
    _openBox();
  }

  Future<void> _openBox() async {
    pigsBox = await Hive.openBox<Pig>('pigsBox'); // Open Hive box
    setState(() {}); // Refresh UI after box is opened
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
        child: FutureBuilder(
          future: Hive.openBox<Pig>('pigsBox'), // Ensure Hive box is opened
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator()); // Show loading spinner
            }

            if (!snapshot.hasData) {
              return const Center(child: Text("No data available"));
            }

            final pigsBox = snapshot.data as Box<Pig>;
            final int totalPigs = pigsBox.length; // Get total pig count

            return GridView.count(
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
                  count: totalPigs, // Show dynamic pig count
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
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EventsScreen()));
                  },
                ),
                DashboardCard(
                  title: "Expenses",
                  icon: Icons.attach_money,
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ExpensesScreen()));
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
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ReportsScreen()));
                  },
                ),
              ],
            );
          },
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
