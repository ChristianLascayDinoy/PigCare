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
      _showError('Error loading data: ${e.toString()}');
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
      selectedPigs.clear();
      pigsInSelectedPen = pigpen?.pigs.toList() ?? [];
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
    if (!_validateForm()) return;

    final double quantity = double.tryParse(quantityController.text) ?? 0;
    final List<Pig> pigsToFeed = assignToAll ? pigsInSelectedPen : selectedPigs;

    try {
      final schedules = <FeedingSchedule>[];

      for (final pig in pigsToFeed) {
        if (_hasDuplicateSchedule(pig)) continue;

        final schedule = FeedingSchedule.create(
          pigId: pig.tag,
          pigName: pig.name ?? 'Unnamed Pig',
          pigpenId: selectedPigpen!.name,
          feedType: selectedFeed!.name,
          quantity: quantity,
          time: selectedTime.format(context),
          date: DateTime.now(),
        );

        schedules.add(schedule);
      }

      // Save all schedules to Hive
      for (final schedule in schedules) {
        await feedingScheduleBox.put(schedule.id, schedule);
        await schedule.scheduleNotification();
      }

      _resetForm();
      _showSuccess('Schedule saved for ${pigsToFeed.length} pigs!');
    } catch (e) {
      _showError('Error saving schedule: ${e.toString()}');
    }
  }

  bool _validateForm() {
    if (selectedPigpen == null ||
        selectedFeed == null ||
        quantityController.text.isEmpty ||
        (!assignToAll && selectedPigs.isEmpty)) {
      _showError("Please fill in all required fields.");
      return false;
    }

    final double quantity = double.tryParse(quantityController.text) ?? 0;
    if (quantity <= 0) {
      _showError("Please enter a valid quantity.");
      return false;
    }

    return true;
  }

  bool _hasDuplicateSchedule(Pig pig) {
    return feedingScheduleBox.values.any(
        (s) => s.pigId == pig.tag && s.time == selectedTime.format(context));
  }

  void _resetForm() {
    setState(() {
      quantityController.clear();
      selectedPigs.clear();
    });
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
        await schedule.delete();
        _showSuccess('Schedule deleted successfully');
        setState(() {}); // Refresh the UI
      } catch (e) {
        _showError('Error deleting schedule: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
            _buildFormSection(),
            _buildScheduleListSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildPigPenDropdown(),
                  const SizedBox(height: 16),
                  if (selectedPigpen != null) _buildPigSelection(),
                  const SizedBox(height: 16),
                  _buildFeedDropdown(),
                  const SizedBox(height: 16),
                  _buildQuantityInput(),
                  const SizedBox(height: 16),
                  _buildTimePicker(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPigPenDropdown() {
    return DropdownButtonFormField<Pigpen>(
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
          child: Text("${pen.name} (${pen.pigs.length} pigs)"),
        );
      }).toList(),
      onChanged: _updatePigsList,
    );
  }

  Widget _buildPigSelection() {
    return Column(
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
            title: const Text("Apply to all pigs in this pen"),
            value: assignToAll,
            onChanged: (value) => setState(() {
              assignToAll = value!;
              if (assignToAll) selectedPigs.clear();
            }),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (!assignToAll) ...[
            const SizedBox(height: 8),
            const Text("Select Pigs:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: pigsInSelectedPen.length,
                itemBuilder: (context, index) {
                  final pig = pigsInSelectedPen[index];
                  return CheckboxListTile(
                    title: Text("${pig.name ?? 'Unnamed'} (${pig.tag})"),
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
    );
  }

  Widget _buildFeedDropdown() {
    return DropdownButtonFormField<Feed>(
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
                    color: feed.remainingQuantity < 5 ? Colors.red : null,
                  ),
                ),
              ))
          .toList(),
      onChanged: (feed) => setState(() => selectedFeed = feed),
    );
  }

  Widget _buildQuantityInput() {
    return TextFormField(
      controller: quantityController,
      decoration: const InputDecoration(
        labelText: "Quantity per pig (kg)*",
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
    );
  }

  Widget _buildTimePicker() {
    return InkWell(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveFeedingSchedule,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          "SAVE SCHEDULE",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildScheduleListSection() {
    return Column(
      children: [
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
          height: MediaQuery.of(context).size.height * 0.5,
          child: _buildScheduleList(),
        ),
      ],
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
