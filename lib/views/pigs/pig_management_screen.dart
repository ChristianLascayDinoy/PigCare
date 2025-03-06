import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PigManagementScreen extends StatefulWidget {
  final Map<String, String> pigpen;

  const PigManagementScreen({Key? key, required this.pigpen}) : super(key: key);

  @override
  _PigManagementScreenState createState() => _PigManagementScreenState();
}

class _PigManagementScreenState extends State<PigManagementScreen> {
  List<Map<String, dynamic>> pigs = []; // Store pigs
  final ImagePicker _picker = ImagePicker();

  void _showPigDialog({int? index}) {
    TextEditingController tagController = TextEditingController();
    TextEditingController breedController = TextEditingController();
    TextEditingController weightController = TextEditingController();
    TextEditingController dobController = TextEditingController();
    TextEditingController doeController = TextEditingController();
    TextEditingController notesController = TextEditingController();
    TextEditingController otherStageController = TextEditingController();

    String? selectedGender;
    String? selectedStage;
    String? selectedSource;
    File? imageFile;

    if (index != null) {
      var pig = pigs[index];
      tagController.text = pig["tag"] ?? "";
      breedController.text = pig["breed"] ?? "";
      weightController.text = pig["weight"] ?? "";
      dobController.text = pig["dob"] ?? "";
      doeController.text = pig["doe"] ?? "";
      notesController.text = pig["notes"] ?? "";
      selectedGender = pig["gender"];
      selectedStage = pig["stage"];
      selectedSource = pig["source"];
      imageFile = pig["image"];
      if (!["Piglet", "Barrow/Stag", "Weaner", "Boar"]
          .contains(selectedStage)) {
        otherStageController.text = selectedStage ?? "";
        selectedStage = "Other";
      }
    }

    Future<void> _pickImageFromGallery() async {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          imageFile = File(pickedFile.path);
        });
      }
    }

    Future<void> _pickImageFromCamera() async {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          imageFile = File(pickedFile.path);
        });
      }
    }

    void _showImagePickerDialog() {
      showModalBottomSheet(
        context: context,
        builder: (context) => Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text("Take a Photo"),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
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
                onTap: _showImagePickerDialog,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: imageFile != null
                      ? Image.file(imageFile!, fit: BoxFit.cover)
                      : const Icon(Icons.camera_alt,
                          size: 40, color: Colors.grey),
                ),
              ),
              TextField(
                  controller: tagController,
                  decoration: InputDecoration(labelText: "Tag Number")),
              TextField(
                  controller: breedController,
                  decoration: InputDecoration(labelText: "Breed")),
              DropdownButtonFormField<String>(
                value: selectedGender,
                decoration: InputDecoration(labelText: "Gender"),
                items: ["Male", "Female"].map((gender) {
                  return DropdownMenuItem(value: gender, child: Text(gender));
                }).toList(),
                onChanged: (value) => setState(() => selectedGender = value),
              ),
              DropdownButtonFormField<String>(
                value: selectedStage,
                decoration: InputDecoration(labelText: "Pig Stage"),
                items: ["Piglet", "Barrow/Stag", "Weaner", "Boar", "Other"]
                    .map((stage) {
                  return DropdownMenuItem(value: stage, child: Text(stage));
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedStage = value);
                },
              ),
              if (selectedStage == "Other")
                TextField(
                  controller: otherStageController,
                  decoration: InputDecoration(labelText: "Enter Custom Stage"),
                ),
              TextField(
                  controller: weightController,
                  decoration: InputDecoration(labelText: "Weight (kg)"),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: dobController,
                  decoration: InputDecoration(labelText: "Date of Birth"),
                  readOnly: true,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now());
                    if (picked != null)
                      dobController.text =
                          picked.toLocal().toString().split(' ')[0];
                  }),
              TextField(
                  controller: doeController,
                  decoration:
                      InputDecoration(labelText: "Date of Entry on Farm"),
                  readOnly: true,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now());
                    if (picked != null)
                      doeController.text =
                          picked.toLocal().toString().split(' ')[0];
                  }),
              DropdownButtonFormField<String>(
                value: selectedSource,
                decoration: InputDecoration(labelText: "Source"),
                items: ["Born on Farm", "Purchased"].map((source) {
                  return DropdownMenuItem(value: source, child: Text(source));
                }).toList(),
                onChanged: (value) => setState(() => selectedSource = value),
              ),
              TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: "Notes (Optional)")),
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
                setState(() {
                  if (index == null) {
                    pigs.add({
                      "image": imageFile,
                      "tag": tagController.text,
                      "breed": breedController.text,
                      "gender": selectedGender,
                      "stage": selectedStage == "Other"
                          ? otherStageController.text
                          : selectedStage,
                      "weight": weightController.text,
                      "dob": dobController.text,
                      "doe": doeController.text,
                      "source": selectedSource,
                      "notes": notesController.text,
                    });
                  } else {
                    pigs[index] = {
                      "image": imageFile,
                      "tag": tagController.text,
                      "breed": breedController.text,
                      "gender": selectedGender,
                      "stage": selectedStage == "Other"
                          ? otherStageController.text
                          : selectedStage,
                      "weight": weightController.text,
                      "dob": dobController.text,
                      "doe": doeController.text,
                      "source": selectedSource,
                      "notes": notesController.text,
                    };
                  }
                });
                Navigator.pop(context);
              }
            },
            child: Text(index == null ? "Add" : "Save"),
          ),
        ],
      ),
    );
  }

  void _deletePig(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Pig"),
        content: const Text("Are you sure you want to delete this pig?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                pigs.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text("${widget.pigpen["name"]} - Pigs"),
          backgroundColor: Colors.green),
      body: pigs.isEmpty
          ? const Center(child: Text("No pigs added yet."))
          : ListView.builder(
              itemCount: pigs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: pigs[index]["image"] != null
                      ? Image.file(pigs[index]["image"],
                          width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.image_not_supported,
                          size: 50, color: Colors.grey),
                  title: Text(
                      "Tag: ${pigs[index]["tag"]} - Breed: ${pigs[index]["breed"]}"),
                  subtitle: Text(
                      "Gender: ${pigs[index]["gender"]} - Stage: ${pigs[index]["stage"]}"),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePig(index)),
                  onTap: () => _showPigDialog(index: index),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => _showPigDialog(),
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }
}
