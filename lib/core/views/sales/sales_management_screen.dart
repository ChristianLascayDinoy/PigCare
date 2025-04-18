// screens/sales_management_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../models/sale_model.dart';
import '../../models/pig_model.dart';
import '../../widgets/add_edit_sale_dialog.dart';

class SalesManagementScreen extends StatefulWidget {
  final List<Pig> allPigs;

  const SalesManagementScreen({
    super.key,
    required this.allPigs,
  });

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {
  late Box<Sale> _salesBox;
  List<Sale> _allSales = [];
  String _searchQuery = '';
  bool _isLoading = false;

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
    if (_searchQuery.isEmpty) return _allSales;
    return _allSales.where((sale) {
      return sale.pigTag.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sale.buyerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (sale.description
                  ?.toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ??
              false);
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
        title: const Text("Sales Management"),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSaleDialog(),
            tooltip: 'Add new sale',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
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

  Widget _buildSalesList() {
    if (_filteredSales.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? "No sales found\nAdd your first sale!"
              : "No sales match your search",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSales,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
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
                      pig.name ?? pig.tag,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    NumberFormat.currency(symbol: '\$').format(sale.amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditSaleDialog(sale),
                    tooltip: 'Edit sale',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _confirmDeleteSale(sale),
                    tooltip: 'Delete sale',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSaleDialog() async {
    final result = await showDialog<Sale>(
      context: context,
      builder: (context) => AddEditSaleDialog(
        allPigs: widget.allPigs,
      ),
    );

    if (result != null) {
      await _saveSale(result);
    }
  }

  Future<void> _showEditSaleDialog(Sale sale) async {
    final result = await showDialog<Sale>(
      context: context,
      builder: (context) => AddEditSaleDialog(
        allPigs: widget.allPigs,
        existingSale: sale,
      ),
    );

    if (result != null) {
      await _saveSale(result);
    }
  }

  Future<void> _saveSale(Sale sale) async {
    try {
      await _salesBox.put(sale.id, sale);
      await _loadSales();
      _showSuccessSnackbar('Sale saved successfully');
    } catch (e) {
      _showErrorSnackbar('Error saving sale: $e');
    }
  }

  Future<void> _showSaleDetails(Sale sale, Pig pig) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Sale Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Pig', pig.name ?? pig.tag),
              _buildDetailRow('Buyer', sale.buyerName),
              _buildDetailRow('Amount',
                  NumberFormat.currency(symbol: '\$').format(sale.amount)),
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
}
