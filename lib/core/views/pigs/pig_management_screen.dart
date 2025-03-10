import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../models/pig_model.dart';
import '../../models/pigpen_model.dart';
import 'pig_details_screen.dart';

class PigManagementScreen extends StatefulWidget {
  final int pigpenIndex;

  const PigManagementScreen({super.key, required this.pigpenIndex});

  @override
  // ignore: library_private_types_in_public_api
  _PigManagementScreenState createState() => _PigManagementScreenState();
}

class _PigManagementScreenState extends State<PigManagementScreen> {
  final ImagePicker _picker = ImagePicker();
  late Box pigpenBox;
  List<Pig> pigs = [];

  @override
  void initState() {
    super.initState();
    pigpenBox = Hive.box('pigpens');
    _loadPigs();
  }

  void _loadPigs() {
    var pigpen = pigpenBox.getAt(widget.pigpenIndex) as Pigpen;
    setState(() {
      pigs = List<Pig>.from(pigpen.pigs);
    });
  }

  void _showPigDialog({int? index}) {
    final formKey = GlobalKey<FormState>();
    TextEditingController tagController = TextEditingController();
    TextEditingController breedController = TextEditingController();
    TextEditingController weightController = TextEditingController();
    TextEditingController dobController = TextEditingController();
    TextEditingController doeController = TextEditingController();
    TextEditingController notesController = TextEditingController();

    String? selectedGender;
    String? selectedStage;
    String? selectedSource;
    String? imagePath;

    if (index != null) {
      var pig = pigs[index];
      tagController.text = pig.tag;
      breedController.text = pig.breed;
      weightController.text = pig.weight;
      dobController.text = pig.dob;
      doeController.text = pig.doe;
      notesController.text = pig.notes;
      selectedGender = pig.gender;
      selectedStage = pig.stage;
      selectedSource = pig.source;
      imagePath = pig.imagePath;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(index == null ? "Add Pig" : "Edit Pig"),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final pickedFile = await _picker.pickImage(
                              source: ImageSource.gallery);
                          if (pickedFile != null) {
                            setState(() => imagePath = pickedFile.path);
                          }
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                            image: imagePath != null
                                ? DecorationImage(
                                    image: FileImage(File(imagePath!)),
                                    fit: BoxFit.cover)
                                : null,
                          ),
                          child: imagePath == null
                              ? Icon(Icons.add_a_photo,
                                  size: 40, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(tagController, "Tag Number",
                          required: true),
                      _buildTextField(breedController, "Breed", required: true),
                      _buildDropdownField(
                          "Gender", ["Male", "Female"], selectedGender,
                          (value) {
                        setState(() => selectedGender = value);
                      }),
                      _buildDropdownField(
                          "Pig Stage",
                          ["Piglet", "Weaner", "Boar", "Other"],
                          selectedStage, (value) {
                        setState(() => selectedStage = value);
                      }),
                      _buildTextField(weightController, "Weight (kg)",
                          isNumber: true, required: true),
                      _buildDropdownField(
                          "Source",
                          ["Purchased", "Born on Farm", "Other"],
                          selectedSource, (value) {
                        setState(() => selectedSource = value);
                      }),
                      _buildDatePicker(dobController, "Date of Birth"),
                      _buildDatePicker(doeController, "Date of Entry on Farm"),
                      _buildTextField(notesController, "Notes (Optional)",
                          maxLines: 2, required: true),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate() &&
                        selectedGender != null) {
                      Pig newPig = Pig(
                        tag: tagController.text,
                        breed: breedController.text,
                        gender: selectedGender!,
                        stage: selectedStage ?? "Unknown",
                        weight: weightController.text,
                        dob: dobController.text,
                        doe: doeController.text,
                        source: selectedSource ?? "Unknown",
                        notes: notesController.text,
                        imagePath: imagePath,
                      );

                      setState(() {
                        var pigpen =
                            pigpenBox.getAt(widget.pigpenIndex) as Pigpen;
                        if (index == null) {
                          pigpen.pigs.add(newPig);
                        } else {
                          pigpen.pigs[index] = newPig;
                        }
                        pigpenBox.putAt(widget.pigpenIndex, pigpen);
                        _loadPigs(); // Reload pigs from Hive to ensure UI updates
                      });

                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, int maxLines = 1, required bool required}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: controller,
        decoration:
            InputDecoration(labelText: label, border: OutlineInputBorder()),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> items, String? value,
      Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration:
            InputDecoration(labelText: label, border: OutlineInputBorder()),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDatePicker(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: controller,
        decoration:
            InputDecoration(labelText: label, border: OutlineInputBorder()),
        readOnly: true,
        onTap: () async {
          DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now());
          if (picked != null) {
            controller.text = picked.toLocal().toString().split(' ')[0];
          }
        },
      ),
    );
  }

  void _deletePig(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: const Text("Are you sure you want to delete this pig?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  pigs.removeAt(index);
                  var pigpen = pigpenBox.getAt(widget.pigpenIndex) as Pigpen;
                  pigpen.pigs = pigs;
                  pigpenBox.putAt(widget.pigpenIndex, pigpen);
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Pig deleted"),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pig Management",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.green[700], // Green Theme
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView.builder(
          itemCount: pigs.length,
          itemBuilder: (context, index) {
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: pigs[index].imagePath != null
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(8), // Rounded image corners
                        child: Image.file(File(pigs[index].imagePath!),
                            width: 60, height: 60, fit: BoxFit.cover),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.green[
                              300], // Light green background for missing images
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.pets,
                            size: 40, color: Colors.white),
                      ),
                title: Text(
                  "Tag No. ${pigs[index].tag}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Breed: ${pigs[index].breed}",
                        style: TextStyle(color: Colors.grey[700])),
                    Text("Stage: ${pigs[index].stage}",
                        style: TextStyle(color: Colors.grey[700])),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.blue), // Green edit button
                      onPressed: () => _showPigDialog(index: index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePig(index),
                    ),
                  ],
                ),
                onTap: () {
                  // Navigate to Pig Details Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PigDetailsScreen(pig: pigs[index]),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPigDialog(),
        backgroundColor: Colors.green[700], // Green FAB
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
