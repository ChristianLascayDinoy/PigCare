import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/models/task_model.dart';
import 'package:pigcare/core/views/pigs/pig_management_screen.dart';
import '../pigpens/pigpen_management_screen.dart';
import '../feeds/feed_management_screen.dart';
import '../tasks/task_management_screen.dart';
import '../expenses/expense_management_screen.dart';
import '../sales/sales_management_screen.dart';
import '../reports/reports_screen.dart';
import '../../widgets/dashboard_card.dart';
import '../../models/pigpen_model.dart';

class DashboardScreen extends StatefulWidget {
  final List<Pig> allPigs;
  const DashboardScreen({super.key, required this.allPigs});

  @override
  // ignore: library_private_types_in_public_api
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box pigpenBox;
  int totalPigs = 0;
  late Box<Feed> feedsBox;
  late Box<PigTask> _tasksBox;
  final double lowStockThreshold = 10.0;

  @override
  void initState() {
    super.initState();
    feedsBox = Hive.box<Feed>('feedsBox');
    _tasksBox = Hive.box<PigTask>('pig_tasks');
    _loadTotalPigs();
    Hive.box<Pigpen>('pigpens').listenable().addListener(_loadTotalPigs);
    _tasksBox.listenable().addListener(_updateDashboard);
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
    _tasksBox.listenable().removeListener(_updateDashboard);
    super.dispose();
  }

  void _updateDashboard() {
    setState(() {});
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
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PigpenManagementScreen(),
                        ),
                      );
                      // Optional: Refresh data when returning
                      _loadTotalPigs();
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
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => FeedManagementScreen()),
                      );
                      // This will trigger a rebuild when returning
                      setState(() {});
                    },
                  ),
                  DashboardCard(
                    title: "Tasks",
                    icon: Icons.event,
                    onTap: () {
                      final pigpenBox = Hive.box<Pigpen>('pigpens');
                      final allPigs = pigpenBox.values
                          .expand((pigpen) => pigpen.pigs)
                          .toList();

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskManagementScreen(
                            allPigs: allPigs,
                            initialSelectedPigs: [],
                          ),
                        ),
                      );
                      // Remove the setState() call - it's not needed anymore
                    },
                  ),
                  DashboardCard(
                    title: "Expenses",
                    icon: Icons.attach_money,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ExpenseManagementScreen()),
                      );
                    },
                  ),
                  DashboardCard(
                    title: "Sales",
                    icon: Icons.shopping_cart,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                SalesManagementScreen(allPigs: widget.allPigs)),
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
    // Calculate feed metrics
    int lowStockCount = 0;
    for (final feed in feedsBox.values) {
      if (feed.quantity < lowStockThreshold) {
        lowStockCount++;
      }
    }

    // Count upcoming tasks
    int upcomingTasks = 0;
    for (final task in _tasksBox.values) {
      if (!task.isCompleted && task.date.isAfter(DateTime.now())) {
        upcomingTasks++;
      }
    }

    return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(children: [
          // First row (same as original)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("📦 Total Pigpens: ${pigpenBox.length}",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("🐷 Total Pigs: $totalPigs",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          // Divider line
          const Divider(height: 1, color: Colors.grey),
          const SizedBox(height: 12),
          // Second row with feeds and tasks
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            ValueListenableBuilder(
              valueListenable: feedsBox.listenable(),
              builder: (context, Box<Feed> box, _) {
                // Calculate feed metrics
                int lowStockCount = 0;
                for (final feed in box.values) {
                  if (feed.remainingQuantity < lowStockThreshold) {
                    lowStockCount++;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: "📊 Feeds Level: "),
                            TextSpan(
                              text: lowStockCount > 0
                                  ? "⚠️ $lowStockCount low stock"
                                  : "✅ Stock good",
                              style: TextStyle(
                                color: lowStockCount > 0
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ])
                  ],
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _tasksBox.listenable(),
              builder: (context, Box<PigTask> box, _) {
                // Count upcoming tasks
                int upcomingTasks = box.values
                    .where((task) =>
                        !task.isCompleted && task.date.isAfter(DateTime.now()))
                    .length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(children: [
                      const Icon(Icons.event, size: 24, color: Colors.green),
                      const SizedBox(width: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: "Upcoming Tasks: "),
                            TextSpan(
                              text: upcomingTasks > 0
                                  ? "$upcomingTasks Upcoming"
                                  : "✅ All caught up",
                              style: TextStyle(
                                fontSize: 14,
                                color: upcomingTasks > 0
                                    ? Colors.blue
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ])
                  ],
                );
              },
            )
          ])
        ]));
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
