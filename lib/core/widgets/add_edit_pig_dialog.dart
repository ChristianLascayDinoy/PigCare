import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../models/pig_model.dart';
import '../models/pigpen_model.dart';

class AddEditPigDialog extends StatefulWidget {
  final List<Pig> allPigs;
  final List<Pigpen> allPigpens;
  final ImagePicker imagePicker;
  final Pig? existingPig;

  const AddEditPigDialog({
    super.key,
    required this.allPigs,
    required this.allPigpens,
    required this.imagePicker,
    this.existingPig,
  });

  @override
  State<AddEditPigDialog> createState() => _AddEditPigDialogState();
}

class _AddEditPigDialogState extends State<AddEditPigDialog> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  late Map<String, dynamic> _dropdownValues;
  final List<String> _pigBreeds = [
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

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _initializeFormData() {
    _controllers = {
      'tag': TextEditingController(text: widget.existingPig?.tag ?? ''),
      'name': TextEditingController(text: widget.existingPig?.name ?? ''),
      'weight': TextEditingController(
          text: widget.existingPig?.weight.toString() ?? ''),
      'dob': TextEditingController(text: widget.existingPig?.dob ?? ''),
      'doe': TextEditingController(text: widget.existingPig?.doe ?? ''),
      'notes': TextEditingController(text: widget.existingPig?.notes ?? ''),
    };

    _dropdownValues = {
      'gender': widget.existingPig?.gender ?? 'Female',
      'stage': widget.existingPig?.stage ?? 'Piglet',
      'source': widget.existingPig?.source ?? 'Born on Farm',
      'pigpenKey': widget.existingPig?.pigpenKey,
      'breed': widget.existingPig?.breed ?? _pigBreeds.first,
      'motherTag': widget.existingPig?.motherTag,
      'fatherTag': widget.existingPig?.fatherTag,
      'imagePath': widget.existingPig?.imagePath,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingPig != null ? "Edit Pig" : "Add New Pig"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImagePicker(),
              const SizedBox(height: 16),
              _buildTagField(),
              const SizedBox(height: 12),
              _buildNameField(),
              const SizedBox(height: 12),
              _buildPigpenDropdown(),
              const SizedBox(height: 12),
              _buildBreedDropdown(),
              const SizedBox(height: 12),
              _buildGenderDropdown(),
              const SizedBox(height: 12),
              _buildStageDropdown(),
              const SizedBox(height: 12),
              _buildWeightField(),
              const SizedBox(height: 12),
              _buildSourceDropdown(),
              const SizedBox(height: 12),
              _buildDateField(
                controller: _controllers['dob']!,
                label: "Date of Birth *",
                isRequired: true,
              ),
              const SizedBox(height: 12),
              _buildDateField(
                controller: _controllers['doe']!,
                label: "Date of Entry *",
                isRequired: true,
              ),
              const SizedBox(height: 12),
              _buildParentDropdown(
                label: "Mother's Tag",
                currentValue: _dropdownValues['motherTag'],
                requiredGender: 'Female',
              ),
              const SizedBox(height: 12),
              _buildParentDropdown(
                label: "Father's Tag",
                currentValue: _dropdownValues['fatherTag'],
                requiredGender: 'Male',
              ),
              const SizedBox(height: 12),
              _buildNotesField(),
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
          onPressed: _validateAndSave,
          child: const Text("Save"),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
              image: _dropdownValues['imagePath'] != null
                  ? DecorationImage(
                      image: FileImage(File(_dropdownValues['imagePath']!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _dropdownValues['imagePath'] == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 30, color: Colors.grey),
                      Text("Add Photo", style: TextStyle(fontSize: 12)),
                    ],
                  )
                : null,
          ),
        ),
        if (_dropdownValues['imagePath'] != null)
          TextButton(
            onPressed: () =>
                setState(() => _dropdownValues['imagePath'] = null),
            child: const Text(
              "Remove Photo",
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Future<void> _showImageSourceDialog() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Image Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await widget.imagePicker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        setState(() => _dropdownValues['imagePath'] = pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTagField() {
    final existingTags = widget.allPigs.map((pig) => pig.tag).toList();
    if (widget.existingPig != null) {
      existingTags.remove(widget.existingPig!.tag);
    }

    return TextFormField(
      controller: _controllers['tag'],
      decoration: const InputDecoration(
        labelText: "Tag Number *",
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required field';
        if (existingTags.contains(value)) {
          return 'Tag number must be unique';
        }
        return null;
      },
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _controllers['name'],
      decoration: const InputDecoration(
        labelText: "Name (Optional)",
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPigpenDropdown() {
    return DropdownButtonFormField<int?>(
      value: _dropdownValues['pigpenKey'],
      decoration: const InputDecoration(
        labelText: "Pigpen",
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text("Unassigned"),
        ),
        ...widget.allPigpens
            .where((p) => p.name != "Unassigned")
            .map<DropdownMenuItem<int?>>((pigpen) {
          return DropdownMenuItem<int?>(
            value: pigpen.key,
            child: Text(pigpen.name),
          );
        }).toList(),
      ],
      onChanged: (value) => setState(() {
        _dropdownValues['pigpenKey'] = value;
      }),
    );
  }

  Widget _buildBreedDropdown() {
    return DropdownButtonFormField<String>(
      value: _dropdownValues['breed'],
      decoration: const InputDecoration(
        labelText: "Breed *",
        border: OutlineInputBorder(),
      ),
      items: _pigBreeds.map((breed) {
        return DropdownMenuItem(
          value: breed,
          child: Text(breed),
        );
      }).toList(),
      onChanged: (value) => setState(() => _dropdownValues['breed'] = value),
      validator: (value) => value == null ? 'Please select a breed' : null,
      isExpanded: true,
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _dropdownValues['gender'],
      decoration: const InputDecoration(
        labelText: "Gender *",
        border: OutlineInputBorder(),
      ),
      items: ['Male', 'Female'].map((gender) {
        return DropdownMenuItem(
          value: gender,
          child: Text(gender),
        );
      }).toList(),
      onChanged: (value) => setState(() => _dropdownValues['gender'] = value),
      validator: (value) => value == null ? 'Please select a gender' : null,
    );
  }

  Widget _buildStageDropdown() {
    return DropdownButtonFormField<String>(
      value: _dropdownValues['stage'],
      decoration: const InputDecoration(
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
      onChanged: (value) => setState(() => _dropdownValues['stage'] = value),
      validator: (value) => value == null ? 'Please select a stage' : null,
    );
  }

  Widget _buildWeightField() {
    return TextFormField(
      controller: _controllers['weight'],
      decoration: const InputDecoration(
        labelText: "Weight (kg) *",
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required field';
        if (double.tryParse(value) == null) return 'Enter a valid number';
        if (double.parse(value) <= 0) return 'Weight must be positive';
        return null;
      },
    );
  }

  Widget _buildSourceDropdown() {
    return DropdownButtonFormField<String>(
      value: _dropdownValues['source'],
      decoration: const InputDecoration(
        labelText: "Source *",
        border: OutlineInputBorder(),
      ),
      items: ['Purchased', 'Born on Farm', 'Other'].map((source) {
        return DropdownMenuItem(
          value: source,
          child: Text(source),
        );
      }).toList(),
      onChanged: (value) => setState(() => _dropdownValues['source'] = value),
      validator: (value) => value == null ? 'Please select a source' : null,
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      readOnly: true,
      onTap: () async {
        final picked = await showDatePicker(
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

  Widget _buildParentDropdown({
    required String label,
    required String? currentValue,
    required String requiredGender,
  }) {
    final currentPigTag = widget.existingPig?.tag;
    final availablePigs = widget.allPigs.where((pig) {
      return pig.gender == requiredGender &&
          pig.tag != currentPigTag &&
          pig.isSexuallyMature;
    }).toList();

    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('None'),
        ),
        ...availablePigs.map((pig) {
          return DropdownMenuItem(
            value: pig.tag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${pig.tag} ${pig.genderSymbol}'),
                Text(
                  '${pig.name ?? 'No name'} • ${pig.getFormattedAge()}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        }),
      ],
      onChanged: (value) => setState(() {
        if (label.contains("Mother")) {
          _dropdownValues['motherTag'] = value;
        } else {
          _dropdownValues['fatherTag'] = value;
        }
      }),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _controllers['notes'],
      decoration: const InputDecoration(
        labelText: "Notes (Optional)",
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  Future<void> _validateAndSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dropdownValues['motherTag'] == _controllers['tag']!.text ||
        _dropdownValues['fatherTag'] == _controllers['tag']!.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A pig cannot be its own parent'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newPig = Pig(
      tag: _controllers['tag']!.text,
      name: _controllers['name']!.text.isNotEmpty
          ? _controllers['name']!.text
          : null,
      breed: _dropdownValues['breed']!,
      gender: _dropdownValues['gender']!,
      stage: _dropdownValues['stage']!,
      weight: double.parse(_controllers['weight']!.text),
      dob: _controllers['dob']!.text,
      doe: _controllers['doe']!.text,
      source: _dropdownValues['source']!,
      pigpenKey: _dropdownValues['pigpenKey'],
      motherTag: _dropdownValues['motherTag'],
      fatherTag: _dropdownValues['fatherTag'],
      notes: _controllers['notes']!.text.isNotEmpty
          ? _controllers['notes']!.text
          : null,
      imagePath: _dropdownValues['imagePath'],
    );

    if (_dropdownValues['motherTag'] != null) {
      final mother = widget.allPigs
          .firstWhere((p) => p.tag == _dropdownValues['motherTag']);
      if (!mother.canBeParentOf(newPig)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mother must be older than the pig being registered'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_dropdownValues['fatherTag'] != null) {
      final father = widget.allPigs
          .firstWhere((p) => p.tag == _dropdownValues['fatherTag']);
      if (!father.canBeParentOf(newPig)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Father must be older than the pig being registered'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    Navigator.pop(context, newPig);
  }
}
