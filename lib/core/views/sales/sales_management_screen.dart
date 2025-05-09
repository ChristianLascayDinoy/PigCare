// screens/sales_management_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:pigcare/core/models/pigpen_model.dart';
import '../../models/sale_model.dart';
import '../../models/pig_model.dart';

class SalesManagementScreen extends StatefulWidget {
  final List<Pig> allPigs;
  final List<Pigpen> allPigpens;

  const SalesManagementScreen({
    super.key,
    required this.allPigs,
    required this.allPigpens,
  });

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {
  late Box<Sale> _salesBox;
  List<Sale> _allSales = [];
  String _searchQuery = '';
  bool _isLoading = false;
  DateTimeRange? _dateRangeFilter;
  double? _minAmountFilter;
  double? _maxAmountFilter;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    try {
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(SaleAdapter());
      }
      _salesBox = await Hive.openBox<Sale>('sales');
      _loadSales();
    } catch (e) {
      _showErrorSnackbar('Error initializing database: $e');
    }
  }

  Future<void> _loadSales() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final sales = _salesBox.values.toList();
      setState(() => _allSales = sales);
    } catch (e) {
      _showErrorSnackbar('Error loading sales: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSale(Sale sale) async {
    try {
      await _salesBox.delete(sale.id);
      await _loadSales();
      _showSuccessSnackbar('Sale deleted successfully');
    } catch (e) {
      _showErrorSnackbar('Error deleting sale: $e');
    }
  }

  List<Sale> get _filteredSales {
    return _allSales.where((sale) {
      final matchesSearch = sale.pigTag
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          sale.buyerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (sale.description
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);
      final matchesDateRange = _dateRangeFilter == null ||
          (_dateRangeFilter!.start.isBefore(sale.date) &&
              _dateRangeFilter!.end.isAfter(sale.date));
      final matchesAmountRange =
          (_minAmountFilter == null || sale.amount >= _minAmountFilter!) &&
              (_maxAmountFilter == null || sale.amount <= _maxAmountFilter!);

      return matchesSearch && matchesDateRange && matchesAmountRange;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'lib/assets/images/sales.png',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Sales Management",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.green[700],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSaleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Sale'),
        backgroundColor: Colors.green[700],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading ? _buildLoadingIndicator() : _buildSalesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search sales...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
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

  Widget _buildSalesList() {
    if (_filteredSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/assets/images/sales.png',
              width: 64,
              height: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty &&
                      _dateRangeFilter == null &&
                      _minAmountFilter == null &&
                      _maxAmountFilter == null
                  ? "No sales found\nAdd your first sale!"
                  : "No sales match your search/filters",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSales,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _filteredSales.length,
        itemBuilder: (context, index) {
          final sale = _filteredSales[index];
          return _buildSaleCard(sale);
        },
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    final pig = widget.allPigs.firstWhere(
      (p) => p.tag == sale.pigTag,
      orElse: () => Pig(
          tag: sale.pigTag,
          name: 'Unknown',
          breed: '',
          gender: 'Female',
          dob: '',
          doe: '',
          source: '',
          stage: '',
          weight: 0),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showSaleDetails(sale, pig),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Tag: ${pig.tag}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberFormat.currency(symbol: '₱').format(sale.amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      if (sale.weight != null)
                        Text(
                          '${sale.weight!.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    sale.buyerName,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(sale.date),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              if (sale.description != null && sale.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  sale.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        _showSaleDetails(sale, pig);
                        break;
                      case 'edit':
                        _showEditSaleDialog(sale);
                        break;
                      case 'delete':
                        _confirmDeleteSale(sale);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: const [
                          Icon(Icons.visibility, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: const [
                          Icon(Icons.edit, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSaleDialog() async {
    final result = await Navigator.push<Sale>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSaleDialog(
          allPigs: widget.allPigs,
          allPigpens: widget.allPigpens,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      await _saveSale(result);
    }
  }

  Future<void> _showEditSaleDialog(Sale sale) async {
    final result = await Navigator.push<Sale>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSaleDialog(
          allPigs: widget.allPigs,
          allPigpens: widget.allPigpens,
          existingSale: sale,
        ),
      ),
    );

    if (result != null) {
      await _saveSale(result);
    }
  }

  Future<void> _saveSale(Sale sale) async {
    try {
      await _salesBox.put(sale.id, sale);
      await _removeSoldPig(sale.pigTag);
      await _loadSales();
      _showSuccessSnackbar('Sale saved and pig removed successfully');
    } catch (e) {
      _showErrorSnackbar('Error saving sale: $e');
    }
  }

  Future<void> _removeSoldPig(String pigTag) async {
    try {
      final pigpenBox = Hive.box<Pigpen>('pigpens');
      final pigpens = pigpenBox.values.toList();

      for (final pigpen in pigpens) {
        if (pigpen.pigs.any((pig) => pig.tag == pigTag)) {
          pigpen.pigs.removeWhere((pig) => pig.tag == pigTag);
          await pigpen.save();
          break;
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error removing sold pig: $e');
    }
  }

  // In the _showSaleDetails method
  Future<void> _showSaleDetails(Sale sale, Pig pig) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sale Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Pig Tag', pig.tag),
              if (pig.name != null) _buildDetailRow('Pig Name', pig.name!),
              _buildDetailRow('Buyer', sale.buyerName),
              if (sale.buyerContact != null)
                _buildDetailRow('Buyer Contact', sale.buyerContact!),
              if (sale.weight != null)
                _buildDetailRow(
                    'Weight', '${sale.weight!.toStringAsFixed(2)} kg'),
              _buildDetailRow('Amount',
                  NumberFormat.currency(symbol: '₱').format(sale.amount)),
              _buildDetailRow('Date', DateFormat.yMMMd().format(sale.date)),
              if (sale.description != null)
                _buildDetailRow('Description', sale.description!),
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

  Future<void> _confirmDeleteSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete sale of ${sale.pigTag}?"),
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
      await _deleteSale(sale);
    }
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
                        lastDate: DateTime.now(),
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

// Update the AddEditSaleDialog class
class AddEditSaleDialog extends StatefulWidget {
  final List<Pig> allPigs;
  final List<Pigpen> allPigpens;
  final Sale? existingSale;

  const AddEditSaleDialog({
    super.key,
    required this.allPigs,
    required this.allPigpens,
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
  late TextEditingController _weightController;
  late TextEditingController _buyerContactController;

  late DateTime _selectedDate;
  late Pigpen? _selectedPigpen;
  late Pig? _selectedPig;
  late List<Pig> _pigsInSelectedPen;

  @override
  void initState() {
    super.initState();
    _buyerNameController =
        TextEditingController(text: widget.existingSale?.buyerName ?? '');
    _amountController = TextEditingController(
        text: widget.existingSale?.amount.toString() ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingSale?.description ?? '');
    _weightController = TextEditingController(
        text: widget.existingSale?.weight?.toString() ?? '');
    _buyerContactController =
        TextEditingController(text: widget.existingSale?.buyerContact ?? '');
    _selectedDate = widget.existingSale?.date ?? DateTime.now();
    _selectedPigpen = null;
    _selectedPig = null;
    _pigsInSelectedPen = [];

    // Initialize with existing sale data if editing
    if (widget.existingSale != null) {
      final existingPig = widget.allPigs.firstWhere(
        (pig) => pig.tag == widget.existingSale!.pigTag,
        orElse: () => Pig(
            tag: widget.existingSale!.pigTag,
            name: 'Unknown',
            breed: '',
            gender: 'Female',
            dob: '',
            doe: '',
            source: '',
            stage: '',
            weight: 0),
      );

      // Find which pen the pig is in
      for (final pigpen in widget.allPigpens) {
        if (pigpen.pigs.any((pig) => pig.tag == existingPig.tag)) {
          _selectedPigpen = pigpen;
          _pigsInSelectedPen = pigpen.pigs.toList();
          _selectedPig = existingPig;
          break;
        }
      }
    }
  }

  void _updatePigsList(Pigpen? pigpen) {
    setState(() {
      _selectedPigpen = pigpen;
      _pigsInSelectedPen = pigpen?.pigs.toList() ?? [];
      _selectedPig = null; // Reset selected pig when changing pen
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSale != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Sale" : "Add Sale"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Pigpen selection - disabled when editing
              // Pigpen selection - disabled when editing
              AbsorbPointer(
                absorbing: isEditing,
                child: DropdownButtonFormField<Pigpen>(
                  value: _selectedPigpen,
                  decoration: InputDecoration(
                    labelText: "Pig Pen *",
                    border: const OutlineInputBorder(),
                    filled: isEditing,
                    fillColor: isEditing ? Colors.grey[200] : null,
                  ),
                  items: widget.allPigpens
                      .map((pen) => DropdownMenuItem(
                            value: pen,
                            child:
                                Text("${pen.name} (${pen.pigs.length} pigs)"),
                          ))
                      .toList(),
                  onChanged: _updatePigsList,
                  validator: isEditing
                      ? null
                      : (value) =>
                          value == null ? 'Please select a pig pen' : null,
                ),
              ),

// Pig selection - disabled when editing
              if (_selectedPigpen != null)
                AbsorbPointer(
                  absorbing: isEditing,
                  child: DropdownButtonFormField<Pig>(
                    value: _selectedPig,
                    decoration: InputDecoration(
                      labelText: "Pig *",
                      border: const OutlineInputBorder(),
                      filled: isEditing,
                      fillColor: isEditing ? Colors.grey[200] : null,
                    ),
                    items: _pigsInSelectedPen.map((pig) {
                      return DropdownMenuItem(
                        value: pig,
                        child: Text(
                            "Tag: ${pig.tag} - (${pig.name ?? 'No name'})"),
                      );
                    }).toList(),
                    onChanged: (pig) => setState(() => _selectedPig = pig),
                    validator: isEditing
                        ? null
                        : (value) =>
                            value == null ? 'Please select a pig' : null,
                  ),
                ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: "Weight (kg) *",
                  border: OutlineInputBorder(),
                  suffixText: 'kg',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    if (isEditing && widget.existingSale?.weight != null) {
                      return null; // Allow empty if editing and weight exists
                    }
                    return 'Required field';
                  }
                  final weight = double.tryParse(value);
                  if (weight == null || weight <= 0) {
                    return 'Enter valid weight';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Buyer Name (unchanged)
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

              // New: Buyer Contact
              TextFormField(
                controller: _buyerContactController,
                decoration: const InputDecoration(
                  labelText: "Buyer Contact (Optional)",
                  border: OutlineInputBorder(),
                  hintText: "Phone number or other contact info",
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: "Amount *",
                  border: OutlineInputBorder(),
                  prefixText: '₱',
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
                      onPressed: _saveSale,
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

    // When editing, we don't need to validate pigpen and pig selection
    if (widget.existingSale == null && _selectedPig == null) return;

    final sale = Sale(
      id: widget.existingSale?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      pigTag: widget.existingSale?.pigTag ?? _selectedPig!.tag,
      buyerName: _buyerNameController.text,
      amount: double.parse(_amountController.text),
      date: _selectedDate,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      weight: double.parse(_weightController.text),
      buyerContact: _buyerContactController.text.isEmpty
          ? null
          : _buyerContactController.text,
    );

    Navigator.pop(context, sale);
  }
}
