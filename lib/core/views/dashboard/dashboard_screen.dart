import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/models/pigpen_model.dart';
import 'package:pigcare/core/models/task_model.dart';
import 'package:pigcare/core/views/feeds/feed_management_screen.dart';
import 'package:pigcare/core/views/pigs/pig_management_screen.dart';
import 'package:pigcare/core/views/pigpens/pigpen_management_screen.dart';
import 'package:pigcare/core/views/reports/reports_screen.dart';
import 'package:pigcare/core/views/sales/sales_management_screen.dart';
import 'package:pigcare/core/views/tasks/task_management_screen.dart';
import 'package:pigcare/core/views/expenses/expense_management_screen.dart';
import 'package:pigcare/core/widgets/dashboard_card.dart';

class DashboardScreen extends StatefulWidget {
  final List<Pig> allPigs;
  const DashboardScreen({super.key, required this.allPigs});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box<Pigpen> _pigpenBox;
  late Box<Feed> _feedsBox;
  late Box<PigTask> _tasksBox;
  int _totalPigs = 0;
  final double _lowStockThreshold = 10.0;

  @override
  void initState() {
    super.initState();
    _initializeHiveBoxes();
    _setupListeners();
  }

  Future<void> _initializeHiveBoxes() async {
    _pigpenBox = Hive.box<Pigpen>('pigpens');
    _feedsBox = Hive.box<Feed>('feedsBox');
    _tasksBox = Hive.box<PigTask>('pig_tasks');
    await _loadTotalPigs();
  }

  void _setupListeners() {
    _pigpenBox.listenable().addListener(_loadTotalPigs);
    _tasksBox.listenable().addListener(_updateDashboard);
  }

  Future<void> _loadTotalPigs() async {
    int count = 0;
    for (final pigpen in _pigpenBox.values) {
      count += pigpen.pigs.length;
    }

    if (mounted) {
      setState(() {
        _totalPigs = count;
      });
    }
  }

  void _updateDashboard() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pigpenBox.listenable().removeListener(_loadTotalPigs);
    _tasksBox.listenable().removeListener(_updateDashboard);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: _buildAppBar(),
      drawer: _buildDrawer(context),
      body: Column(
        children: [
          _buildSummaryCard(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildDashboardGrid(),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        "🐷 PigCare Dashboard",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.green[700],
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: _showNotifications,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
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
          child: Column(
            children: [
              isSmallScreen
                  ? Column(
                      children: [
                        _buildPigpenCount(isSmallScreen),
                        const SizedBox(height: 8),
                        _buildTotalPigsCount(isSmallScreen),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPigpenCount(isSmallScreen),
                        _buildTotalPigsCount(isSmallScreen),
                      ],
                    ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.grey),
              const SizedBox(height: 12),
              isSmallScreen
                  ? Column(
                      children: [
                        _buildFeedsStatus(isSmallScreen),
                        const SizedBox(height: 8),
                        _buildTasksStatus(isSmallScreen),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFeedsStatus(isSmallScreen),
                        _buildTasksStatus(isSmallScreen),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        DashboardCard(
          title: "Pigpens",
          icon: Icons.home,
          onTap: () => _navigateToPigpenManagement(),
        ),
        DashboardCard(
          title: "Pigs",
          icon: Icons.pets,
          onTap: () => _navigateToPigManagement(),
        ),
        DashboardCard(
          title: "Feeds",
          icon: Icons.food_bank,
          onTap: () => _navigateToFeedManagement(),
        ),
        DashboardCard(
          title: "Tasks",
          icon: Icons.event,
          onTap: () => _navigateToTaskManagement(),
        ),
        DashboardCard(
          title: "Expenses",
          icon: Icons.attach_money,
          onTap: () => _navigateToExpenseManagement(),
        ),
        DashboardCard(
          title: "Sales",
          icon: Icons.shopping_cart,
          onTap: () => _navigateToSalesManagement(),
        ),
        DashboardCard(
          title: "Reports",
          icon: Icons.bar_chart,
          onTap: () => _navigateToReports(),
        ),
      ],
    );
  }

  // Navigation methods
  Future<void> _navigateToPigpenManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PigpenManagementScreen()),
    );
    await _loadTotalPigs();
  }

  void _navigateToPigManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PigManagementScreen(
          pigpenIndex: 0,
          allPigs: widget.allPigs,
          pig: Pig(
            tag: '',
            breed: '',
            gender: '',
            stage: '',
            weight: 0,
            source: '',
            dob: '',
            doe: '',
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToFeedManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FeedManagementScreen()),
    );
    setState(() {});
  }

  void _navigateToTaskManagement() {
    final allPigs = _pigpenBox.values.expand((pigpen) => pigpen.pigs).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskManagementScreen(
          allPigs: allPigs,
          initialSelectedPigs: [],
        ),
      ),
    );
  }

  void _navigateToExpenseManagement() {
    final allPigs = _pigpenBox.values.expand((pigpen) => pigpen.pigs).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseManagementScreen(allPigs: allPigs),
      ),
    );
  }

  void _navigateToSalesManagement() {
    final allPigs = _pigpenBox.values.expand((pigpen) => pigpen.pigs).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesManagementScreen(allPigs: allPigs),
      ),
    );
  }

  void _navigateToReports() {
    final allPigs = _pigpenBox.values.expand((pigpen) => pigpen.pigs).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(allPigs: allPigs),
      ),
    );
  }

  void _showNotifications() {
    // TODO: Implement notifications functionality
  }

  // Summary card widgets
  Widget _buildPigpenCount(bool isSmallScreen) {
    return Text(
      "📦 Total Pigpens: ${_pigpenBox.length}",
      style: TextStyle(
        fontSize: isSmallScreen ? 16 : 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTotalPigsCount(bool isSmallScreen) {
    return Text(
      "🐷 Total Pigs: $_totalPigs",
      style: TextStyle(
        fontSize: isSmallScreen ? 16 : 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFeedsStatus(bool isSmallScreen) {
    return ValueListenableBuilder(
      valueListenable: _feedsBox.listenable(),
      builder: (context, Box<Feed> box, _) {
        final lowStockCount = box.values
            .where((feed) => feed.remainingQuantity < _lowStockThreshold)
            .length;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "📊 Feeds Level: "),
                  TextSpan(
                    text: lowStockCount > 0
                        ? "⚠️ $lowStockCount low stock"
                        : "✅ Stock good",
                    style: TextStyle(
                      color: lowStockCount > 0 ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTasksStatus(bool isSmallScreen) {
    return ValueListenableBuilder(
      valueListenable: _tasksBox.listenable(),
      builder: (context, Box<PigTask> box, _) {
        final upcomingTasks = box.values
            .where((task) =>
                !task.isCompleted && task.date.isAfter(DateTime.now()))
            .length;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event, size: 20, color: Colors.green),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "Tasks: "),
                  TextSpan(
                    text: upcomingTasks > 0
                        ? "$upcomingTasks Upcoming"
                        : "✅ All caught up",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: upcomingTasks > 0 ? Colors.blue : Colors.green,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
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
            onTap: () {
              // TODO: Implement settings navigation
            },
          ),
        ],
      ),
    );
  }
}
