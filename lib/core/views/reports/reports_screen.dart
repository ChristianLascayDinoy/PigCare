import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pigcare/core/models/feed_model.dart';
import '../../models/pig_model.dart';
import '../../models/expense_model.dart';
import '../../models/sale_model.dart';
import '../../models/task_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';

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
  Map<String, dynamic> pigReports = {};
  Map<String, dynamic> feedReports = {};
  Map<String, dynamic> taskReports = {};
  Map<String, dynamic> expenseReports = {};
  Map<String, dynamic> salesReports = {};
  Map<String, dynamic> financialSummary = {};

  // Custom icons map
  final Map<String, String> reportIcons = {
    'Pig Reports': 'lib/assets/images/pig.png',
    'Feed Reports': 'lib/assets/images/feed.png',
    'Task Reports': 'lib/assets/images/task.png',
    'Expense Reports': 'lib/assets/images/expenses.png',
    'Sales Reports': 'lib/assets/images/sales.png',
    'Financial Summary': 'lib/assets/images/expenses.png',
  };

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    try {
      _expensesBox = await Hive.openBox<Expense>('expenses');
      _salesBox = await Hive.openBox<Sale>('sales');
      _tasksBox = await Hive.openBox<PigTask>('pig_tasks');
      await _loadReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _calculatePigReports(),
        _calculateFeedReports(),
        _calculateTaskReports(),
        _calculateExpenseReports(),
        _calculateSalesReports(),
        _calculateFinancialSummary(),
      ]);

      setState(() {
        pigReports = results[0] ?? {};
        feedReports = results[1] ?? {};
        taskReports = results[2] ?? {};
        expenseReports = results[3] ?? {};
        salesReports = results[4] ?? {};
        financialSummary = results[5] ?? {};
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating reports: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _calculatePigReports() async {
    final pigs = widget.allPigs;
    if (pigs.isEmpty) return {};

    final now = DateTime.now();
    final ageGroups = <String, int>{
      '0-3 months': 0,
      '3-6 months': 0,
      '6-12 months': 0,
      '1-2 years': 0,
      '2+ years': 0,
    };

    for (final pig in pigs) {
      final age = now.difference(DateTime.parse(pig.dob)).inDays;
      if (age <= 90) {
        ageGroups['0-3 months'] = (ageGroups['0-3 months'] ?? 0) + 1;
      } else if (age <= 180) {
        ageGroups['3-6 months'] = (ageGroups['3-6 months'] ?? 0) + 1;
      } else if (age <= 365) {
        ageGroups['6-12 months'] = (ageGroups['6-12 months'] ?? 0) + 1;
      } else if (age <= 730) {
        ageGroups['1-2 years'] = (ageGroups['1-2 years'] ?? 0) + 1;
      } else {
        ageGroups['2+ years'] = (ageGroups['2+ years'] ?? 0) + 1;
      }
    }

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
      'byAge': ageGroups,
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

  Future<Map<String, dynamic>> _calculateFeedReports() async {
    final feedsBox = await Hive.openBox<Feed>('feedsBox'); // Updated box name
    final expensesBox = await Hive.openBox<Expense>('expenses');

    final allFeeds = feedsBox.values.toList();
    final feedExpenses = expensesBox.values
        .where((e) =>
            e.category == 'Feed' &&
            e.date.isAfter(_dateRange.start) &&
            e.date.isBefore(_dateRange.end))
        .toList();

    if (allFeeds.isEmpty && feedExpenses.isEmpty) return {};

    // Calculate total feed cost in the date range
    final totalFeedCost = feedExpenses.fold(0.0, (sum, e) => sum + e.amount);

    // Calculate current inventory (only feeds purchased within date range)
    final currentInventory = allFeeds
        .where((f) =>
            f.purchaseDate.isAfter(_dateRange.start) &&
            f.purchaseDate.isBefore(_dateRange.end))
        .fold(0.0, (sum, f) => sum + f.remainingQuantity);

    // Calculate feed consumption (initial - remaining for feeds in date range)
    double consumption = allFeeds
        .where((f) =>
            f.purchaseDate.isAfter(_dateRange.start) &&
            f.purchaseDate.isBefore(_dateRange.end))
        .fold(0.0, (sum, f) => sum + (f.quantity - f.remainingQuantity));

    // Group by feed type for current inventory
    final feedTypes = <String, Map<String, dynamic>>{};
    for (final feed in allFeeds.where((f) =>
        f.purchaseDate.isAfter(_dateRange.start) &&
        f.purchaseDate.isBefore(_dateRange.end))) {
      if (!feedTypes.containsKey(feed.name)) {
        feedTypes[feed.name] = {
          'quantity': 0.0,
          'remaining': 0.0,
          'consumed': 0.0,
          'percentage': 0.0,
          'brands': <String, int>{},
          'suppliers': <String, int>{},
        };
      }
      feedTypes[feed.name]!['quantity'] =
          (feedTypes[feed.name]!['quantity'] as double) + feed.quantity;
      feedTypes[feed.name]!['remaining'] =
          (feedTypes[feed.name]!['remaining'] as double) +
              feed.remainingQuantity;
      feedTypes[feed.name]!['consumed'] =
          (feedTypes[feed.name]!['consumed'] as double) +
              (feed.quantity - feed.remainingQuantity);

      // Track brands
      if (!feedTypes[feed.name]!['brands'].containsKey(feed.brand)) {
        feedTypes[feed.name]!['brands'][feed.brand] = 0;
      }
      feedTypes[feed.name]!['brands'][feed.brand] += 1;

      // Track suppliers
      if (!feedTypes[feed.name]!['suppliers'].containsKey(feed.supplier)) {
        feedTypes[feed.name]!['suppliers'][feed.supplier] = 0;
      }
      feedTypes[feed.name]!['suppliers'][feed.supplier] += 1;
    }

    // Calculate percentages based on remaining quantity
    if (currentInventory > 0) {
      for (final type in feedTypes.keys) {
        feedTypes[type]!['percentage'] =
            (feedTypes[type]!['remaining'] as double) / currentInventory * 100;
      }
    }

    return {
      'totalFeedCost': totalFeedCost,
      'currentInventory': currentInventory,
      'feedConsumption': consumption,
      'feedTypes': feedTypes,
      'lowStockItems': allFeeds
          .where((f) =>
              f.purchaseDate.isAfter(_dateRange.start) &&
              f.purchaseDate.isBefore(_dateRange.end) &&
              f.remainingQuantity < 10)
          .length,
      'averageCostPerKg': totalFeedCost > 0 && consumption > 0
          ? totalFeedCost / consumption
          : 0,
      'totalFeedPurchases': allFeeds
          .where((f) =>
              f.purchaseDate.isAfter(_dateRange.start) &&
              f.purchaseDate.isBefore(_dateRange.end))
          .length,
    };
  }

  Future<Map<String, dynamic>> _calculateTaskReports() async {
    final tasks = _tasksBox.values
        .where((e) =>
            e.date.isAfter(_dateRange.start) && e.date.isBefore(_dateRange.end))
        .toList();

    if (tasks.isEmpty) return {};

    return {
      'totalEvents': tasks.length,
      'byType': {
        'health': tasks.where((e) => e.taskType == 'Health').length,
        'breeding': tasks.where((e) => e.taskType == 'Breeding').length,
        'feeding': tasks.where((e) => e.taskType == 'Feeding').length,
        'movement': tasks.where((e) => e.taskType == 'Movement').length,
        'other': tasks.where((e) => e.taskType == 'Other').length,
      },
      'completionRate': tasks.where((e) => e.isCompleted).length / tasks.length,
    };
  }

  Future<Map<String, dynamic>> _calculateFinancialSummary() async {
    final sales = _salesBox.values
        .where((s) =>
            s.date.isAfter(_dateRange.start) && s.date.isBefore(_dateRange.end))
        .toList();

    final expenses = _expensesBox.values
        .where((e) =>
            e.date.isAfter(_dateRange.start) && e.date.isBefore(_dateRange.end))
        .toList();

    final totalSales = sales.fold(0.0, (sum, s) => sum + s.amount);
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final netProfit = totalSales - totalExpenses;

    return {
      'totalSales': totalSales,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'profitMargin': totalSales > 0 ? (netProfit / totalSales) * 100 : 0,
    };
  }

  Future<Map<String, dynamic>> _calculateExpenseReports() async {
    final expenses = _expensesBox.values
        .where((e) =>
            e.date.isAfter(_dateRange.start) && e.date.isBefore(_dateRange.end))
        .toList();

    if (expenses.isEmpty) return {};

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

  Future<Map<String, dynamic>> _calculateSalesReports() async {
    final sales = _salesBox.values
        .where((s) =>
            s.date.isAfter(_dateRange.start) && s.date.isBefore(_dateRange.end))
        .toList();

    if (sales.isEmpty) return {};

    double total = sales.fold(0, (sum, s) => sum + s.amount);
    Map<String, dynamic> byPigType = {};

    for (final sale in sales) {
      try {
        final pig = widget.allPigs.firstWhere((p) => p.tag == sale.pigTag);
        final type = pig.stage;
        byPigType[type] = {
          'count': (byPigType[type]?['count'] ?? 0) + 1,
          'total': (byPigType[type]?['total'] ?? 0) + sale.amount,
        };
      } catch (e) {
        // Pig not found
      }
    }

    return {
      'total': total,
      'count': sales.length,
      'average': total / sales.length,
      'byPigType': byPigType,
    };
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
    );

    if (picked != null && picked != _dateRange) {
      if (picked.end.difference(picked.start).inDays > 365) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a range of 1 year or less'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      setState(() {
        _dateRange = picked;
        _isLoading = true;
      });
      await _loadReports();
    }
  }

  Future<void> _exportReports() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Farm Reports',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  )),
            ),
            pw.Text(
                'Date Range: ${DateFormat('MMM dd, yyyy').format(_dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange.end)}'),
            pw.SizedBox(height: 20),

            // Always include all reports in PDF
            _buildPdfReportSection(
                'Pig Report',
                pigReports.isEmpty
                    ? pw.Text('No pig data available')
                    : _buildPigReportPdfContent()),
            pw.SizedBox(height: 20),

            _buildPdfReportSection(
                'Financial Summary', _buildFinancialSummaryPdfContent()),
            pw.SizedBox(height: 20),

            _buildPdfReportSection(
                'Feed Report',
                feedReports.isEmpty
                    ? pw.Text('No feed data available')
                    : _buildFeedReportPdfContent()),
            pw.SizedBox(height: 20),

            _buildPdfReportSection(
                'Task Report',
                taskReports.isEmpty
                    ? pw.Text('No task data available')
                    : _buildTaskReportPdfContent()),
            pw.SizedBox(height: 20),

            _buildPdfReportSection(
                'Expense Report',
                expenseReports.isEmpty
                    ? pw.Text('No expense data available')
                    : _buildExpenseReportPdfContent()),
            pw.SizedBox(height: 20),

            _buildPdfReportSection(
                'Sales Report',
                salesReports.isEmpty
                    ? pw.Text('No sales data available')
                    : _buildSalesReportPdfContent()),
          ],
        ),
      );

      // Request storage permission
      if (await Permission.storage.request().isGranted) {
        final downloadsDirectory = Directory('/storage/emulated/0/Download');
        final file = File('${downloadsDirectory.path}/farm_report.pdf');
        await file.writeAsBytes(await pdf.save());
        print('PDF saved to Downloads: ${file.path}');
      } else {
        print('Permission denied');
      }

      // Share/save the PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'farm_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report exported successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting PDF report: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

// =====================
// PDF Helper Methods
// =====================

  pw.Widget _buildPdfReportSection(String title, pw.Widget content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            )),
        pw.Divider(),
        content,
      ],
    );
  }

  pw.Widget _buildPigReportPdfContent() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfReportItem('Total Pigs', pigReports['totalPigs'].toString()),
        _buildPdfReportItem(
            'Male Pigs', pigReports['byGender']['male'].toString()),
        _buildPdfReportItem(
            'Female Pigs', pigReports['byGender']['female'].toString()),
        pw.SizedBox(height: 10),
        pw.Text('By Stage:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildPdfReportItem(
            'Piglets', pigReports['byStage']['piglet'].toString()),
        _buildPdfReportItem(
            'Weaners', pigReports['byStage']['weaner'].toString()),
        _buildPdfReportItem(
            'Growers', pigReports['byStage']['grower'].toString()),
        _buildPdfReportItem(
            'Finishers', pigReports['byStage']['finisher'].toString()),
        _buildPdfReportItem('Sows', pigReports['byStage']['sow'].toString()),
        _buildPdfReportItem('Boars', pigReports['byStage']['boar'].toString()),
        pw.SizedBox(height: 10),
        pw.Text('By Age Group:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildPdfReportItem(
            '0-3 months', pigReports['byAge']['0-3 months'].toString()),
        _buildPdfReportItem(
            '3-6 months', pigReports['byAge']['3-6 months'].toString()),
        _buildPdfReportItem(
            '6-12 months', pigReports['byAge']['6-12 months'].toString()),
        _buildPdfReportItem(
            '1-2 years', pigReports['byAge']['1-2 years'].toString()),
        _buildPdfReportItem(
            '2+ years', pigReports['byAge']['2+ years'].toString()),
        _buildPdfReportItem('Average Age',
            '${pigReports['averageAge'].toStringAsFixed(1)} months'),
      ],
    );
  }

  pw.Widget _buildFinancialSummaryPdfContent() {
    final currencyFormat = NumberFormat.currency(symbol: '₱');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfReportItem('Total Sales',
            currencyFormat.format(financialSummary['totalSales'])),
        _buildPdfReportItem('Total Expenses',
            currencyFormat.format(financialSummary['totalExpenses'])),
        _buildPdfReportItem(
          'Net Profit',
          currencyFormat.format(financialSummary['netProfit']),
          isPositive: financialSummary['netProfit'] >= 0,
        ),
        _buildPdfReportItem(
          'Profit Margin',
          '${financialSummary['profitMargin'].toStringAsFixed(2)}%',
          isPositive: financialSummary['profitMargin'] >= 0,
        ),
      ],
    );
  }

  pw.Widget _buildFeedReportPdfContent() {
    final currencyFormat = NumberFormat.currency(symbol: '₱');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfReportItem('Total Feed Cost',
            currencyFormat.format(feedReports['totalFeedCost'] ?? 0)),
        _buildPdfReportItem('Current Inventory',
            '${feedReports['currentInventory']?.toStringAsFixed(2) ?? '0'} kg'),
        _buildPdfReportItem('Feed Consumed',
            '${feedReports['feedConsumption']?.toStringAsFixed(2) ?? '0'} kg'),
        _buildPdfReportItem(
          'Avg Cost/Kg',
          feedReports['averageCostPerKg'] != null
              ? '${currencyFormat.format(feedReports['averageCostPerKg'])}/kg'
              : 'N/A',
        ),
        _buildPdfReportItem(
            'Low Stock Items', '${feedReports['lowStockItems'] ?? 0} items'),
        _buildPdfReportItem('Total Purchases',
            '${feedReports['totalFeedPurchases'] ?? 0} purchases'),
        if (feedReports['feedTypes'] != null &&
            feedReports['feedTypes'].isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('Feed Types:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...feedReports['feedTypes'].entries.map((entry) {
            final value = entry.value as Map<String, dynamic>;
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(entry.key,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                _buildPdfReportItem('Purchased',
                    '${(value['quantity'] as num).toStringAsFixed(2)} kg'),
                _buildPdfReportItem('Consumed',
                    '${(value['consumed'] as num).toStringAsFixed(2)} kg'),
                _buildPdfReportItem(
                  'Remaining',
                  '${(value['remaining'] as num).toStringAsFixed(2)} kg (${(value['percentage'] as num).toStringAsFixed(1)}%)',
                  isPositive: (value['remaining'] as num).toDouble() >= 10,
                ),
                pw.SizedBox(height: 5),
              ],
            );
          }).toList(),
        ],
      ],
    );
  }

  pw.Widget _buildTaskReportPdfContent() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfReportItem(
            'Total Events', taskReports['totalEvents'].toString()),
        _buildPdfReportItem(
          'Completion Rate',
          '${(taskReports['completionRate'] * 100).toStringAsFixed(1)}%',
          isPositive: taskReports['completionRate'] >= 0.7,
        ),
        pw.SizedBox(height: 10),
        pw.Text('By Type:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildPdfReportItem(
            'Health', taskReports['byType']['health'].toString()),
        _buildPdfReportItem(
            'Breeding', taskReports['byType']['breeding'].toString()),
        _buildPdfReportItem(
            'Feeding', taskReports['byType']['feeding'].toString()),
        _buildPdfReportItem(
            'Movement', taskReports['byType']['movement'].toString()),
        _buildPdfReportItem('Other', taskReports['byType']['other'].toString()),
      ],
    );
  }

  pw.Widget _buildExpenseReportPdfContent() {
    final currencyFormat = NumberFormat.currency(symbol: '₱');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfReportItem('Total Expenses',
            currencyFormat.format(expenseReports['total'] ?? 0)),
        _buildPdfReportItem('Average Expense',
            currencyFormat.format(expenseReports['average'] ?? 0)),
        if (expenseReports['byCategory'] != null &&
            expenseReports['byCategory'].isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('By Category:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...expenseReports['byCategory'].entries.map((entry) {
            return _buildPdfReportItem(
              entry.key,
              currencyFormat.format(entry.value),
            );
          }).toList(),
        ],
      ],
    );
  }

  pw.Widget _buildSalesReportPdfContent() {
    final currencyFormat = NumberFormat.currency(symbol: '₱');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildPdfReportItem(
            'Total Sales', currencyFormat.format(salesReports['total'])),
        _buildPdfReportItem(
            'Number of Sales', salesReports['count'].toString()),
        _buildPdfReportItem(
            'Average Sale', currencyFormat.format(salesReports['average'])),
        if (salesReports['byPigType'].isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('By Pig Type:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...salesReports['byPigType'].entries.map((entry) {
            return _buildPdfReportItem(
              entry.key,
              '${entry.value['count']} sales (${currencyFormat.format(entry.value['total'])})',
            );
          }).toList(),
        ],
      ],
    );
  }

  pw.Widget _buildPdfReportItem(String label, String value,
      {bool? isPositive}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: isPositive != null
                  ? (isPositive ? PdfColors.green : PdfColors.red)
                  : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'lib/assets/images/reports.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Farm Reports",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.green[700],
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _selectDateRange(context),
              tooltip: 'Select date range',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportReports,
              tooltip: 'Export reports',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadReports,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateRangeHeader(),
                        const SizedBox(height: 20),
                        _buildReportCard(
                          title: "Pig Reports",
                          iconPath: reportIcons['Pig Reports']!,
                          data: pigReports,
                          buildContent: _buildPigReportContent,
                        ),
                        const SizedBox(height: 16),
                        _buildReportCard(
                          title: "Feed Reports",
                          iconPath: reportIcons['Feed Reports']!,
                          data: feedReports,
                          buildContent: _buildFeedReportContent,
                        ),
                        const SizedBox(height: 16),
                        _buildReportCard(
                          title: "Task Reports",
                          iconPath: reportIcons['Task Reports']!,
                          data: taskReports,
                          buildContent: _buildTaskReportContent,
                        ),
                        const SizedBox(height: 16),
                        _buildReportCard(
                          title: "Expense Reports",
                          iconPath: reportIcons['Expense Reports']!,
                          data: expenseReports,
                          buildContent: _buildExpenseReportContent,
                        ),
                        const SizedBox(height: 16),
                        _buildReportCard(
                          title: "Sales Reports",
                          iconPath: reportIcons['Sales Reports']!,
                          data: salesReports,
                          buildContent: _buildSalesReportContent,
                        ),
                        const SizedBox(height: 16),
                        _buildFinancialSummaryCard(),
                      ],
                    ),
                  ),
                )));
  }

  Widget _buildDateRangeHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
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
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String iconPath,
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
          // ✅ Wrap multiple widgets here
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  iconPath,
                  width: 28,
                  height: 28,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error_outline),
                ),
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
            if (data.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No data available for this period',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
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
        const Text("By Age Group:",
            style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildReportItem(
                "0-3 months", data['byAge']['0-3 months'].toString()),
            _buildReportItem(
                "3-6 months", data['byAge']['3-6 months'].toString()),
            _buildReportItem(
                "6-12 months", data['byAge']['6-12 months'].toString()),
            _buildReportItem(
                "1-2 years", data['byAge']['1-2 years'].toString()),
            _buildReportItem("2+ years", data['byAge']['2+ years'].toString()),
          ],
        ),
        const SizedBox(height: 12),
        _buildReportItem(
            "Average Age", "${data['averageAge'].toStringAsFixed(1)} months"),
      ],
    );
  }

  List<PieChartSectionData> _buildFeedTypeSections(
      Map<String, dynamic> feedTypes) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
    ];

    final validEntries = feedTypes.entries.where((entry) {
      final value = entry.value as Map<String, dynamic>;
      final remaining = value['remaining'] as double? ?? 0;
      return remaining > 0;
    }).toList();

    validEntries.sort((a, b) {
      final aRemaining = (a.value['remaining'] as double? ?? 0);
      final bRemaining = (b.value['remaining'] as double? ?? 0);
      return bRemaining.compareTo(aRemaining);
    });

    validEntries.fold<double>(
      0.0,
      (sum, entry) => sum + ((entry.value['remaining'] as num).toDouble()),
    );

    return validEntries.map((entry) {
      final value = entry.value as Map<String, dynamic>;
      final percentage = (value['percentage'] as num?)?.toDouble() ?? 0.0;
      final colorIndex = validEntries.indexOf(entry) % colors.length;

      return PieChartSectionData(
        color: colors[colorIndex],
        value: percentage,
        title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: percentage >= 5 ? 50 : 40,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildFeedReportContent(Map<String, dynamic> data) {
    final currencyFormat = NumberFormat.currency(symbol: '₱');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportItem(
          "Total Feed Cost",
          currencyFormat.format(data['totalFeedCost'] ?? 0),
        ),
        _buildReportItem(
          "Current Inventory",
          "${data['currentInventory']?.toStringAsFixed(2) ?? '0'} kg",
        ),
        _buildReportItem(
          "Feed Consumed",
          "${data['feedConsumption']?.toStringAsFixed(2) ?? '0'} kg",
        ),
        _buildReportItem(
          "Avg Cost/Kg",
          data['averageCostPerKg'] != null
              ? "${currencyFormat.format(data['averageCostPerKg'])}/kg"
              : "N/A",
        ),
        _buildReportItem(
          "Low Stock Items",
          "${data['lowStockItems'] ?? 0} items",
        ),
        _buildReportItem(
          "Total Purchases",
          "${data['totalFeedPurchases'] ?? 0} purchases",
        ),
        if (data['feedTypes'] != null && data['feedTypes'].isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            "Feed Type Distribution (Remaining):",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            height: 250,
            padding: const EdgeInsets.all(8),
            child: PieChart(
              PieChartData(
                sections: _buildFeedTypeSections(data['feedTypes']),
                centerSpaceRadius: 40,
                sectionsSpace: 0,
                startDegreeOffset: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Feed Types Details:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...(data['feedTypes'] as Map<String, dynamic>).entries.map((entry) {
            final value = entry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Purchased:"),
                          Text(
                            "${(value['quantity'] as num).toStringAsFixed(2)} kg",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Consumed:"),
                          Text(
                            "${(value['consumed'] as num).toStringAsFixed(2)} kg",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Remaining:"),
                          Text(
                            "${(value['remaining'] as num).toStringAsFixed(2)} kg (${(value['percentage'] as num).toStringAsFixed(1)}%)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (value['remaining'] as num).toDouble() < 10
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (value['brands'] != null &&
                          (value['brands'] as Map).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Brands: ${(value['brands'] as Map).keys.join(', ')}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      if (value['suppliers'] != null &&
                          (value['suppliers'] as Map).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Suppliers: ${(value['suppliers'] as Map).keys.join(', ')}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ] else ...[
          const SizedBox(height: 16),
          const Center(
            child: Text('No feed type data available for selected date range'),
          ),
        ],
      ],
    );
  }

  Widget _buildTaskReportContent(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportItem("Total Tasks", data['totalEvents'].toString()),
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
        _buildReportItem(
          "Total Expenses",
          NumberFormat.currency(symbol: '₱').format(data['total'] ?? 0),
        ),
        _buildReportItem(
          "Average Expense",
          NumberFormat.currency(symbol: '₱').format(data['average'] ?? 0),
        ),
        if (data['byCategory'] != null && data['byCategory'].isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text("By Category:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: _buildExpenseBarGroups(data['byCategory']),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final categories = data['byCategory'].keys.toList();
                        if (value.toInt() >= 0 &&
                            value.toInt() < categories.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              categories[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<BarChartGroupData> _buildExpenseBarGroups(
      Map<String, dynamic> byCategory) {
    final categories = byCategory.keys.toList();
    return List<BarChartGroupData>.generate(
      categories.length,
      (index) => BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: (byCategory[categories[index]] ?? 0).toDouble(),
            color: Colors.red,
            width: 16,
          ),
        ],
        showingTooltipIndicators: [0],
      ),
    );
  }

  Widget _buildSalesReportContent(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportItem("Total Sales",
            NumberFormat.currency(symbol: '₱').format(data['total'])),
        _buildReportItem("Number of Sales", data['count'].toString()),
        _buildReportItem("Average Sale",
            NumberFormat.currency(symbol: '₱').format(data['average'])),
        if (data['byPigType'].isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text("By Pig Type:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...data['byPigType'].entries.map(
                (entry) => _buildReportItem(
                  entry.key,
                  "${entry.value['count']} sales (${NumberFormat.currency(symbol: '\$').format(entry.value['total'])})",
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildFinancialSummaryCard() {
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
                Image.asset(
                  reportIcons['Financial Summary']!,
                  width: 28,
                  height: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  "Financial Summary",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            if (financialSummary.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No financial data available for this period',
                    style: TextStyle(color: Colors.grey)),
              )
            else ...[
              _buildFinancialComparisonChart(),
              const SizedBox(height: 16),
              _buildReportItem(
                "Total Sales",
                NumberFormat.currency(symbol: '₱')
                    .format(financialSummary['totalSales'] ?? 0),
              ),
              _buildReportItem(
                "Total Expenses",
                NumberFormat.currency(symbol: '₱')
                    .format(financialSummary['totalExpenses'] ?? 0),
              ),
              _buildReportItem(
                "Net Profit",
                NumberFormat.currency(symbol: '₱')
                    .format(financialSummary['netProfit'] ?? 0),
                tooltip: 'Sales minus Expenses',
              ),
              _buildReportItem(
                "Profit Margin",
                "${(financialSummary['profitMargin'] ?? 0).toStringAsFixed(2)}%",
                tooltip: 'Net Profit as percentage of Sales',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialComparisonChart() {
    final currencyFormat = NumberFormat.compactCurrency(symbol: '₱');
    final maxValue = max(
      financialSummary['totalSales'] as num,
      financialSummary['totalExpenses'] as num,
    ).toDouble();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue * 1.2, // Add 20% padding
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: financialSummary['totalSales'],
                  color: Colors.green,
                  width: 20,
                  borderRadius: BorderRadius.zero,
                ),
              ],
              showingTooltipIndicators: [0],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: financialSummary['totalExpenses'],
                  color: Colors.red,
                  width: 20,
                  borderRadius: BorderRadius.zero,
                ),
              ],
              showingTooltipIndicators: [0],
            ),
            BarChartGroupData(
              x: 2,
              barRods: [
                BarChartRodData(
                  toY: financialSummary['netProfit'].abs(),
                  color: financialSummary['netProfit'] >= 0
                      ? Colors.blue
                      : Colors.orange,
                  width: 20,
                  borderRadius: BorderRadius.zero,
                ),
              ],
              showingTooltipIndicators: [0],
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Sales'),
                      );
                    case 1:
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Expenses'),
                      );
                    case 2:
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          financialSummary['netProfit'] >= 0
                              ? 'Profit'
                              : 'Loss',
                        ),
                      );
                    default:
                      return const Text('');
                  }
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      currencyFormat.format(value),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
                reservedSize: 50,
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }

  Widget _buildReportItem(String label, String value, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (tooltip != null) ...[
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  )),
            ),
            Text(value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                )),
          ],
        ),
      ),
    );
  }
}
