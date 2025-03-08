import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../models/pig_model.dart';
import '../../models/pigpen_model.dart'; // Ensure PigPen model is correctly imported

class PigManagementScreen extends StatefulWidget {
  final int pigpenIndex;

  const PigManagementScreen({super.key, required this.pigpenIndex});

  @override
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
      pigs = pigpen.pigs ?? [];
    });
  }

  void _showPigDialog({int? index}) {
    TextEditingController tagController = TextEditingController();
    TextEditingController breedController = TextEditingController();
    TextEditingController weightController = TextEditingController();
    TextEditingController dobController = TextEditingController();
    TextEditingController doeController = TextEditingController();
    TextEditingController notesController = TextEditingController();

    String? selectedGender;
    String? selectedStage;
    String? selectedSource;
    File? imageFile;
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

    Future<void> _pickImage(ImageSource source) async {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          imageFile = File(pickedFile.path);
          imagePath = pickedFile.path;
        });
      }
    }

    void _showImageSourceDialog() {
      showModalBottomSheet(
        context: context,
        builder: (context) => Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take Photo"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(index == null ? "Add Pig" : "Edit Pig"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _showImageSourceDialog,
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
                      ? const Icon(Icons.add_a_photo,
                          size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(tagController, "Tag Number"),
              _buildTextField(breedController, "Breed"),
              _buildDropdownField("Gender", ["Male", "Female"], selectedGender,
                  (value) => setState(() => selectedGender = value)),
              _buildDropdownField(
                  "Pig Stage",
                  ["Piglet", "Barrow/Stag", "Weaner", "Boar", "Other"],
                  selectedStage,
                  (value) => setState(() => selectedStage = value)),
              _buildTextField(weightController, "Weight (kg)", isNumber: true),
              _buildDropdownField(
                "Source",
                ["Purchased", "Born on Farm", "Gifted", "Other"],
                selectedSource,
                (value) => setState(() => selectedSource = value),
              ),
              _buildDatePicker(dobController, "Date of Birth"),
              _buildDatePicker(doeController, "Date of Entry on Farm"),
              _buildTextField(notesController, "Notes (Optional)", maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (tagController.text.isNotEmpty &&
                  breedController.text.isNotEmpty &&
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
                  if (index == null) {
                    pigs.add(newPig);
                  } else {
                    pigs[index] = newPig;
                  }

                  var pigpen = pigpenBox.getAt(widget.pigpenIndex) as Pigpen;
                  pigpen.pigs = pigs;
                  pigpenBox.putAt(widget.pigpenIndex, pigpen);
                });

                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Please fill in all required fields"),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, int maxLines = 1}) {
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
    setState(() {
      pigs.removeAt(index);
      var pigpen = pigpenBox.getAt(widget.pigpenIndex) as Pigpen;
      pigpen.pigs = pigs;
      pigpenBox.putAt(widget.pigpenIndex, pigpen);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pig Management")),
      body: ListView.builder(
        itemCount: pigs.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: pigs[index].imagePath != null
                ? Image.file(File(pigs[index].imagePath!),
                    width: 50, height: 50, fit: BoxFit.cover)
                : const Icon(Icons.pets, size: 40),
            title: Text(pigs[index].tag),
            subtitle: Text(pigs[index].breed),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showPigDialog(index: index)),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePig(index)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPigDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
