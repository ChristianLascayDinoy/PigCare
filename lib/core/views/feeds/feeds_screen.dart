import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/feed_model.dart';
import 'package:pigcare/core/views/feeds/feeding_schedule_screen.dart';

class FeedManagementScreen extends StatefulWidget {
  const FeedManagementScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FeedManagementScreenState createState() => _FeedManagementScreenState();
}

class _FeedManagementScreenState extends State<FeedManagementScreen> {
  late Box<Feed> feedsBox;
  final double lowStockThreshold = 10.0; // Change based on preference

  @override
  void initState() {
    super.initState();
    feedsBox = Hive.box<Feed>('feedsBox');
  }

  void _showFeedDialog({Feed? feed, int? index}) {
    TextEditingController nameController =
        TextEditingController(text: feed?.name ?? '');
    TextEditingController quantityController =
        TextEditingController(text: feed?.quantity.toString() ?? '');
    TextEditingController priceController =
        TextEditingController(text: feed?.price.toString() ?? '');
    DateTime selectedPurchaseDate = feed?.purchaseDate ?? DateTime.now();

    Future<void> selectDate(BuildContext context) async {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (picked != null) {
        setState(() {
          selectedPurchaseDate = picked;
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feed == null ? "Add Feed" : "Edit Feed"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Feed Name"),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: "Quantity (kg)"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: "Price per kg"),
                keyboardType: TextInputType.number,
              ),
              ListTile(
                title: Text("Purchase Date: ${selectedPurchaseDate.toLocal()}"
                    .split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => selectDate(context),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  quantityController.text.isNotEmpty &&
                  priceController.text.isNotEmpty) {
                Feed newFeed = Feed(
                  name: nameController.text,
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
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteFeed(int index) {
    setState(() {
      feedsBox.deleteAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🐷 PigCare Feeds")),
      body: Column(
        children: [
          ValueListenableBuilder(
            valueListenable: feedsBox.listenable(),
            builder: (context, Box<Feed> box, _) {
              double totalStock = 0;
              int lowStockCount = 0;

              for (var feed in box.values) {
                totalStock += feed.quantity;
                if (feed.quantity < lowStockThreshold) {
                  lowStockCount++;
                }
              }

              return Column(
                children: [
                  // Header Section
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: ListTile(
                      leading: const Icon(Icons.inventory, color: Colors.green),
                      title: Text(
                          "📦 Total Feed Stock: ${totalStock.toStringAsFixed(1)} kg"),
                      subtitle: Text(
                        lowStockCount > 0
                            ? "⚠️ $lowStockCount low stock feeds"
                            : "✅ Stock levels are good",
                        style: TextStyle(
                            color:
                                lowStockCount > 0 ? Colors.red : Colors.green),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Buttons: "Add New Feed" and "View Feeding Guide"
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showFeedDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add New Feed"),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                const SizedBox(width: 12), // Space between buttons
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AddFeedingScheduleScreen()),
                    );
                  },
                  icon: const Icon(Icons.menu_book),
                  label: const Text("Add Feeding Schedule"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
          ),

          // Feed Table or Empty State
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: feedsBox.listenable(),
              builder: (context, Box<Feed> box, _) {
                if (box.isEmpty) {
                  return const Center(child: Text("No feeds available"));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    columns: const [
                      DataColumn(label: Text("Name")),
                      DataColumn(label: Text("Quantity (kg)")),
                      DataColumn(label: Text("Price")),
                      DataColumn(label: Text("Date Purchased")),
                      DataColumn(label: Text("Remaining (kg)")),
                      DataColumn(label: Text("Action")),
                    ],
                    rows: List.generate(box.length, (index) {
                      final feed = box.getAt(index)!;
                      bool isLowStock = feed.quantity < lowStockThreshold;

                      return DataRow(
                        color: isLowStock
                            ? WidgetStateProperty.all(Colors.red[100])
                            : WidgetStateProperty.all(Colors.white),
                        cells: [
                          DataCell(Text(feed.name)),
                          DataCell(Text("${feed.quantity} kg")),
                          DataCell(Text("\$${feed.price}")),
                          DataCell(Text(feed.purchaseDate
                              .toLocal()
                              .toString()
                              .split(' ')[0])),
                          DataCell(Text("${feed.quantity} kg")),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.manage_accounts,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _showFeedDialog(feed: feed, index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
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
