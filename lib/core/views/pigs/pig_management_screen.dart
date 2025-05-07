import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

      // Only check capacity if we're adding a new pig (not editing)
      if (existingPig == null && targetPigpen.isFull) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${targetPigpen.name} is already full'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      targetPigpen.pigs.add(newPig);
      await targetPigpen.save();

      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pig saved successfully'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving pig: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pig deleted successfully'),
            backgroundColor: Colors.red,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error deleting pig: ${e.toString()}'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize:
              MainAxisSize.min, // <-- this helps center the Row contents
          children: [
            ClipOval(
              child: Image.asset(
                'lib/assets/images/pig.png',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Pig Management",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.green[700],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPigDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Pig'),
        backgroundColor: Colors.green[700],
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
              allPigs: _allPigs,
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
                      "Tag: ${pig.tag}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${pig.gender} • ${pig.stage} • ${pig.getFormattedAge()}",
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
                      "${pig.weight} kg (est. ${pig.estimatedWeight.toStringAsFixed(1)} kg)",
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      "${pig.stage} (est. ${pig.estimatedStage})",
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
      child: pig.imagePath == null
          ? Image.asset(
              'lib/assets/images/pig.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            )
          : null,
    );
  }

  Widget _buildPigActions(Pig pig) {
    return PopupMenuButton<String>(
      onSelected: (String value) {
        switch (value) {
          case 'view':
            // Navigate to PigDetailsScreen when "View Details" is selected
            Navigator.push(
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
                  allPigs: _allPigs,
                ),
              ),
            );
            break;
          case 'edit':
            _showEditPigDialog(pig);
            break;
          case 'delete':
            _deletePig(pig);
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            value: 'view',
            child: Row(
              children: const [
                Icon(Icons.visibility, color: Colors.blue),
                SizedBox(width: 8),
                Text('View Details'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: const [
                Icon(Icons.edit, color: Colors.blue),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: const [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        ];
      },
      icon: const Icon(Icons.more_vert, color: Colors.black),
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

  List<String> _getStagesForGender(String? gender) {
    if (gender == 'Male') {
      return ['Piglet', 'Weaner', 'Grower', 'Finisher', 'Boar'];
    } else if (gender == 'Female') {
      return ['Piglet', 'Weaner', 'Grower', 'Finisher', 'Sow'];
    }
    return []; // Default empty list if no gender is selected
  }

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
      'gender': widget.existingPig?.gender,
      'stage': widget.existingPig?.stage,
      'source': widget.existingPig?.source,
      'pigpenKey': null,
      'breed': widget.existingPig?.breed,
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
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'lib/assets/images/pig.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                      const Text("Add Photo", style: TextStyle(fontSize: 12)),
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
          keyboardType: TextInputType.text, // Allow letters and numbers
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-Z0-9]')), // Allows letters and digits
            LengthLimitingTextInputFormatter(
                10), // Limit to 10 characters (optional)
          ],
          decoration: const InputDecoration(
            labelText: "Tag Number *",
            border: OutlineInputBorder(),
            hintText: "Enter tag (letters and numbers allowed)",
          ),
          readOnly: widget.existingPig != null,
          validator: (value) {
            final trimmedValue = value?.trim() ?? '';
            if (trimmedValue.isEmpty) return 'Required field';
            if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmedValue)) {
              return 'Only letters and numbers are allowed';
            }

            // Check against all existing tags (trimmed)
            if (widget.existingPig == null) {
              final isDuplicate = widget.allPigs.any((pig) =>
                  pig.tag.trim().toLowerCase() == trimmedValue.toLowerCase());
              if (isDuplicate) return 'Tag number must be unique';
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
      value: _dropdownValues['pigpenKey'], // This will be null initially
      decoration: const InputDecoration(
        labelText: "Pigpen",
        border: OutlineInputBorder(),
        hintText: "Select a pigpen", // Add a hint text
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child:
              Text("Select a pigpen...", style: TextStyle(color: Colors.grey)),
        ),
        ...widget.allPigpens
            .where((p) => p.name != "Unassigned")
            .map<DropdownMenuItem<int?>>((pigpen) {
          // Only disable if it's not the current pigpen
          final isCurrentPigpen = pigpen.key == _dropdownValues['pigpenKey'];
          return DropdownMenuItem<int?>(
            value: pigpen.key,
            enabled: !pigpen.isFull || isCurrentPigpen,
            child: Text(
              pigpen.isFull && !isCurrentPigpen
                  ? '${pigpen.name} (FULL)'
                  : '${pigpen.name} (${pigpen.pigs.length}/${pigpen.capacity})',
              style: TextStyle(
                color: pigpen.isFull && !isCurrentPigpen ? Colors.grey : null,
              ),
            ),
          );
        }).toList(),
      ],
      onChanged: (value) => setState(() {
        _dropdownValues['pigpenKey'] = value;
      }),
      validator: (value) {
        if (value != null) {
          final selectedPen =
              widget.allPigpens.firstWhere((p) => p.key == value);
          // Only validate if changing to a new pigpen
          if (selectedPen.key != widget.existingPig?.pigpenKey &&
              selectedPen.isFull) {
            return 'This pigpen is already full';
          }
        }
        return null;
      },
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
      onChanged: (value) {
        setState(() {
          _dropdownValues['gender'] = value;
          // Reset stage when gender changes
          _dropdownValues['stage'] = null;
        });
      },
      validator: (value) => value == null ? 'Please select a gender' : null,
    );
  }

  Widget _buildStageDropdown() {
    final availableStages = _getStagesForGender(_dropdownValues['gender']);

    return DropdownButtonFormField<String>(
      value: _dropdownValues['stage'],
      decoration: const InputDecoration(
        labelText: "Pig Stage *",
        border: OutlineInputBorder(),
      ),
      items: availableStages.map((stage) {
        return DropdownMenuItem(
          value: stage,
          child: Text(stage),
        );
      }).toList(),
      onChanged: (value) => setState(() => _dropdownValues['stage'] = value),
      validator: (value) {
        if (value == null) return 'Please select a stage';
        if (!availableStages.contains(value))
          return 'Invalid stage for selected gender';
        return null;
      },
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

    // Find the selected pig to display its details
    final selectedPig = currentValue != null
        ? availablePigs.firstWhereOrNull((pig) => pig.tag == currentValue)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showParentSelectionDialog(label, requiredGender),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: selectedPig == null
                      ? Text('None selected',
                          style: TextStyle(color: Colors.grey))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${selectedPig.tag} ${selectedPig.genderSymbol}'),
                            if (selectedPig.name != null)
                              Text(selectedPig.name!),
                            Text(
                              '${selectedPig.breed} • ${selectedPig.getFormattedAge()}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showParentSelectionDialog(
      String label, String requiredGender) async {
    final currentPigTag = widget.existingPig?.tag;
    final availablePigs = widget.allPigs.where((pig) {
      return pig.gender == requiredGender &&
          pig.tag != currentPigTag &&
          pig.isSexuallyMature;
    }).toList();

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $label'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availablePigs.length,
            itemBuilder: (context, index) {
              final pig = availablePigs[index];
              return ListTile(
                title: Text('${pig.tag} ${pig.genderSymbol}'),
                subtitle: Text('${pig.breed} • ${pig.getFormattedAge()}'),
                onTap: () => Navigator.pop(context, pig.tag),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    setState(() {
      if (label.contains("Mother")) {
        _dropdownValues['motherTag'] = selected;
      } else {
        _dropdownValues['fatherTag'] = selected;
      }
    });
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
      tag: _controllers['tag']!.text.trim(),
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
      final mother = widget.allPigs.firstWhere(
        (p) => p.tag == _dropdownValues['motherTag'],
      );
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

    if (_dropdownValues['motherTag'] != null) {
      final mother = widget.allPigs.firstWhere(
        (p) => p.tag == _dropdownValues['motherTag'],
      );
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

    Navigator.pop(context, newPig);
  }
}
