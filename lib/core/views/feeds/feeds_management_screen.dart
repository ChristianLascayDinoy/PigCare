import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/views/feeds/feeding_schedule_screen.dart';

class FeedManagementScreen extends StatefulWidget {
  const FeedManagementScreen({super.key});

  @override
  _FeedManagementScreenState createState() => _FeedManagementScreenState();
}

class _FeedManagementScreenState extends State<FeedManagementScreen> {
  late Box<Feed> feedsBox;
  final double lowStockThreshold = 10.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    try {
      if (!Hive.isBoxOpen('feedsBox')) {
        await Hive.openBox<Feed>('feedsBox');
      }
      setState(() {
        feedsBox = Hive.box<Feed>('feedsBox');
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load feed data: ${e.toString()}')),
      );
    }
  }

  void _showFeedDialog({Feed? feed, int? index}) {
    final formKey = GlobalKey<FormState>();
    final TextEditingController nameController =
        TextEditingController(text: feed?.name ?? '');
    final TextEditingController quantityController =
        TextEditingController(text: feed?.quantity.toStringAsFixed(2) ?? '');
    final TextEditingController priceController =
        TextEditingController(text: feed?.price.toStringAsFixed(2) ?? '');
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
                    if (price > 1000) {
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
            onPressed: () {
              if (formKey.currentState!.validate()) {
                try {
                  final newFeed = Feed(
                    name: nameController.text.trim(),
                    quantity: double.parse(quantityController.text),
                    price: double.parse(priceController.text),
                    purchaseDate: selectedPurchaseDate,
                  );

                  setState(() {
                    if (index == null) {
                      feedsBox.add(newFeed);
                    } else {
                      feedsBox.putAt(index, newFeed);
                    }
                  });

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error saving feed: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFeed(int index) async {
    final feedToDelete = feedsBox.getAt(index);
    if (feedToDelete == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Feed?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This will permanently remove this feed record."),
            if (feedToDelete.quantity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Warning: This feed still has ${feedToDelete.quantity} kg remaining!",
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
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await feedsBox.deleteAt(index);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feed deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete feed: ${e.toString()}'),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("🐷 PigCare Feeds"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Stock Summary Card
          ValueListenableBuilder(
            valueListenable: feedsBox.listenable(),
            builder: (context, Box<Feed> box, _) {
              double totalStock = 0;
              int lowStockCount = 0;

              for (final feed in box.values) {
                totalStock += feed.quantity;
                if (feed.quantity < lowStockThreshold) {
                  lowStockCount++;
                }
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
                          Icon(Icons.inventory,
                              color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            "Feed Inventory Summary",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "📦 Total Stock: ${totalStock.toStringAsFixed(2)} kg",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lowStockCount > 0
                            ? "⚠️ $lowStockCount item(s) below $lowStockThreshold kg"
                            : "✅ Stock levels are good",
                        style: TextStyle(
                          color: lowStockCount > 0
                              ? Theme.of(context).colorScheme.error
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    label: const Text("Schedule"),
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
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Theme.of(context).disabledColor,
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
                      DataColumn(label: Text("Qty (kg)"), numeric: true),
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
                          DataCell(
                            Text(
                              feed.quantity.toStringAsFixed(2),
                              style: TextStyle(
                                color: isLowStock ? Colors.red : null,
                              ),
                            ),
                          ),
                          DataCell(Text("₱${feed.price.toStringAsFixed(2)}")),
                          DataCell(Text(DateFormat('MMM dd, yyyy')
                              .format(feed.purchaseDate))),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  color: Colors.blue,
                                  onPressed: () =>
                                      _showFeedDialog(feed: feed, index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  onPressed: () => _deleteFeed(index),
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
  }
}
