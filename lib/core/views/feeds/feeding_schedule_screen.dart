import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
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
      selectedPig = null;

      if (pigpen != null) {
        // Get all pigs where pigpenKey matches the selected pigpen's key
        pigsInSelectedPen =
            pigBox.values.where((pig) => pig.pigpenKey == pigpen.key).toList();

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
        (!assignToAll && selectedPig == null)) {
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

    final List<Pig> pigsToFeed =
        assignToAll ? pigsInSelectedPen : [selectedPig!];
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
      // Save feeding schedules
      for (final pig in pigsToFeed) {
        await feedingScheduleBox.add(FeedingSchedule(
          pigId: pig.tag,
          pigName: pig.name,
          pigpenId: selectedPigpen!.name,
          feedType: selectedFeed!.name,
          quantity: quantity,
          time: selectedTime.format(context),
          date: DateTime.now(),
        ));
      }

      // Deduct feed from inventory
      selectedFeed!.deductFeed(totalRequired);
      await feedBox.put(selectedFeed!.key, selectedFeed!);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving schedule: ${e.toString()}')),
      );
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
        title: const Text("Add Feeding Schedule"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pig Pen Selection
            DropdownButtonFormField<Pigpen>(
              decoration: const InputDecoration(
                labelText: "Select Pig Pen*",
                border: OutlineInputBorder(),
              ),
              value: selectedPigpen,
              items: pigpens.map((pen) {
                // Count pigs in this pen
                final pigCount = pigBox.values
                    .where((pig) => pig.pigpenKey == pen.key)
                    .length;

                return DropdownMenuItem(
                  value: pen,
                  child: Text("${pen.name} ($pigCount pigs)"),
                );
              }).toList(),
              onChanged: (pen) => _updatePigsList(pen),
              validator: (value) => value == null ? "Required field" : null,
            ),

            const SizedBox(height: 16),

            // Pig Selection (only shown if pigpen selected)
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
                    // Apply to all toggle
                    CheckboxListTile(
                      title: const Text("Apply to all pigs in this pen"),
                      value: assignToAll,
                      onChanged: (value) => setState(() {
                        assignToAll = value!;
                        if (assignToAll) selectedPig = null;
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    // Individual pig selection (only if not applying to all)
                    if (!assignToAll) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Pig>(
                        decoration: const InputDecoration(
                          labelText: "Select Pig*",
                          border: OutlineInputBorder(),
                        ),
                        value: selectedPig,
                        items: pigsInSelectedPen
                            .map((pig) => DropdownMenuItem(
                                  value: pig,
                                  child: Text("${pig.name} (${pig.tag})"),
                                ))
                            .toList(),
                        onChanged: (pig) => setState(() => selectedPig = pig),
                        validator: (value) =>
                            value == null ? "Required field" : null,
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
              ),
              value: selectedFeed,
              items: feeds
                  .map((feed) => DropdownMenuItem(
                        value: feed,
                        child: Text(
                          "${feed.name} (${feed.remainingQuantity.toStringAsFixed(2)} kg)",
                          style: TextStyle(
                            color:
                                feed.remainingQuantity < 5 ? Colors.red : null,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (feed) => setState(() => selectedFeed = feed),
              validator: (value) => value == null ? "Required field" : null,
            ),

            const SizedBox(height: 16),

            // Quantity Input
            TextFormField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: "Quantity per pig (kg)*",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return "Required field";
                final num = double.tryParse(value);
                if (num == null || num <= 0) return "Enter valid quantity";
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Time Selection
            ListTile(
              title: const Text("Feeding Time*"),
              subtitle: Text(
                selectedTime.format(context),
                style: const TextStyle(fontSize: 16),
              ),
              trailing: const Icon(Icons.access_time),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              onTap: _pickTime,
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _saveFeedingSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                "SAVE SCHEDULE",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
