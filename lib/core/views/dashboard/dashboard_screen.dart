import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/models/pigpen_model.dart';
import 'package:pigcare/core/models/task_model.dart';
import 'package:pigcare/core/models/feeding_schedule_model.dart';
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
  late Box<FeedingSchedule> _feedingScheduleBox;
  int _totalPigs = 0;
  final double _lowStockThreshold = 10.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeHiveBoxes();
  }

  Future<void> _initializeHiveBoxes() async {
    try {
      _pigpenBox = await Hive.openBox<Pigpen>('pigpens');
      _feedsBox = await Hive.openBox<Feed>('feedsBox');
      _tasksBox = await Hive.openBox<PigTask>('pig_tasks');
      _feedingScheduleBox =
          await Hive.openBox<FeedingSchedule>('feedingSchedules');
      await _loadTotalPigs();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing data: ${e.toString()}')),
      );
    }
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

  int _getUpcomingFeedingSchedulesCount() {
    if (!_feedingScheduleBox.isOpen) return 0;

    final now = TimeOfDay.now();
    final currentTimeInMinutes = now.hour * 60 + now.minute;

    return _feedingScheduleBox.values.where((schedule) {
      try {
        final scheduleTimeParts = schedule.time.split(':');
        if (scheduleTimeParts.length != 2) return false;

        final scheduleHour = int.tryParse(scheduleTimeParts[0]) ?? 0;
        final scheduleMinute = int.tryParse(scheduleTimeParts[1]) ?? 0;
        final scheduleTimeInMinutes = scheduleHour * 60 + scheduleMinute;

        // Consider schedules within the next 2 hours as "upcoming"
        return scheduleTimeInMinutes > currentTimeInMinutes &&
            scheduleTimeInMinutes <= currentTimeInMinutes + 120;
      } catch (e) {
        return false;
      }
    }).length;
  }

  @override
  void dispose() {
    _pigpenBox.listenable().removeListener(_loadTotalPigs);
    _tasksBox.listenable().removeListener(() {
      setState(() {});
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: Image.asset(
              'lib/assets/images/pigcare_logo.jpg',
              height: 40,
              width: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            "PigCare Dashboard",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      backgroundColor: Colors.green[700],
      elevation: 0,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: _showNotifications,
            ),
            if (_feedingScheduleBox.isOpen)
              ValueListenableBuilder(
                valueListenable: _feedingScheduleBox.listenable(),
                builder: (context, Box<FeedingSchedule> box, _) {
                  final upcomingCount = _getUpcomingFeedingSchedulesCount();
                  if (upcomingCount == 0) return const SizedBox();

                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        upcomingCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
          ],
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
                        const SizedBox(height: 8),
                        _buildFeedingScheduleStatus(isSmallScreen),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFeedsStatus(isSmallScreen),
                        _buildTasksStatus(isSmallScreen),
                        _buildFeedingScheduleStatus(isSmallScreen),
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
          imagePath: 'lib/assets/images/pigpen.png',
          onTap: () => _navigateToPigpenManagement(),
        ),
        DashboardCard(
          title: "Pigs",
          imagePath: 'lib/assets/images/pig.png',
          onTap: () => _navigateToPigManagement(),
        ),
        DashboardCard(
          title: "Feeds",
          imagePath: 'lib/assets/images/feed.png',
          onTap: () => _navigateToFeedManagement(),
        ),
        DashboardCard(
          title: "Tasks",
          imagePath: 'lib/assets/images/task.png',
          onTap: () => _navigateToTaskManagement(),
        ),
        DashboardCard(
          title: "Expenses",
          imagePath: 'lib/assets/images/expenses.png',
          onTap: () => _navigateToExpenseManagement(),
        ),
        DashboardCard(
          title: "Sales",
          imagePath: 'lib/assets/images/sales.png',
          onTap: () => _navigateToSalesManagement(),
        ),
        DashboardCard(
          title: "Reports",
          imagePath: 'lib/assets/images/reports.png',
          onTap: () => _navigateToReports(),
        ),
      ],
    );
  }

  Widget _buildPigpenCount(bool isSmallScreen) {
    return Text(
      "Total Pigpens: ${_pigpenBox.length}",
      style: TextStyle(
        fontSize: isSmallScreen ? 16 : 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTotalPigsCount(bool isSmallScreen) {
    return Text(
      "Total Pigs: $_totalPigs",
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
            const SizedBox(width: 4),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "Feeds: "),
                  TextSpan(
                    text:
                        lowStockCount > 0 ? "$lowStockCount low" : "Stock good",
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
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Count pending tasks (due today)
        final pendingTasks = box.values.where((task) {
          final taskDate =
              DateTime(task.date.year, task.date.month, task.date.day);
          return !task.isCompleted && taskDate.isAtSameMomentAs(today);
        }).length;

        // Count upcoming tasks (due in the future)
        final upcomingTasks = box.values.where((task) {
          final taskDate =
              DateTime(task.date.year, task.date.month, task.date.day);
          return !task.isCompleted && taskDate.isAfter(today);
        }).length;

        String statusText;
        Color statusColor;

        if (pendingTasks > 0 && upcomingTasks > 0) {
          statusText = "$pendingTasks pending, $upcomingTasks upcoming";
          statusColor = Colors.orange;
        } else if (pendingTasks > 0) {
          statusText = "$pendingTasks pending";
          statusColor = Colors.orange;
        } else if (upcomingTasks > 0) {
          statusText = "$upcomingTasks upcoming";
          statusColor = Colors.blue;
        } else {
          statusText = "All caught up";
          statusColor = Colors.green;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "Tasks: "),
                  TextSpan(
                    text: statusText,
                    style: TextStyle(color: statusColor),
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

  Widget _buildFeedingScheduleStatus(bool isSmallScreen) {
    if (!_feedingScheduleBox.isOpen) {
      return const SizedBox();
    }

    return ValueListenableBuilder(
      valueListenable: _feedingScheduleBox.listenable(),
      builder: (context, Box<FeedingSchedule> box, _) {
        final upcomingCount = _getUpcomingFeedingSchedulesCount();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "Feeding Schedule: "),
                  TextSpan(
                    text:
                        upcomingCount > 0 ? "$upcomingCount upcoming" : "None",
                    style: TextStyle(
                      color: upcomingCount > 0 ? Colors.orange : Colors.grey,
                      fontWeight: FontWeight.bold,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipOval(
                  child: Image.asset(
                    'lib/assets/images/pigcare_logo.jpg',
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ],
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
    final allPigpens = _pigpenBox.values.toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskManagementScreen(
          allPigs: allPigs,
          allPigpens: allPigpens,
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
    final pigpenBox = Hive.box<Pigpen>('pigpens');
    final allPigs = pigpenBox.values.expand((pigpen) => pigpen.pigs).toList();
    final allPigpens = pigpenBox.values.toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesManagementScreen(
          allPigs: allPigs,
          allPigpens: allPigpens,
        ),
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
    if (!_feedingScheduleBox.isOpen) return;

    final upcomingSchedules = _feedingScheduleBox.values.where((schedule) {
      try {
        final now = TimeOfDay.now();
        final currentTimeInMinutes = now.hour * 60 + now.minute;
        final scheduleTimeParts = schedule.time.split(':');
        if (scheduleTimeParts.length != 2) return false;

        final scheduleHour = int.tryParse(scheduleTimeParts[0]) ?? 0;
        final scheduleMinute = int.tryParse(scheduleTimeParts[1]) ?? 0;
        final scheduleTimeInMinutes = scheduleHour * 60 + scheduleMinute;

        return scheduleTimeInMinutes > currentTimeInMinutes;
      } catch (e) {
        return false;
      }
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Upcoming Feeding Schedules"),
        content: upcomingSchedules.isEmpty
            ? const Text("No upcoming feeding schedules")
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: upcomingSchedules.length,
                  itemBuilder: (context, index) {
                    final schedule = upcomingSchedules[index];
                    return ListTile(
                      title: Text("${schedule.pigName} (${schedule.pigId})"),
                      subtitle: Text(
                        "Pen: ${schedule.pigpenId}\n"
                        "Feed: ${schedule.feedType} (${schedule.quantity} kg)\n"
                        "Time: ${schedule.time}",
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
