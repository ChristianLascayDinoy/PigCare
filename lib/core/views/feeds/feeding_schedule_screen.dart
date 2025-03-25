import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/pigpen_model.dart';
import '../../models/feeding_schedule_model.dart';
import '../../models/feed_model.dart';

class AddFeedingScheduleScreen extends StatefulWidget {
  const AddFeedingScheduleScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AddFeedingScheduleScreenState createState() =>
      _AddFeedingScheduleScreenState();
}

class _AddFeedingScheduleScreenState extends State<AddFeedingScheduleScreen> {
  List pigpens = [];
  List<Feed> feeds = [];
  Pigpen? selectedPigpen;
  Feed? selectedFeed;
  TimeOfDay selectedTime = TimeOfDay.now();
  TextEditingController quantityController = TextEditingController();
  bool assignToAll = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var pigpenBox = Hive.box('pigpen');
    var feedBox = Hive.box<Feed>('feedsBox');

    setState(() {
      pigpens = pigpenBox.values.toList();
      feeds = feedBox.values
          .where((feed) => feed.remainingQuantity > 0)
          .toList(); // Only show feeds with stock
    });
  }

  void _pickTime() async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  void _saveFeedingSchedule() async {
    if (selectedPigpen == null ||
        selectedFeed == null ||
        quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields.")),
      );
      return;
    }

    double quantity = double.parse(quantityController.text);
    double totalRequired =
        assignToAll ? selectedPigpen!.pigs.length * quantity : quantity;

    if (selectedFeed!.remainingQuantity < totalRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not enough feed stock available!")),
      );
      return;
    }

    final feedingBox = await Hive.openBox<FeedingSchedule>('feedingSchedules');

    for (var pig in selectedPigpen!.pigs) {
      feedingBox.add(FeedingSchedule(
        pigId: pig.tag,
        pigpenId: selectedPigpen!.name,
        feedType: selectedFeed!.name,
        quantity: quantity,
        // ignore: use_build_context_synchronously
        time: selectedTime.format(context),
      ));
    }

    // Deduct Feed Stock
    selectedFeed!.deductFeed(totalRequired);

    // ignore: use_build_context_synchronously
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Add Feeding Schedule"),
          backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField(
              decoration: const InputDecoration(labelText: "Select Pig Pen"),
              items: pigpens
                  .map((pen) =>
                      DropdownMenuItem(value: pen, child: Text(pen.name)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => selectedPigpen = value as Pigpen?),
            ),
            if (selectedPigpen != null) ...[
              const SizedBox(height: 10),
              Text("Pigs Inside: ${selectedPigpen!.pigs.length}",
                  style: const TextStyle(fontSize: 16)),
              CheckboxListTile(
                title: const Text("Apply schedule to all pigs"),
                value: assignToAll,
                onChanged: (value) => setState(() => assignToAll = value!),
              ),
            ],
            DropdownButtonFormField<Feed>(
              decoration: const InputDecoration(labelText: "Select Feed Type"),
              items: feeds
                  .map((feed) => DropdownMenuItem(
                      value: feed,
                      child: Text(
                          "${feed.name} (${feed.remainingQuantity} kg left)")))
                  .toList(),
              onChanged: (value) => setState(() => selectedFeed = value),
            ),
            TextField(
              controller: quantityController,
              decoration:
                  const InputDecoration(labelText: "Feed Quantity (kg)"),
              keyboardType: TextInputType.number,
            ),
            ListTile(
              title: Text("Feeding Time: ${selectedTime.format(context)}"),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveFeedingSchedule,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text("Save Schedule"),
            ),
          ],
        ),
      ),
    );
  }
}
