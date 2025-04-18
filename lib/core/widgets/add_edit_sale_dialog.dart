// widgets/add_edit_sale_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale_model.dart';
import '../models/pig_model.dart';

class AddEditSaleDialog extends StatefulWidget {
  final List<Pig> allPigs;
  final Sale? existingSale;

  const AddEditSaleDialog({
    super.key,
    required this.allPigs,
    this.existingSale,
  });

  @override
  State<AddEditSaleDialog> createState() => _AddEditSaleDialogState();
}

class _AddEditSaleDialogState extends State<AddEditSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _buyerNameController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late String? _selectedPigTag;

  @override
  void initState() {
    super.initState();
    _buyerNameController =
        TextEditingController(text: widget.existingSale?.buyerName ?? '');
    _amountController = TextEditingController(
        text: widget.existingSale?.amount.toString() ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingSale?.description ?? '');
    _selectedDate = widget.existingSale?.date ?? DateTime.now();
    _selectedPigTag = widget.existingSale?.pigTag;
  }

  @override
  void dispose() {
    _buyerNameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingSale != null ? "Edit Sale" : "Add Sale"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedPigTag,
                decoration: const InputDecoration(
                  labelText: "Pig *",
                  border: OutlineInputBorder(),
                ),
                items: widget.allPigs.map((pig) {
                  return DropdownMenuItem(
                    value: pig.tag,
                    child: Text("${pig.tag} - ${pig.name ?? 'No name'}"),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedPigTag = value),
                validator: (value) =>
                    value == null ? 'Please select a pig' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _buyerNameController,
                decoration: const InputDecoration(
                  labelText: "Buyer Name *",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: "Amount *",
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required field';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter valid amount';
                  }
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
          onPressed: _saveSale,
          child: const Text("Save"),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveSale() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPigTag == null) return;

    final sale = Sale(
      id: widget.existingSale?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      pigTag: _selectedPigTag!,
      buyerName: _buyerNameController.text,
      amount: double.parse(_amountController.text),
      date: _selectedDate,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
    );

    Navigator.pop(context, sale);
  }
}
