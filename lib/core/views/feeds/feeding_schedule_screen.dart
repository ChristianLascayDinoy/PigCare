import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/pigpen_model.dart';
import '../../models/pig_model.dart';
import '../../models/feeding_schedule_model.dart';
import '../../models/feed_model.dart';

class AddFeedingScheduleScreen extends StatefulWidget {
  const AddFeedingScheduleScreen({super.key});

  @override
  _AddFeedingScheduleScreenState createState() =>
      _AddFeedingScheduleScreenState();
}

class _AddFeedingScheduleScreenState extends State<AddFeedingScheduleScreen> {
  late Box<Pigpen> pigpenBox;
  late Box<Feed> feedBox;
  late Box<Pig> pigBox;
  late Box<FeedingSchedule> feedingScheduleBox;
  List<Pig> selectedPigs = [];

  List<Pigpen> pigpens = [];
  List<Feed> feeds = [];
  List<Pig> pigsInSelectedPen = [];

  Pigpen? selectedPigpen;
  Pig? selectedPig;
  Feed? selectedFeed;
  TimeOfDay selectedTime = TimeOfDay.now();

  final TextEditingController quantityController = TextEditingController();
  bool assignToAll = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    try {
      pigpenBox = await Hive.openBox<Pigpen>('pigpens');
      feedBox = await Hive.openBox<Feed>('feedsBox');
      pigBox = await Hive.openBox<Pig>('pigs');
      feedingScheduleBox =
          await Hive.openBox<FeedingSchedule>('feedingSchedules');

      _loadData();
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    }
  }

  void _loadData() {
    setState(() {
      pigpens = pigpenBox.values.toList();
      feeds =
          feedBox.values.where((feed) => feed.remainingQuantity > 0).toList();
      isLoading = false;
    });
  }

  void _updatePigsList(Pigpen? pigpen) {
    setState(() {
      selectedPigpen = pigpen;
      selectedPigs.clear(); // Clear selection when changing pigpen

      if (pigpen != null) {
        pigsInSelectedPen = pigpen.pigs.toList();
        debugPrint('Found ${pigsInSelectedPen.length} pigs in ${pigpen.name}');
      } else {
        pigsInSelectedPen = [];
      }
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (pickedTime != null) {
      setState(() => selectedTime = pickedTime);
    }
  }

  Future<void> _saveFeedingSchedule() async {
    if (selectedPigpen == null ||
        selectedFeed == null ||
        quantityController.text.isEmpty ||
        (!assignToAll && selectedPigs.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields.")),
      );
      return;
    }

    final double quantity = double.tryParse(quantityController.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid quantity.")),
      );
      return;
    }

    final List<Pig> pigsToFeed = assignToAll ? pigsInSelectedPen : selectedPigs;
    final double totalRequired = pigsToFeed.length * quantity;

    if (selectedFeed!.remainingQuantity < totalRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Not enough ${selectedFeed!.name} available! "
                "Available: ${selectedFeed!.remainingQuantity} kg, "
                "Required: $totalRequired kg")),
      );
      return;
    }

    try {
      for (final pig in pigsToFeed) {
        // Ensure non-null values for all required fields
        final pigName = pig.name ?? 'Unnamed Pig'; // Provide default if null
        final pigTag = pig.tag; // Assuming tag is non-nullable
        final penName = selectedPigpen!.name;
        final feedName = selectedFeed!.name;
        final timeString = selectedTime.format(context);

        await feedingScheduleBox.add(FeedingSchedule(
          pigId: pigTag,
          pigName: pigName,
          pigpenId: penName,
          feedType: feedName,
          quantity: quantity,
          time: timeString,
          date: DateTime.now(),
        ));
      }

      selectedFeed!.deductFeed(totalRequired);
      await feedBox.put(selectedFeed!.key, selectedFeed!);

      // Clear form after successful save
      setState(() {
        quantityController.clear();
        selectedPigs.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule saved successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving schedule: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteSchedule(FeedingSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Schedule?"),
        content:
            const Text("This will permanently remove this feeding schedule."),
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
        // Find the key for this schedule
        final key = feedingScheduleBox.keyAt(
          feedingScheduleBox.values.toList().indexOf(schedule),
        );
        await feedingScheduleBox.delete(key);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting schedule: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Feeding Schedules"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Form Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Create New Schedule",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),

                          // Pig Pen Selection
                          DropdownButtonFormField<Pigpen>(
                            decoration: const InputDecoration(
                              labelText: "Select Pig Pen*",
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: selectedPigpen,
                            items: pigpens.map((pen) {
                              return DropdownMenuItem(
                                value: pen,
                                child: Text(
                                    "${pen.name} (${pen.pigs.length} pigs)"),
                              );
                            }).toList(),
                            onChanged: (pen) => _updatePigsList(pen),
                          ),
                          const SizedBox(height: 16),

                          // Pig Selection
                          if (selectedPigpen != null) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Pigs in ${selectedPigpen!.name}: ${pigsInSelectedPen.length}",
                                  style: const TextStyle(fontSize: 16),
                                ),
                                if (pigsInSelectedPen.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      "No pigs found in this pen",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                if (pigsInSelectedPen.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                    title: const Text(
                                        "Apply to all pigs in this pen"),
                                    value: assignToAll,
                                    onChanged: (value) => setState(() {
                                      assignToAll = value!;
                                      if (assignToAll) selectedPigs.clear();
                                    }),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  if (!assignToAll) ...[
                                    const SizedBox(height: 8),
                                    const Text("Select Pigs:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 150,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListView.builder(
                                        itemCount: pigsInSelectedPen.length,
                                        itemBuilder: (context, index) {
                                          final pig = pigsInSelectedPen[index];
                                          return CheckboxListTile(
                                            title: Text(
                                                "${pig.name ?? 'Unnamed'} (${pig.tag})"),
                                            value: selectedPigs.contains(pig),
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  selectedPigs.add(pig);
                                                } else {
                                                  selectedPigs.remove(pig);
                                                }
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Feed Selection
                          DropdownButtonFormField<Feed>(
                            decoration: const InputDecoration(
                              labelText: "Select Feed Type*",
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: selectedFeed,
                            items: feeds
                                .map((feed) => DropdownMenuItem(
                                      value: feed,
                                      child: Text(
                                        "${feed.name} (${feed.remainingQuantity.toStringAsFixed(2)} kg)",
                                        style: TextStyle(
                                          color: feed.remainingQuantity < 5
                                              ? Colors.red
                                              : null,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (feed) =>
                                setState(() => selectedFeed = feed),
                          ),
                          const SizedBox(height: 16),

                          // Quantity Input
                          TextFormField(
                            controller: quantityController,
                            decoration: const InputDecoration(
                              labelText: "Quantity per pig (kg)*",
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Time Selection
                          InkWell(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Feeding Time*",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Text(
                                    selectedTime.format(context),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const Icon(Icons.access_time),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saveFeedingSchedule,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "SAVE SCHEDULE",
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Schedule List Section
            const Divider(height: 1, thickness: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: const Row(
                children: [
                  Icon(Icons.history, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    "Existing Schedules",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: MediaQuery.of(context).size.height *
                  0.5, // Adjust height as needed
              child: _buildScheduleList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    return ValueListenableBuilder(
      valueListenable: feedingScheduleBox.listenable(),
      builder: (context, Box<FeedingSchedule> box, _) {
        final schedules = box.values.toList().cast<FeedingSchedule>();

        if (schedules.isEmpty) {
          return const Center(
            child: Text("No feeding schedules found"),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              headingRowColor: MaterialStateProperty.resolveWith<Color>(
                (states) => Colors.green[50]!,
              ),
              columns: const [
                DataColumn(label: Text("Pig ID")),
                DataColumn(label: Text("Name")),
                DataColumn(label: Text("Pen")),
                DataColumn(label: Text("Feed")),
                DataColumn(label: Text("Qty (kg)"), numeric: true),
                DataColumn(label: Text("Time")),
                DataColumn(label: Text("Actions")),
              ],
              rows: schedules.map((schedule) {
                return DataRow(
                  cells: [
                    DataCell(Text(schedule.pigId)),
                    DataCell(Text(schedule.pigName)),
                    DataCell(Text(schedule.pigpenId)),
                    DataCell(Text(schedule.feedType)),
                    DataCell(Text(schedule.quantity.toStringAsFixed(2))),
                    DataCell(Text(schedule.time)),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red,
                        onPressed: () => _deleteSchedule(schedule),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
