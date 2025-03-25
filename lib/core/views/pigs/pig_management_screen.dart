import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../models/pig_model.dart';
import '../../models/pigpen_model.dart';
import 'pig_details_screen.dart';

class PigManagementScreen extends StatefulWidget {
  const PigManagementScreen({super.key, required int pigpenIndex});

  @override
  State<PigManagementScreen> createState() => _PigManagementScreenState();
}

const List<String> pigBreeds = [
  'Large White',
  'Landrace',
  'Duroc',
  'Hampshire',
  'Pietrain',
  'Berkshire',
  'Chester White',
  'Spotted',
  'Poland China',
  'Hereford',
  'Tamworth',
  'Mangalica',
  'Meishan',
  'Other'
];

class _PigManagementScreenState extends State<PigManagementScreen> {
  final ImagePicker _picker = ImagePicker();
  late Box pigpenBox;
  List<Pig> allPigs = [];
  List<Pigpen> allPigpens = [];

  @override
  void initState() {
    super.initState();
    pigpenBox = Hive.box<Pigpen>('pigpens');
    _loadAllData();
  }

  void _loadAllData() {
    setState(() {
      allPigpens = pigpenBox.values.cast<Pigpen>().toList();
      allPigs = allPigpens.expand((pigpen) => pigpen.pigs).toList();
    });
  }

  void _showAddPigDialog() {
    final formKey = GlobalKey<FormState>();
    final controllers = _initializeControllers();
    final dropdownValues = _initializeDropdownValues();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return _buildPigDialog(
              context: context,
              formKey: formKey,
              controllers: controllers,
              dropdownValues: dropdownValues,
              setState: setState,
              isEditing: false,
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _initializeDropdownValues() {
    return {
      'gender': null,
      'stage': null,
      'source': null,
      'pigpen': null,
      'breed': null,
      'motherTag': null,
      'fatherTag': null,
      'imagePath': null,
    };
  }

  Map<String, TextEditingController> _initializeControllers() {
    return {
      'tag': TextEditingController(),
      'name': TextEditingController(),
      'weight': TextEditingController(),
      'dob': TextEditingController(),
      'doe': TextEditingController(),
      'notes': TextEditingController(),
    };
  }

  Widget _buildPigDialog({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required Map<String, TextEditingController> controllers,
    required Map<String, dynamic> dropdownValues,
    required StateSetter setState,
    required bool isEditing,
    Pig? existingPig,
  }) {
    final pigpenNames = ["Unassigned", ...allPigpens.map((p) => p.name)];
    final existingPigTags = allPigs.map((pig) => pig.tag).toList();

    return AlertDialog(
      title: Text(isEditing ? "Edit Pig" : "Add New Pig"),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            children: [
              _buildImagePicker(dropdownValues, setState),
              _buildTagField(controllers['tag']!, existingPigTags, isEditing),
              _buildNameField(controllers['name']!),
              _buildPigpenDropdown(pigpenNames, dropdownValues, setState),
              _buildBreedDropdown(dropdownValues, setState),
              _buildGenderDropdown(dropdownValues, setState),
              _buildStageDropdown(dropdownValues, setState),
              _buildWeightField(controllers['weight']!),
              _buildSourceDropdown(dropdownValues, setState),
              _buildDateField(controllers['dob']!, "Date of Birth *",
                  isRequired: true),
              _buildDateField(controllers['doe']!, "Date of Entry *",
                  isRequired: true),
              _buildParentDropdown(
                "Mother's Tag",
                existingPigTags,
                dropdownValues['motherTag'],
                (value) => setState(() => dropdownValues['motherTag'] = value),
              ),
              _buildParentDropdown(
                "Father's Tag",
                existingPigTags,
                dropdownValues['fatherTag'],
                (value) => setState(() => dropdownValues['fatherTag'] = value),
              ),
              _buildNotesField(controllers['notes']!),
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
          onPressed: () => _savePig(
            context,
            formKey,
            controllers,
            dropdownValues,
            isEditing,
            existingPig,
          ),
          child: const Text("Save"),
        ),
      ],
    );
  }

  Widget _buildImagePicker(
      Map<String, dynamic> dropdownValues, StateSetter setState) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showImageSourceDialog(dropdownValues, setState),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
              image: dropdownValues['imagePath'] != null
                  ? DecorationImage(
                      image: FileImage(File(dropdownValues['imagePath']!)),
                      fit: BoxFit.cover)
                  : null,
            ),
            child: dropdownValues['imagePath'] == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 30, color: Colors.grey),
                      Text("Add Photo", style: TextStyle(fontSize: 12)),
                    ],
                  )
                : null,
          ),
        ),
        if (dropdownValues['imagePath'] != null)
          TextButton(
            onPressed: () => setState(() => dropdownValues['imagePath'] = null),
            child: Text(
              "Remove Photo",
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Future<void> _showImageSourceDialog(
      Map<String, dynamic> dropdownValues, StateSetter setState) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Select Image Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, dropdownValues, setState);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, dropdownValues, setState);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(
    ImageSource source,
    Map<String, dynamic> dropdownValues,
    StateSetter setState,
  ) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => dropdownValues['imagePath'] = pickedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTagField(TextEditingController controller,
      List<String> existingTags, bool isEditing) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: "Tag Number *",
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required field';
        if (!isEditing && existingTags.contains(value)) {
          return 'Tag number must be unique';
        }
        return null;
      },
    );
  }

  Widget _buildNameField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: "Name (Optional)",
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPigpenDropdown(
    List<String> pigpenNames,
    Map<String, dynamic> dropdownValues,
    StateSetter setState,
  ) {
    // Ensure "Unassigned" only appears once
    final uniquePigpenNames = [
      "Unassigned",
      ...allPigpens.map((p) => p.name).where((name) => name != "Unassigned")
    ];

    return DropdownButtonFormField<String>(
      value: dropdownValues['pigpen'] ??
          "Unassigned", // Default to "Unassigned" if null
      decoration: InputDecoration(
        labelText: "Pigpen *",
        border: OutlineInputBorder(),
      ),
      items: uniquePigpenNames.map((name) {
        return DropdownMenuItem<String>(
          value: name,
          child: Text(name),
        );
      }).toList(),
      onChanged: (value) => setState(() => dropdownValues['pigpen'] = value),
      validator: (value) => value == null ? 'Please select a pigpen' : null,
    );
  }

  Widget _buildBreedDropdown(
    Map<String, dynamic> dropdownValues,
    StateSetter setState,
  ) {
    return DropdownButtonFormField<String>(
      value: dropdownValues['breed'],
      decoration: InputDecoration(
        labelText: "Breed *",
        border: OutlineInputBorder(),
      ),
      items: pigBreeds.map((breed) {
        return DropdownMenuItem(
          value: breed,
          child: Text(breed),
        );
      }).toList(),
      onChanged: (value) => setState(() => dropdownValues['breed'] = value),
      validator: (value) => value == null ? 'Please select a breed' : null,
      isExpanded: true,
    );
  }

  Widget _buildGenderDropdown(
    Map<String, dynamic> dropdownValues,
    StateSetter setState,
  ) {
    return DropdownButtonFormField<String>(
      value: dropdownValues['gender'],
      decoration: InputDecoration(
        labelText: "Gender *",
        border: OutlineInputBorder(),
      ),
      items: ['Male', 'Female'].map((gender) {
        return DropdownMenuItem(
          value: gender,
          child: Text(gender),
        );
      }).toList(),
      onChanged: (value) => setState(() => dropdownValues['gender'] = value),
      validator: (value) => value == null ? 'Please select a gender' : null,
    );
  }

  Widget _buildStageDropdown(
    Map<String, dynamic> dropdownValues,
    StateSetter setState,
  ) {
    return DropdownButtonFormField<String>(
      value: dropdownValues['stage'],
      decoration: InputDecoration(
        labelText: "Pig Stage *",
        border: OutlineInputBorder(),
      ),
      items: ['Piglet', 'Weaner', 'Grower', 'Finisher', 'Sow', 'Boar']
          .map((stage) {
        return DropdownMenuItem(
          value: stage,
          child: Text(stage),
        );
      }).toList(),
      onChanged: (value) => setState(() => dropdownValues['stage'] = value),
      validator: (value) => value == null ? 'Please select a stage' : null,
    );
  }

  Widget _buildWeightField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: "Weight (kg) *",
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required field';
        if (double.tryParse(value) == null) return 'Enter a valid number';
        return null;
      },
    );
  }

  Widget _buildSourceDropdown(
    Map<String, dynamic> dropdownValues,
    StateSetter setState,
  ) {
    return DropdownButtonFormField<String>(
      value: dropdownValues['source'],
      decoration: InputDecoration(
        labelText: "Source *",
        border: OutlineInputBorder(),
      ),
      items: ['Purchased', 'Born on Farm', 'Other'].map((source) {
        return DropdownMenuItem(
          value: source,
          child: Text(source),
        );
      }).toList(),
      onChanged: (value) => setState(() => dropdownValues['source'] = value),
      validator: (value) => value == null ? 'Please select a source' : null,
    );
  }

  Widget _buildDateField(TextEditingController controller, String label,
      {bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.calendar_today),
      ),
      readOnly: true,
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          controller.text = picked.toLocal().toString().split(' ')[0];
        }
      },
      validator: isRequired
          ? (value) =>
              value == null || value.isEmpty ? 'This field is required' : null
          : null,
    );
  }

  Widget _buildParentDropdown(
    String label,
    List<String> existingTags,
    String? currentValue,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      items: ['None', ...existingTags].map((tag) {
        return DropdownMenuItem(
          value: tag == 'None' ? null : tag,
          child: Text(tag),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildNotesField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: "Notes (Optional)",
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  void _savePig(
    BuildContext context,
    GlobalKey<FormState> formKey,
    Map<String, TextEditingController> controllers,
    Map<String, dynamic> dropdownValues,
    bool isEditing,
    Pig? existingPig,
  ) async {
    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 1. Create a NEW Pig instance (never reuse existing objects)
      final newPig = Pig(
        tag: controllers['tag']!.text,
        name: controllers['name']!.text.isNotEmpty
            ? controllers['name']!.text
            : null,
        breed: dropdownValues['breed']!,
        gender: dropdownValues['gender']!,
        stage: dropdownValues['stage']!,
        weight: double.tryParse(controllers['weight']!.text) ?? 0.0,
        dob: controllers['dob']!.text,
        doe: controllers['doe']!.text,
        source: dropdownValues['source']!,
        pigpen: dropdownValues['pigpen']!,
        motherTag: dropdownValues['motherTag'],
        fatherTag: dropdownValues['fatherTag'],
        notes: controllers['notes']!.text,
        imagePath: dropdownValues['imagePath'],
      );

      // 2. Get the target pigpen (handle "Unassigned" case)
      final pigpenName = dropdownValues['pigpen'] == "Unassigned"
          ? null
          : dropdownValues['pigpen'];
      var targetPigpen = allPigpens.firstWhere(
        (p) => p.name == pigpenName,
        orElse: () => Pigpen(name: "Unassigned", description: '', pigs: []),
      );

      // 3. Handle editing vs adding new
      if (isEditing && existingPig != null) {
        // Remove from old pigpen if it exists
        for (var pigpen in allPigpens) {
          if (pigpen.pigs.any((p) => p.tag == existingPig.tag)) {
            pigpen.pigs.removeWhere((p) => p.tag == existingPig.tag);
            await pigpen.save(); // Save the modified pigpen
            break;
          }
        }
      }

      // 4. Add to target pigpen
      targetPigpen.pigs.add(newPig);

      // 5. Save changes
      if (!allPigpens.contains(targetPigpen)) {
        // If it's a new "Unassigned" pigpen, add it to the list
        allPigpens.add(targetPigpen);
        await pigpenBox.add(targetPigpen); // Add new pigpen to Hive
      } else {
        await targetPigpen.save(); // Update existing pigpen
      }

      // 6. Update UI
      _loadAllData();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving pig: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pig Management"),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddPigDialog,
          ),
        ],
      ),
      body: allPigs.isEmpty
          ? const Center(
              child: Text(
                "No pigs found\nAdd your first pig!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: allPigs.length,
              itemBuilder: (context, index) {
                final pig = allPigs[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: pig.imagePath != null
                        ? CircleAvatar(
                            backgroundImage: FileImage(File(pig.imagePath!)),
                            radius: 25,
                          )
                        : CircleAvatar(
                            child: Icon(Icons.pets),
                            radius: 25,
                          ),
                    title: Text("Tag: ${pig.tag}"),
                    subtitle: Text("${pig.breed} • ${pig.gender}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditPigDialog(pig),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deletePig(pig),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PigDetailsScreen(pig: pig),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showEditPigDialog(Pig pig) {
    final formKey = GlobalKey<FormState>();
    final controllers = _initializeControllers();
    final dropdownValues = _initializeDropdownValues();

    controllers['tag']!.text = pig.tag;
    controllers['name']!.text = pig.name ?? "";
    controllers['weight']!.text = pig.weight.toString();
    controllers['dob']!.text = pig.dob;
    controllers['doe']!.text = pig.doe;
    controllers['notes']!.text = pig.notes ?? "";

    dropdownValues.addAll({
      'gender': pig.gender,
      'stage': pig.stage,
      'source': pig.source,
      'pigpen': pig.pigpen ?? "Unassigned",
      'breed': pig.breed,
      'motherTag': pig.motherTag,
      'fatherTag': pig.fatherTag,
      'imagePath': pig.imagePath,
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return _buildPigDialog(
              context: context,
              formKey: formKey,
              controllers: controllers,
              dropdownValues: dropdownValues,
              setState: setState,
              isEditing: true,
              existingPig: pig,
            );
          },
        );
      },
    );
  }

  void _deletePig(Pig pig) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this pig?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              try {
                // 1. Find the pigpen containing this pig
                final pigpen = allPigpens.firstWhere(
                  (p) => p.pigs.any((p) => p.tag == pig.tag),
                  orElse: () => Pigpen(name: '', description: ''),
                );

                if (pigpen.name.isNotEmpty) {
                  // 2. Remove the pig from the pigpen
                  pigpen.pigs.removeWhere((p) => p.tag == pig.tag);

                  // 3. Save the updated pigpen back to Hive
                  await pigpen.saveChanges();

                  // 4. Update the UI
                  if (mounted) {
                    Navigator.pop(context);
                    _loadAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Pig deleted successfully"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Pig not found in any pigpen"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error deleting pig: ${e.toString()}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
