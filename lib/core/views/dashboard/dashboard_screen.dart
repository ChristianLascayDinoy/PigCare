import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/views/pigs/pig_management_screen.dart';
import '../pigs/pigpen_management_screen.dart';
import '../feeds/feeds_screen.dart';
import '../events/event_management_screen.dart';
import '../expenses/expenses_screen.dart';
import '../sales/sales_screen.dart';
import '../reports/reports_screen.dart';
import '../../widgets/dashboard_card.dart';
import '../../models/pigpen_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box pigpenBox;
  int totalPigs = 0;

  @override
  void initState() {
    super.initState();
    _loadTotalPigs();
    Hive.box<Pigpen>('pigpens').listenable().addListener(_loadTotalPigs);
  }

  Future<void> _loadTotalPigs() async {
    pigpenBox = Hive.box<Pigpen>('pigpens');
    int count = 0;

    for (int i = 0; i < pigpenBox.length; i++) {
      final pigpen = pigpenBox.getAt(i) as Pigpen;
      count += pigpen.pigs.length;
    }

    setState(() {
      totalPigs = count;
    });
  }

  @override
  void dispose() {
    Hive.box('pigpens').listenable().removeListener(_loadTotalPigs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text("🐷 PigCare Dashboard",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Column(
        children: [
          _buildSummaryCard(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  DashboardCard(
                    title: "Pigpens",
                    icon: Icons.home,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PigpenManagementScreen()),
                      );
                    },
                  ),
                  DashboardCard(
                    title: "Pigs",
                    icon: Icons.pets,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PigManagementScreen(
                                  pigpenIndex: 0,
                                  allPigs: [],
                                  pig: Pig(
                                      tag: '',
                                      breed: '',
                                      gender: '',
                                      stage: '',
                                      weight: 0,
                                      source: '',
                                      dob: '',
                                      doe: ''),
                                )),
                      );
                    },
                  ),
                  DashboardCard(
                    title: "Feeds",
                    icon: Icons.food_bank,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => FeedManagementScreen()),
                      );
                    },
                  ),
                  DashboardCard(
                      title: "Events",
                      icon: Icons.event,
                      onTap: () {
                        final pigpenBox = Hive.box<Pigpen>('pigpens');
                        final allPigs = pigpenBox.values
                            .expand((pigpen) => pigpen.pigs)
                            .toList();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventManagementScreen(
                              allPigs: allPigs,
                              initialSelectedPigs: [], // Empty if no specific pigs pre-selected
                            ),
                          ),
                        );
                      }),
                  DashboardCard(
                    title: "Expenses",
                    icon: Icons.attach_money,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ExpensesScreen()),
                      );
                    },
                  ),
                  DashboardCard(
                    title: "Sales",
                    icon: Icons.shopping_cart,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SalesScreen()),
                      );
                    },
                  ),
                  DashboardCard(
                    title: "Reports",
                    icon: Icons.bar_chart,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ReportsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("📦 Pigpens: ${pigpenBox.length}",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("🐷 Total Pigs: $totalPigs",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
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
