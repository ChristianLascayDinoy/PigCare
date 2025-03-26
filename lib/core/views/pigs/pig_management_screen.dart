import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../models/pig_model.dart';
import '../../models/pigpen_model.dart';
import 'pig_details_screen.dart';
import '../../widgets/add_edit_pig_dialog.dart';

class PigManagementScreen extends StatefulWidget {
  const PigManagementScreen({super.key, required int pigpenIndex});

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
        _allPigpens.add(newPigpen);
        return newPigpen;
      },
    );

    if (!_pigpenBox.containsKey(unassignedPigpen.key)) {
      _pigpenBox.add(unassignedPigpen);
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
      builder: (context) => AddEditPigDialog(
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
      builder: (context) => AddEditPigDialog(
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

      final targetPigpen = _getTargetPigpen(newPig.pigpenKey);
      targetPigpen.pigs.add(newPig);
      await targetPigpen.save();

      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pig saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving pig: ${e.toString()}')),
        );
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

  Pigpen _getTargetPigpen(int? pigpenKey) {
    return _allPigpens.firstWhere(
      (p) => p.key == pigpenKey,
      orElse: () {
        final newPigpen = Pigpen(name: "Unassigned", description: '', pigs: []);
        _allPigpens.add(newPigpen);
        return newPigpen;
      },
    );
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
            const SnackBar(content: Text('Pig deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting pig: ${e.toString()}')),
          );
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
            builder: (context) => PigDetailsScreen(pig: pig),
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
