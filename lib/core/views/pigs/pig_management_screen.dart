import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../models/pig_model.dart';
import '../../models/pigpen_model.dart';
import 'pig_details_screen.dart';

class PigManagementScreen extends StatefulWidget {
  final int pigpenIndex;
  final Pig? existingPig;
  final List<Pigpen>? pigpens;

  const PigManagementScreen({
    super.key,
    required this.pigpenIndex,
    this.existingPig,
    this.pigpens,
    required List allPigs,
    required Pig pig,
  });

  @override
  State<PigManagementScreen> createState() => _PigManagementScreenState();
}

class _PigManagementScreenState extends State<PigManagementScreen> {
  late Box<Pigpen> _pigpenBox;
  List<Pig> _allPigs = [];
  List<Pigpen> _allPigpens = [];
  final ImagePicker _imagePicker = ImagePicker();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _pigpenBox = Hive.box<Pigpen>('pigpens');
    _loadAllData();

    // If existingPig was passed, initialize edit mode
    if (widget.existingPig != null) {
      _showEditPigDialog(widget.existingPig!);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _allPigpens = _pigpenBox.values.toList();
      _ensureUnassignedPigpenExists();
      _allPigs = _allPigpens.expand((pigpen) => pigpen.pigs).toList();
    });
  }

  void _ensureUnassignedPigpenExists() {
    final unassignedPigpen = _allPigpens.firstWhere(
      (p) => p.name == "Unassigned",
      orElse: () {
        final newPigpen = Pigpen(name: "Unassigned", description: '', pigs: []);
        _pigpenBox.add(newPigpen); // Add to Hive immediately
        return newPigpen;
      },
    );

    // Ensure it's in the local list
    if (!_allPigpens.contains(unassignedPigpen)) {
      _allPigpens.add(unassignedPigpen);
    }
  }

  List<Pig> get _filteredPigs {
    if (_searchQuery.isEmpty) return _allPigs;
    return _allPigs.where((pig) {
      return pig.tag.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (pig.name?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          pig.breed.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _showAddPigDialog() async {
    final result = await showDialog<Pig?>(
      context: context,
      builder: (context) => _AddEditPigDialog(
        allPigs: _allPigs,
        allPigpens: _allPigpens,
        imagePicker: _imagePicker,
      ),
    );

    if (result != null) {
      await _savePig(result);
    }
  }

  Future<void> _showEditPigDialog(Pig pig) async {
    final result = await showDialog<Pig?>(
      context: context,
      builder: (context) => _AddEditPigDialog(
        allPigs: _allPigs,
        allPigpens: _allPigpens,
        imagePicker: _imagePicker,
        existingPig: pig,
      ),
    );

    if (result != null) {
      await _savePig(result, existingPig: pig);
    }
  }

  Future<void> _savePig(Pig newPig, {Pig? existingPig}) async {
    try {
      if (existingPig != null) {
        await _removePigFromPigpen(existingPig);
      }

      Pigpen targetPigpen;
      if (newPig.pigpenKey == null) {
        // Handle unassigned case explicitly
        targetPigpen = _allPigpens.firstWhere(
          (p) => p.name == "Unassigned",
          orElse: () {
            final newPigpen =
                Pigpen(name: "Unassigned", description: '', pigs: []);
            _pigpenBox.add(newPigpen);
            return newPigpen;
          },
        );
      } else {
        targetPigpen = _allPigpens.firstWhere(
          (p) => p.key == newPig.pigpenKey,
          orElse: () => _allPigpens.firstWhere(
            (p) => p.name == "Unassigned",
            orElse: () {
              final newPigpen =
                  Pigpen(name: "Unassigned", description: '', pigs: []);
              _pigpenBox.add(newPigpen);
              return newPigpen;
            },
          ),
        );
      }

      targetPigpen.pigs.add(newPig);
      await targetPigpen.save();

      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pig saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving pig: ${e.toString()}')));
      }
    }
  }

  Future<void> _removePigFromPigpen(Pig pig) async {
    for (final pigpen in _allPigpens) {
      if (pigpen.pigs.any((p) => p.tag == pig.tag)) {
        pigpen.pigs.removeWhere((p) => p.tag == pig.tag);
        await pigpen.save();
        break;
      }
    }
  }

  Future<void> _deletePig(Pig pig) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this pig?"),
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
        await _removePigFromPigpen(pig);
        _loadAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pig deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting pig: ${e.toString()}')));
        }
      }
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
            tooltip: 'Add new pig',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search pigs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _buildPigList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPigList() {
    if (_filteredPigs.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? "No pigs found\nAdd your first pig!"
              : "No pigs match your search",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredPigs.length,
      itemBuilder: (context, index) {
        final pig = _filteredPigs[index];
        return _buildPigCard(pig);
      },
    );
  }

  Widget _buildPigCard(Pig pig) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PigDetailsScreen(
              pig: pig,
              pigpens: _allPigpens,
              onPigUpdated: (updatedPig) {
                _savePig(updatedPig);
              },
              onPigDeleted: (pigToDelete) {
                _deletePig(pigToDelete);
              },
              allPigs: [],
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              _buildPigAvatar(pig),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pig.name ?? "Tag: ${pig.tag}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${pig.breed} • ${pig.gender} • ${pig.getFormattedAge()}",
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (pig.pigpenKey != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Pen: ${pig.getPigpenName(_allPigpens)}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      "${pig.weight} kg",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildPigActions(pig),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPigAvatar(Pig pig) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: Colors.grey[200],
      backgroundImage:
          pig.imagePath != null ? FileImage(File(pig.imagePath!)) : null,
      child: pig.imagePath == null ? const Icon(Icons.pets, size: 30) : null,
    );
  }

  Widget _buildPigActions(Pig pig) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _showEditPigDialog(pig),
          tooltip: 'Edit pig',
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deletePig(pig),
          tooltip: 'Delete pig',
        ),
      ],
    );
  }
}

class _AddEditPigDialog extends StatefulWidget {
  final List<Pig> allPigs;
  final List<Pigpen> allPigpens;
  final ImagePicker imagePicker;
  final Pig? existingPig;

  const _AddEditPigDialog({
    required this.allPigs,
    required this.allPigpens,
    required this.imagePicker,
    this.existingPig,
  });

  @override
  State<_AddEditPigDialog> createState() => __AddEditPigDialogState();
}

class __AddEditPigDialogState extends State<_AddEditPigDialog> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controllers['tag'],
          decoration: const InputDecoration(
            labelText: "Tag Number *",
            border: OutlineInputBorder(),
          ),
          readOnly: widget.existingPig != null,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Required field';
            if (widget.existingPig == null &&
                widget.allPigs.any((pig) => pig.tag == value)) {
              return 'Tag number must be unique';
            }
            return null;
          },
        ),
        if (widget.existingPig != null)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              'Tag number is permanent and cannot be changed',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
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
