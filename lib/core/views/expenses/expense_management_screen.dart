import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pigcare/core/models/expense_model.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/models/pigpen_model.dart';
import 'package:pigcare/core/providers/feed_expense_provider.dart';

class ExpenseManagementScreen extends StatefulWidget {
  final List<Pig> allPigs;

  const ExpenseManagementScreen({
    super.key,
    required this.allPigs,
  });

  @override
  State<ExpenseManagementScreen> createState() =>
      _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  List<Expense> _allExpenses = [];
  String _searchQuery = '';
  String _filterCategory = 'All';
  bool _isLoading = true;
  bool _initializationError = false;
  DateTimeRange? _dateRangeFilter;
  double? _minAmountFilter;
  double? _maxAmountFilter;

  final List<String> _categories = [
    'Feed',
    'Medication',
    'Equipment',
    'Veterinary',
    'Transport',
    'Labor',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _initializationError = false;
      });

      final provider = Provider.of<FeedExpenseProvider>(context, listen: false);
      await provider.initialize();
      await _loadExpenses();
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _isLoading = false;
        _initializationError = true;
      });
      _showErrorSnackbar('Failed to initialize: ${e.toString()}');
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final provider = Provider.of<FeedExpenseProvider>(context, listen: false);
      final expenses = provider.expensesBox.values.toList();
      setState(() {
        _allExpenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackbar('Error loading expenses: $e');
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final isFeedExpense = expense.feedId != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text(isFeedExpense
            ? "This expense is linked to a feed. The feed will remain but the expense record will be deleted."
            : "Delete ${expense.name} expense?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final provider =
            Provider.of<FeedExpenseProvider>(context, listen: false);
        await provider.deleteExpense(expense.id);
        await _loadExpenses();
        _showSuccessSnackbar('Expense deleted successfully');
      } catch (e) {
        _showErrorSnackbar('Error deleting expense: $e');
      }
    }
  }

  Future<void> _saveExpense(Expense expense) async {
    try {
      final provider = Provider.of<FeedExpenseProvider>(context, listen: false);
      await provider.updateExpense(expense);
      await _loadExpenses();
      _showSuccessSnackbar('Expense saved successfully');
    } catch (e) {
      _showErrorSnackbar('Error saving expense: $e');
    }
  }

  List<Expense> get _filteredExpenses {
    return _allExpenses.where((expense) {
      final matchesSearch =
          expense.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (expense.description
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false);
      final matchesCategory =
          _filterCategory == 'All' || expense.category == _filterCategory;
      final matchesDateRange = _dateRangeFilter == null ||
          (_dateRangeFilter!.start.isBefore(expense.date) &&
              _dateRangeFilter!.end.isAfter(expense.date));
      final matchesAmountRange =
          (_minAmountFilter == null || expense.amount >= _minAmountFilter!) &&
              (_maxAmountFilter == null || expense.amount <= _maxAmountFilter!);

      return matchesSearch &&
          matchesCategory &&
          matchesDateRange &&
          matchesAmountRange;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Management"),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddExpenseDialog,
            tooltip: 'Add new expense',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _initializationError
              ? _buildErrorWidget()
              : Column(
                  children: [
                    _buildSearchAndFilter(),
                    Expanded(
                      child: _buildExpenseList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text('Loading expenses...'),
          if (_initializationError) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _initializeData,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 20),
          const Text('Failed to load expenses'),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _initializeData,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search expenses...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterCategory,
                  items: ['All', ..._categories]
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _filterCategory = value!),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    labelText: 'Category',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.filter_alt),
                onPressed: _showAdvancedFilters,
                tooltip: 'Advanced filters',
              ),
            ],
          ),
          if (_dateRangeFilter != null ||
              _minAmountFilter != null ||
              _maxAmountFilter != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (_dateRangeFilter != null)
                  Chip(
                    label: Text(
                        '${DateFormat('MMM d').format(_dateRangeFilter!.start)} - ${DateFormat('MMM d').format(_dateRangeFilter!.end)}'),
                    onDeleted: () => setState(() => _dateRangeFilter = null),
                  ),
                if (_minAmountFilter != null)
                  Chip(
                    label:
                        Text('Min: ₱${_minAmountFilter!.toStringAsFixed(2)}'),
                    onDeleted: () => setState(() => _minAmountFilter = null),
                  ),
                if (_maxAmountFilter != null)
                  Chip(
                    label:
                        Text('Max: ₱${_maxAmountFilter!.toStringAsFixed(2)}'),
                    onDeleted: () => setState(() => _maxAmountFilter = null),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_filteredExpenses.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty &&
                  _filterCategory == 'All' &&
                  _dateRangeFilter == null
              ? "No expenses found\nAdd your first expense!"
              : "No expenses match your search/filters",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExpenses,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _filteredExpenses.length,
        itemBuilder: (context, index) {
          final expense = _filteredExpenses[index];
          return _buildExpenseCard(expense);
        },
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final isFeedExpense =
        expense.category == 'Feed' && expense.name.startsWith('Feed Purchase:');
    final provider = Provider.of<FeedExpenseProvider>(context, listen: false);
    final hasLinkedFeed = isFeedExpense &&
        provider.feedsBox.values.any((f) =>
            f.name == expense.name.replaceFirst('Feed Purchase: ', '') &&
            f.purchaseDate == expense.date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showExpenseDetails(expense),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasLinkedFeed)
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.link, size: 16, color: Colors.blue),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      expense.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Chip(
                    label: Text(expense.category),
                    backgroundColor: _getCategoryColor(expense.category),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(expense.date),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    NumberFormat.currency(symbol: '₱').format(expense.amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              if (expense.description != null &&
                  expense.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  expense.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                "Pigs: ${expense.pigTags.isEmpty ? 'None' : expense.pigTags.length}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditExpenseDialog(expense),
                    tooltip: 'Edit expense',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _deleteExpense(expense),
                    tooltip: 'Delete expense',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Feed':
        return Colors.orange[100]!;
      case 'Medication':
        return Colors.red[100]!;
      case 'Equipment':
        return Colors.blue[100]!;
      case 'Veterinary':
        return Colors.purple[100]!;
      case 'Transport':
        return Colors.green[100]!;
      case 'Labor':
        return Colors.yellow[100]!;
      default:
        return Colors.grey[200]!;
    }
  }

  Future<void> _showAddExpenseDialog() async {
    final pigpenBox = Hive.box<Pigpen>('pigpens');
    final allPigs = pigpenBox.values.expand((pigpen) => pigpen.pigs).toList();

    final result = await showDialog<Expense>(
      context: context,
      builder: (context) {
        final provider =
            Provider.of<FeedExpenseProvider>(context, listen: false);
        return AddEditExpenseDialog(
          allPigs: allPigs,
          initialSelectedPigs: [],
          expensesBox: provider.expensesBox,
        );
      },
    );

    if (result != null) {
      await _saveExpense(result);
    }
  }

  Future<void> _showEditExpenseDialog(Expense expense) async {
    final isFeedExpense =
        expense.category == 'Feed' && expense.name.startsWith('Feed Purchase:');
    final provider = Provider.of<FeedExpenseProvider>(context, listen: false);
    final hasLinkedFeed = isFeedExpense &&
        provider.feedsBox.values.any((f) =>
            f.name == expense.name.replaceFirst('Feed Purchase: ', '') &&
            f.purchaseDate == expense.date);

    if (hasLinkedFeed) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Feed Expense'),
          content: const Text('This expense is linked to a feed record. '
              'Editing it here will update the corresponding feed record. '
              'Do you want to proceed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Edit'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    final pigpenBox = Hive.box<Pigpen>('pigpens');
    final allPigs = pigpenBox.values.expand((pigpen) => pigpen.pigs).toList();

    final result = await showDialog<Expense>(
      context: context,
      builder: (context) {
        final provider =
            Provider.of<FeedExpenseProvider>(context, listen: false);
        return AddEditExpenseDialog(
          allPigs: allPigs,
          existingExpense: expense,
          initialSelectedPigs: expense.pigTags,
          expensesBox: provider.expensesBox,
        );
      },
    );

    if (result != null) {
      await _saveExpense(result);
    }
  }

  Future<void> _showExpenseDetails(Expense expense) async {
    final isFeedExpense =
        expense.category == 'Feed' && expense.name.startsWith('Feed Purchase:');
    final provider = Provider.of<FeedExpenseProvider>(context, listen: false);
    final hasLinkedFeed = isFeedExpense &&
        provider.feedsBox.values.any((f) =>
            f.name == expense.name.replaceFirst('Feed Purchase: ', '') &&
            f.purchaseDate == expense.date);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(expense.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasLinkedFeed)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Note: This expense is linked to a feed record',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              _buildDetailRow('Category', expense.category),
              _buildDetailRow('Amount',
                  NumberFormat.currency(symbol: '₱').format(expense.amount)),
              _buildDetailRow('Date', DateFormat.yMMMd().format(expense.date)),
              if (expense.description != null)
                _buildDetailRow('Description', expense.description!),
              const SizedBox(height: 16),
              const Text('Associated Pigs:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (expense.pigTags.isEmpty)
                const Text('None', style: TextStyle(color: Colors.grey))
              else
                ...expense.pigTags.map((tag) => Text(tag)).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _showAdvancedFilters() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Advanced Filters"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text("Date Range"),
                    subtitle: Text(_dateRangeFilter == null
                        ? "Select date range"
                        : "${DateFormat.yMd().format(_dateRangeFilter!.start)} - ${DateFormat.yMd().format(_dateRangeFilter!.end)}"),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDateRange: _dateRangeFilter,
                      );
                      if (picked != null) {
                        setState(() => _dateRangeFilter = picked);
                      }
                    },
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Minimum Amount",
                      prefixText: "₱",
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(
                        () => _minAmountFilter = double.tryParse(value)),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Maximum Amount",
                      prefixText: "₱",
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(
                        () => _maxAmountFilter = double.tryParse(value)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Clear All"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Apply"),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      setState(() {
        if (!result) {
          // Clear all filters if "Clear All" was pressed
          _dateRangeFilter = null;
          _minAmountFilter = null;
          _maxAmountFilter = null;
        }
        // Otherwise keep the filters that were set
      });
    }
  }
}

class AddEditExpenseDialog extends StatefulWidget {
  final List<Pig> allPigs;
  final Expense? existingExpense;
  final List<String> initialSelectedPigs;
  final Box<Expense> expensesBox;

  const AddEditExpenseDialog({
    super.key,
    required this.allPigs,
    this.existingExpense,
    required this.initialSelectedPigs,
    required this.expensesBox,
  });

  @override
  State<AddEditExpenseDialog> createState() => _AddEditExpenseDialogState();
}

class _AddEditExpenseDialogState extends State<AddEditExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late DateTime _selectedDate;
  late String _selectedCategory;
  late List<String> _selectedPigTags;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingExpense?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingExpense?.description ?? '');
    _amountController = TextEditingController(
        text: widget.existingExpense?.amount.toString() ?? '');
    _selectedDate = widget.existingExpense?.date ?? DateTime.now();
    _selectedCategory = widget.existingExpense?.category ?? 'Feed';
    _selectedPigTags = List.from(widget.initialSelectedPigs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.existingExpense != null ? "Edit Expense" : "Add Expense"),
        actions: [
          if (widget.existingExpense != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmDeleteExpense,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Expense Name *",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Category *",
                  border: OutlineInputBorder(),
                ),
                items: [
                  'Feed',
                  'Medication',
                  'Equipment',
                  'Veterinary',
                  'Transport',
                  'Labor',
                  'Other'
                ]
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: "Amount *",
                  prefixText: "₱",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required field';
                  if (double.tryParse(value!) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Date *",
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description (Optional)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildPigSelection(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveExpense,
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPigSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Pigs (Optional)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(maxHeight: 200),
          child: widget.allPigs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No pigs available to select"),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.allPigs.length,
                  itemBuilder: (context, index) {
                    final pig = widget.allPigs[index];
                    return CheckboxListTile(
                      title: Text("${pig.tag} - ${pig.name ?? 'No name'}"),
                      value: _selectedPigTags.contains(pig.tag),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedPigTags.add(pig.tag);
                          } else {
                            _selectedPigTags.remove(pig.tag);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final expense = Expense(
      id: widget.existingExpense?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      amount: double.parse(_amountController.text),
      date: _selectedDate,
      category: _selectedCategory,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      pigTags: _selectedPigTags,
    );

    Navigator.pop(context, expense);
  }

  Future<void> _confirmDeleteExpense() async {
    if (widget.existingExpense == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete ${widget.existingExpense!.name} expense?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.expensesBox.delete(widget.existingExpense!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense successfully deleted'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting expense: $e'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, false);
        }
      }
    }
  }
}
