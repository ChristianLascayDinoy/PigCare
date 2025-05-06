import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/providers/feed_expense_provider.dart';
import 'package:pigcare/core/views/feeds/feeding_schedule_screen.dart';

class FeedManagementScreen extends StatefulWidget {
  const FeedManagementScreen({super.key});

  @override
  _FeedManagementScreenState createState() => _FeedManagementScreenState();
}

class _FeedManagementScreenState extends State<FeedManagementScreen> {
  final double lowStockThreshold = 10.0;
  bool _isLoading = true;
  bool _initializationError = false;

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
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _isLoading = false;
        _initializationError = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showFeedDialog({Feed? feed}) {
    // Removed index parameter
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: feed?.name ?? '');
    final quantityController =
        TextEditingController(text: feed?.quantity.toStringAsFixed(2) ?? '');
    final priceController =
        TextEditingController(text: feed?.price.toStringAsFixed(2) ?? '');
    final supplierController =
        TextEditingController(text: feed?.supplier ?? '');
    final brandController = TextEditingController(text: feed?.brand ?? '');
    DateTime selectedPurchaseDate = feed?.purchaseDate ?? DateTime.now();

    Future<void> selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedPurchaseDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (picked != null && picked != selectedPurchaseDate) {
        setState(() => selectedPurchaseDate = picked);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feed == null ? "Add Feed" : "Edit Feed"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Feed Name *",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter feed name';
                    }
                    if (value.length > 50) {
                      return 'Name too long (max 50 chars)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: brandController,
                  decoration: const InputDecoration(
                    labelText: "Brand *",
                    border: OutlineInputBorder(),
                    hintText: "Feed brand/manufacturer",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter feed brand';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: supplierController,
                  decoration: const InputDecoration(
                    labelText: "Supplier/Store *",
                    border: OutlineInputBorder(),
                    hintText: "Where you purchased the feed",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter supplier/store name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: "Quantity (kg) *",
                    border: OutlineInputBorder(),
                    suffixText: 'kg',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity';
                    }
                    final quantity = double.tryParse(value);
                    if (quantity == null) {
                      return 'Enter valid number';
                    }
                    if (quantity <= 0) {
                      return 'Must be greater than 0';
                    }
                    if (quantity > 10000) {
                      return 'Quantity too large';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: "Price (₱) *",
                    border: OutlineInputBorder(),
                    prefixText: '₱',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter price';
                    }
                    final price = double.tryParse(value);
                    if (price == null) {
                      return 'Enter valid number';
                    }
                    if (price <= 0) {
                      return 'Must be greater than 0';
                    }
                    if (price > 100000) {
                      return 'Price too high';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text("Purchase Date *"),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(selectedPurchaseDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  onTap: () => selectDate(context),
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
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final provider =
                      Provider.of<FeedExpenseProvider>(context, listen: false);
                  final newFeed = Feed(
                    id: feed?.id, // Preserve existing ID if editing
                    name: nameController.text.trim(),
                    quantity: double.parse(quantityController.text),
                    price: double.parse(priceController.text),
                    purchaseDate: selectedPurchaseDate,
                    supplier: supplierController.text.trim(),
                    brand: brandController.text.trim(),
                  );

                  if (feed == null) {
                    await provider.addFeedWithExpense(newFeed);
                  } else {
                    await provider.updateFeedWithExpense(newFeed);
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Feed and expense saved successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error saving data: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFeed(Feed feedToDelete) async {
    // Removed index parameter
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Feed?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This will also delete the associated expense record."),
            if (feedToDelete.quantity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Warning: This feed still has ${feedToDelete.remainingQuantity} kg remaining!",
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
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
        await provider.deleteFeed(feedToDelete);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Feed and expense deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Loading feed data...'),
              if (_initializationError) ...[
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _initializeData,
                  child: const Text('Retry Initialization'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_initializationError) {
      return Scaffold(
        appBar: AppBar(title: const Text("Feed Management")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 20),
              const Text('Failed to initialize database'),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _initializeData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<FeedExpenseProvider>(
      builder: (context, provider, child) {
        final feedsBox = provider.feedsBox;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize:
                  MainAxisSize.min, // <-- this helps center the Row contents
              children: [
                ClipOval(
                  child: Image.asset(
                    'lib/assets/images/feed.png',
                    height: 40,
                    width: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Feed Management",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Inside the ValueListenableBuilder where the summary card is built:
              ValueListenableBuilder(
                valueListenable: feedsBox.listenable(),
                builder: (context, Box<Feed> box, _) {
                  double totalFeeds = 0;
                  int lowStockCount = 0;
                  List<MapEntry<String, double>> feedQuantities = [];

                  for (final feed in box.values) {
                    totalFeeds += feed.quantity;
                    if (feed.remainingQuantity < lowStockThreshold) {
                      lowStockCount++;
                    }
                    feedQuantities
                        .add(MapEntry(feed.name, feed.remainingQuantity));
                  }

                  return Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'lib/assets/images/feed.png',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Feed Inventory Summary",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Total Feeds: ${totalFeeds.toStringAsFixed(2)} kg",
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyLarge,
                              children: [
                                TextSpan(
                                  text: "Feeds Level: ",
                                  style: TextStyle(color: Colors.black),
                                ),
                                TextSpan(
                                  text: lowStockCount > 0
                                      ? "$lowStockCount item(s) below $lowStockThreshold kg remaining"
                                      : "Stock levels are good",
                                  style: TextStyle(
                                    color: lowStockCount > 0
                                        ? Theme.of(context).colorScheme.error
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Add this new section for feed quantities
                          if (feedQuantities.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Text(
                              "Remaining Quantities:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: feedQuantities.map((entry) {
                                return Text(
                                  "${entry.key}: ${entry.value.toStringAsFixed(2)} kg",
                                  style: TextStyle(
                                    color: entry.value < lowStockThreshold
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Action Buttons
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showFeedDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Feed"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddFeedingScheduleScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.schedule),
                        label: const Text("Feeding Schedules"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Feed Data Table
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: feedsBox.listenable(),
                  builder: (context, Box<Feed> box, _) {
                    if (box.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'lib/assets/images/feed.png',
                              width: 64,
                              height: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No feed records found",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Add your first feed item to get started",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text("Name")),
                          DataColumn(label: Text("Brand")),
                          DataColumn(label: Text("Supplier")),
                          DataColumn(
                              label: Text("Quantity (kg)"), numeric: true),
                          DataColumn(label: Text("Price (₱)"), numeric: true),
                          DataColumn(label: Text("Purchase Date")),
                          DataColumn(label: Text("Actions")),
                        ],
                        rows: List.generate(box.length, (index) {
                          final feed = box.getAt(index)!;
                          final isLowStock = feed.quantity < lowStockThreshold;

                          return DataRow(
                            color: MaterialStateProperty.resolveWith<Color?>(
                              (states) => isLowStock
                                  ? Colors.red[50]?.withOpacity(0.3)
                                  : null,
                            ),
                            cells: [
                              DataCell(
                                Text(
                                  feed.name,
                                  style: TextStyle(
                                    fontWeight: isLowStock
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              DataCell(Text(feed.brand)),
                              DataCell(Text(feed.supplier)),
                              DataCell(Text(feed.quantity.toStringAsFixed(2))),
                              DataCell(
                                  Text("₱${feed.price.toStringAsFixed(2)}")),
                              DataCell(Text(DateFormat('MMM dd, yyyy')
                                  .format(feed.purchaseDate))),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      color: Colors.blue,
                                      onPressed: () =>
                                          _showFeedDialog(feed: feed),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      color: Colors.red,
                                      onPressed: () => _deleteFeed(feed),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
