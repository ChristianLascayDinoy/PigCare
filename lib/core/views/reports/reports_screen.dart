import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../../models/pig_model.dart';
import '../../models/expense_model.dart';
import '../../models/sale_model.dart';
import '../../models/task_model.dart';

class ReportsScreen extends StatefulWidget {
  final List<Pig> allPigs;

  const ReportsScreen({
    super.key,
    required this.allPigs,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Box<Expense> _expensesBox;
  late Box<Sale> _salesBox;
  late Box<PigTask> _tasksBox;
  bool _isLoading = true;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  // Report data variables
  Map<String, dynamic> _pigReports = {};
  Map<String, dynamic> _feedReports = {};
  Map<String, dynamic> _eventReports = {};
  Map<String, dynamic> _expenseReports = {};
  Map<String, dynamic> _salesReports = {};

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    try {
      _expensesBox = Hive.box<Expense>('expenses');
      _salesBox = Hive.box<Sale>('sales');
      _tasksBox = Hive.box<PigTask>('pig_tasks');
      await _loadReports();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading reports: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadReports() async {
    // Calculate all reports
    _pigReports = _calculatePigReports();
    _feedReports = _calculateFeedReports();
    _eventReports = _calculateEventReports();
    _expenseReports = _calculateExpenseReports();
    _salesReports = _calculateSalesReports();
  }

  Map<String, dynamic> _calculatePigReports() {
    final pigs = widget.allPigs;
    final now = DateTime.now();

    return {
      'totalPigs': pigs.length,
      'byGender': {
        'male': pigs.where((p) => p.gender == 'Male').length,
        'female': pigs.where((p) => p.gender == 'Female').length,
      },
      'byStage': {
        'piglet': pigs.where((p) => p.stage == 'Piglet').length,
        'weaner': pigs.where((p) => p.stage == 'Weaner').length,
        'grower': pigs.where((p) => p.stage == 'Grower').length,
        'finisher': pigs.where((p) => p.stage == 'Finisher').length,
        'sow': pigs.where((p) => p.stage == 'Sow').length,
        'boar': pigs.where((p) => p.stage == 'Boar').length,
      },
      'averageAge': _calculateAverageAge(pigs),
    };
  }

  double _calculateAverageAge(List<Pig> pigs) {
    if (pigs.isEmpty) return 0;

    final now = DateTime.now();
    var totalDays = 0;

    for (final pig in pigs) {
      final dob = DateTime.parse(pig.dob);
      totalDays += now.difference(dob).inDays;
    }

    return (totalDays / pigs.length) / 30; // Return age in months
  }

  Map<String, dynamic> _calculateFeedReports() {
    // This would come from your feed tracking system
    return {
      'totalFeedCost': 0,
      'feedConsumption': {},
      'feedTypes': {},
    };
  }

  Map<String, dynamic> _calculateEventReports() {
    final events = _tasksBox.values
        .where((e) =>
            e.date.isAfter(_dateRange.start) && e.date.isBefore(_dateRange.end))
        .toList();

    return {
      'totalEvents': events.length,
      'byType': {
        'health': events.where((e) => e.taskType == 'Health').length,
        'breeding': events.where((e) => e.taskType == 'Breeding').length,
        'feeding': events.where((e) => e.taskType == 'Feeding').length,
        'movement': events.where((e) => e.taskType == 'Movement').length,
        'other': events.where((e) => e.taskType == 'Other').length,
      },
      'completionRate': events.isEmpty
          ? 0
          : events.where((e) => e.isCompleted).length / events.length,
    };
  }

  Map<String, dynamic> _calculateExpenseReports() {
    final expenses = _expensesBox.values
        .where((e) =>
            e.date.isAfter(_dateRange.start) && e.date.isBefore(_dateRange.end))
        .toList();

    if (expenses.isEmpty) return {'total': 0, 'byCategory': {}};

    double total = expenses.fold(0, (sum, e) => sum + e.amount);

    Map<String, double> byCategory = {};
    for (final expense in expenses) {
      byCategory[expense.category] =
          (byCategory[expense.category] ?? 0) + expense.amount;
    }

    return {
      'total': total,
      'byCategory': byCategory,
      'average': total / expenses.length,
    };
  }

  Map<String, dynamic> _calculateSalesReports() {
    final sales = _salesBox.values
        .where((s) =>
            s.date.isAfter(_dateRange.start) && s.date.isBefore(_dateRange.end))
        .toList();

    if (sales.isEmpty) return {'total': 0, 'count': 0, 'average': 0};

    double total = sales.fold(0, (sum, s) => sum + s.amount);

    return {
      'total': total,
      'count': sales.length,
      'average': total / sales.length,
      'byPigType': _calculateSalesByPigType(sales),
    };
  }

  Map<String, dynamic> _calculateSalesByPigType(List<Sale> sales) {
    Map<String, dynamic> result = {};

    for (final sale in sales) {
      try {
        final pig = widget.allPigs.firstWhere((p) => p.tag == sale.pigTag);
        final type = pig.stage;
        result[type] = {
          'count': (result[type]?['count'] ?? 0) + 1,
          'total': (result[type]?['total'] ?? 0) + sale.amount,
        };
      } catch (e) {
        // Pig not found
      }
    }

    return result;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
        _isLoading = true;
      });
      await _loadReports();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Farm Reports"),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Select date range',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDateRangeHeader(),
                  const SizedBox(height: 20),
                  _buildReportCard(
                    title: "Pig Reports",
                    icon: Icons.pets,
                    data: _pigReports,
                    buildContent: _buildPigReportContent,
                  ),
                  const SizedBox(height: 16),
                  _buildReportCard(
                    title: "Feed Reports",
                    icon: Icons.fastfood,
                    data: _feedReports,
                    buildContent: _buildFeedReportContent,
                  ),
                  const SizedBox(height: 16),
                  _buildReportCard(
                    title: "Event Reports",
                    icon: Icons.event,
                    data: _eventReports,
                    buildContent: _buildEventReportContent,
                  ),
                  const SizedBox(height: 16),
                  _buildReportCard(
                    title: "Expense Reports",
                    icon: Icons.attach_money,
                    data: _expenseReports,
                    buildContent: _buildExpenseReportContent,
                  ),
                  const SizedBox(height: 16),
                  _buildReportCard(
                    title: "Sales Reports",
                    icon: Icons.shopping_cart,
                    data: _salesReports,
                    buildContent: _buildSalesReportContent,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDateRangeHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DateFormat('MMM dd, yyyy').format(_dateRange.start),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text("to"),
        ),
        Text(
          DateFormat('MMM dd, yyyy').format(_dateRange.end),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required String title,
    required IconData icon,
    required Map<String, dynamic> data,
    required Widget Function(Map<String, dynamic>) buildContent,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: Colors.green[700]),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            buildContent(data),
          ],
        ),
      ),
    );
  }

  Widget _buildPigReportContent(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportItem("Total Pigs", data['totalPigs'].toString()),
        const SizedBox(height: 12),
        const Text("By Gender:", style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child:
                  _buildReportItem("Male", data['byGender']['male'].toString()),
            ),
            Expanded(
              child: _buildReportItem(
                  "Female", data['byGender']['female'].toString()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text("By Stage:", style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildReportItem("Piglets", data['byStage']['piglet'].toString()),
            _buildReportItem("Weaners", data['byStage']['weaner'].toString()),
            _buildReportItem("Growers", data['byStage']['grower'].toString()),
            _buildReportItem(
                "Finishers", data['byStage']['finisher'].toString()),
            _buildReportItem("Sows", data['byStage']['sow'].toString()),
            _buildReportItem("Boars", data['byStage']['boar'].toString()),
          ],
        ),
        const SizedBox(height: 12),
        _buildReportItem(
            "Average Age", "${data['averageAge'].toStringAsFixed(1)} months"),
      ],
    );
  }

  Widget _buildFeedReportContent(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportItem("Total Feed Cost",
            NumberFormat.currency(symbol: '\$').format(data['totalFeedCost'])),
        const SizedBox(height: 12),
        const Text("Coming soon...", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildEventReportContent(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportItem("Total Events", data['totalEvents'].toString()),
        const SizedBox(height: 12),
        _buildReportItem("Completion Rate",
            "${(data['completionRate'] * 100).toStringAsFixed(1)}%"),
        const SizedBox(height: 12),
        const Text("By Type:", style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildReportItem("Health", data['byType']['health'].toString()),
            _buildReportItem("Breeding", data['byType']['breeding'].toString()),
            _buildReportItem("Feeding", data['byType']['feeding'].toString()),
            _buildReportItem("Movement", data['byType']['movement'].toString()),
            _buildReportItem("Other", data['byType']['other'].toString()),
          ],
        ),
      ],
    );
  }

  Widget _buildExpenseReportContent(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportItem("Total Expenses",
            NumberFormat.currency(symbol: '\$').format(data['total'])),
        _buildReportItem("Average Expense",
            NumberFormat.currency(symbol: '\$').format(data['average'])),
        const SizedBox(height: 12),
        if (data['byCategory'].isNotEmpty)
          const Text("By Category:",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ...data['byCategory'].entries.map(
              (entry) => _buildReportItem(
                entry.key,
                NumberFormat.currency(symbol: '\$').format(entry.value),
              ),
            ),
      ],
    );
  }

  Widget _buildSalesReportContent(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportItem("Total Sales",
            NumberFormat.currency(symbol: '\$').format(data['total'])),
        _buildReportItem("Number of Sales", data['count'].toString()),
        _buildReportItem("Average Sale",
            NumberFormat.currency(symbol: '\$').format(data['average'])),
        const SizedBox(height: 12),
        if (data['byPigType'].isNotEmpty)
          const Text("By Pig Type:",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ...data['byPigType'].entries.map(
              (entry) => _buildReportItem(
                entry.key,
                "${entry.value['count']} sales (${NumberFormat.currency(symbol: '\$').format(entry.value['total'])})",
              ),
            ),
      ],
    );
  }

  Widget _buildReportItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
