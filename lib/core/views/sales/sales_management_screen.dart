import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:pigcare/core/models/pig_model.dart';

class Sale {
  final String id;
  final String pigTag;
  final double amount;
  final DateTime date;
  final String buyer;
  final String? notes;

  Sale({
    required this.id,
    required this.pigTag,
    required this.amount,
    required this.date,
    required this.buyer,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pigTag': pigTag,
      'amount': amount,
      'date': date.toIso8601String(),
      'buyer': buyer,
      'notes': notes,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      pigTag: map['pigTag'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      buyer: map['buyer'],
      notes: map['notes'],
    );
  }
}

class SalesManagementScreen extends StatefulWidget {
  final List<Pig> allPigs;

  const SalesManagementScreen({required this.allPigs, super.key});

  @override
  _SalesManagementScreenState createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {
  late Box<Sale> _salesBox;
  List<Sale> _sales = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    _salesBox = await Hive.openBox<Sale>('sales');
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    _sales = _salesBox.values.toList();
    setState(() => _isLoading = false);
  }

  Future<void> _addSale() async {
    if (widget.allPigs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No pigs available for sale")),
      );
      return;
    }

    final result = await showDialog<Sale>(
      context: context,
      builder: (context) => AddEditSaleDialog(allPigs: widget.allPigs),
    );

    if (result != null) {
      await _salesBox.add(result);
      _loadSales();
    }
  }

  Future<void> _editSale(Sale sale) async {
    final result = await showDialog<Sale>(
      context: context,
      builder: (context) => AddEditSaleDialog(
        sale: sale,
        allPigs: widget.allPigs,
      ),
    );

    if (result != null) {
      final key = _salesBox.keyAt(_sales.indexOf(sale));
      await _salesBox.put(key, result);
      _loadSales();
    }
  }

  Future<void> _deleteSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this sale?"),
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
      final key = _salesBox.keyAt(_sales.indexOf(sale));
      await _salesBox.delete(key);
      _loadSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSale,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? const Center(child: Text("No sales recorded"))
              : ListView.builder(
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final sale = _sales[index];
                    final pig = widget.allPigs.firstWhere(
                      (p) => p.tag == sale.pigTag,
                      orElse: () => Pig(
                        tag: 'Unknown',
                        breed: '',
                        gender: '',
                        stage: '',
                        weight: 0,
                        source: '',
                        dob: '',
                        doe: '',
                      ),
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(pig.genderSymbol),
                        ),
                        title: Text("Pig: ${sale.pigTag}"),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Buyer: ${sale.buyer}"),
                            Text(
                              DateFormat('MMM dd, yyyy').format(sale.date),
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (sale.notes != null)
                              Text(
                                "Notes: ${sale.notes}",
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "₱${sale.amount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _editSale(sale),
                        onLongPress: () => _deleteSale(sale),
                      ),
                    );
                  },
                ),
    );
  }
}

class AddEditSaleDialog extends StatefulWidget {
  final Sale? sale;
  final List<Pig> allPigs;

  const AddEditSaleDialog({
    this.sale,
    required this.allPigs,
    super.key,
  });

  @override
  _AddEditSaleDialogState createState() => _AddEditSaleDialogState();
}

class _AddEditSaleDialogState extends State<AddEditSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _pigTag;
  late double _amount;
  late DateTime _date;
  late String _buyer;
  String? _notes;

  @override
  void initState() {
    super.initState();
    // Initialize with first pig if available, otherwise empty string
    _pigTag = widget.sale?.pigTag ??
        (widget.allPigs.isNotEmpty ? widget.allPigs.first.tag : '');
    _amount = widget.sale?.amount ?? 0;
    _date = widget.sale?.date ?? DateTime.now();
    _buyer = widget.sale?.buyer ?? '';
    _notes = widget.sale?.notes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.sale == null ? "Add Sale" : "Edit Sale"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.allPigs.isEmpty)
                const Text(
                  "No pigs available for sale",
                  style: TextStyle(color: Colors.red),
                )
              else
                DropdownButtonFormField<String>(
                  value: _pigTag,
                  items: widget.allPigs.map((Pig pig) {
                    return DropdownMenuItem<String>(
                      value: pig.tag,
                      child: Text("${pig.tag} (${pig.breed})"),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _pigTag = value!),
                  decoration: const InputDecoration(labelText: "Pig"),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Select a pig' : null,
                ),
              TextFormField(
                initialValue: _amount.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount"),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  if (double.parse(value) <= 0) return 'Must be positive';
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
                initialValue: _buyer,
                decoration: const InputDecoration(labelText: "Buyer"),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
                onSaved: (value) => _buyer = value!,
              ),
              TextFormField(
                initialValue: _notes,
                decoration:
                    const InputDecoration(labelText: "Notes (optional)"),
                onSaved: (value) => _notes = value,
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
          onPressed: widget.allPigs.isEmpty
              ? null
              : () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    Navigator.pop(
                      context,
                      Sale(
                        id: widget.sale?.id ?? DateTime.now().toString(),
                        pigTag: _pigTag,
                        amount: _amount,
                        date: _date,
                        buyer: _buyer,
                        notes: _notes,
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
