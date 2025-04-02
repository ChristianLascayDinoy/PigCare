import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class Expense {
  final String id;
  final String category;
  final double amount;
  final DateTime date;
  final String description;
  final String? pigTag; // Optional: link to specific pig

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.description,
    this.pigTag,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'pigTag': pigTag,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      category: map['category'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      description: map['description'],
      pigTag: map['pigTag'],
    );
  }
}

class ExpenseManagementScreen extends StatefulWidget {
  const ExpenseManagementScreen({super.key});

  @override
  _ExpenseManagementScreenState createState() =>
      _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  late Box<Expense> _expensesBox;
  List<Expense> _expenses = [];
  bool _isLoading = false;
  final List<String> _categories = [
    'Feed',
    'Medication',
    'Equipment',
    'Labor',
    'Transport',
    'Utilities',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    _expensesBox = await Hive.openBox<Expense>('expenses');
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    _expenses = _expensesBox.values.toList();
    setState(() => _isLoading = false);
  }

  Future<void> _addExpense() async {
    final result = await showDialog<Expense>(
      context: context,
      builder: (context) => const AddEditExpenseDialog(),
    );

    if (result != null) {
      await _expensesBox.add(result);
      _loadExpenses();
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final result = await showDialog<Expense>(
      context: context,
      builder: (context) => AddEditExpenseDialog(expense: expense),
    );

    if (result != null) {
      final key = _expensesBox.keyAt(_expenses.indexOf(expense));
      await _expensesBox.put(key, result);
      _loadExpenses();
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this expense?"),
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
      final key = _expensesBox.keyAt(_expenses.indexOf(expense));
      await _expensesBox.delete(key);
      _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addExpense,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? const Center(child: Text("No expenses recorded"))
              : ListView.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final expense = _expenses[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(expense.category),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(expense.description),
                            Text(
                              DateFormat('MMM dd, yyyy').format(expense.date),
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (expense.pigTag != null)
                              Text(
                                "Linked to: ${expense.pigTag}",
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "₱${expense.amount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _editExpense(expense),
                        onLongPress: () => _deleteExpense(expense),
                      ),
                    );
                  },
                ),
    );
  }
}

class AddEditExpenseDialog extends StatefulWidget {
  final Expense? expense;

  const AddEditExpenseDialog({this.expense, super.key});

  @override
  _AddEditExpenseDialogState createState() => _AddEditExpenseDialogState();
}

class _AddEditExpenseDialogState extends State<AddEditExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _category;
  late double _amount;
  late DateTime _date;
  late String _description;
  String? _pigTag;

  @override
  void initState() {
    super.initState();
    _category = widget.expense?.category ?? 'Feed';
    _amount = widget.expense?.amount ?? 0;
    _date = widget.expense?.date ?? DateTime.now();
    _description = widget.expense?.description ?? '';
    _pigTag = widget.expense?.pigTag;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expense == null ? "Add Expense" : "Edit Expense"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _category,
                items: [
                  'Feed',
                  'Medication',
                  'Equipment',
                  'Labor',
                  'Transport',
                  'Utilities',
                  'Other'
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _category = value!),
                decoration: const InputDecoration(labelText: "Category"),
              ),
              TextFormField(
                initialValue: _amount.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount"),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  return null;
                },
                onSaved: (value) => _amount = double.parse(value!),
              ),
              ListTile(
                title: Text(DateFormat('MMM dd, yyyy').format(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _date = date);
                  }
                },
              ),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: "Description"),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
                onSaved: (value) => _description = value!,
              ),
              TextFormField(
                initialValue: _pigTag,
                decoration: const InputDecoration(
                    labelText: "Pig Tag (optional)",
                    hintText: "Link to specific pig"),
                onSaved: (value) => _pigTag = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.pop(
                context,
                Expense(
                  id: widget.expense?.id ?? DateTime.now().toString(),
                  category: _category,
                  amount: _amount,
                  date: _date,
                  description: _description,
                  pigTag: _pigTag,
                ),
              );
            }
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
