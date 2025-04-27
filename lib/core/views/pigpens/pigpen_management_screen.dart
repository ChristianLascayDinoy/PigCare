import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/models/pigpen_model.dart';
import 'package:pigcare/core/views/pigpens/pigpen_pigs_list_screen.dart';

class PigpenManagementScreen extends StatefulWidget {
  const PigpenManagementScreen({super.key});

  @override
  State<PigpenManagementScreen> createState() => _PigpenManagementScreenState();
}

class _PigpenManagementScreenState extends State<PigpenManagementScreen> {
  late final Box<Pigpen> _pigpenBox;
  final Set<String> _existingNames = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _pigpenBox = Hive.box<Pigpen>('pigpens');
    _loadExistingNames();
  }

  void _loadExistingNames() {
    _existingNames.clear();
    _existingNames
        .addAll(_pigpenBox.values.map((p) => p.name.trim().toLowerCase()));
  }

  bool _isNameDuplicate(String name, {Pigpen? excludePigpen}) {
    final normalizedName = name.trim().toLowerCase();

    if (excludePigpen != null) {
      return _existingNames.any((existingName) =>
          existingName.trim().toLowerCase() == normalizedName &&
          existingName.toLowerCase() !=
              excludePigpen.name.trim().toLowerCase());
    }

    return _existingNames.any(
        (existingName) => existingName.trim().toLowerCase() == normalizedName);
  }

  Future<void> _showAddEditDialog({Pigpen? pigpen}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: pigpen?.name ?? '');
    final descriptionController =
        TextEditingController(text: pigpen?.description ?? '');
    final capacityController =
        TextEditingController(text: pigpen?.capacity.toString() ?? '0');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(pigpen == null ? "Add New Pigpen" : "Edit Pigpen"),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Pigpen Name *",
                    border: OutlineInputBorder(),
                    hintText: "Enter unique name",
                  ),
                  validator: (value) {
                    final trimmedValue = value?.trim() ?? '';
                    if (trimmedValue.isEmpty) return 'Please enter a name';
                    if (trimmedValue.replaceAll(' ', '').isEmpty)
                      return 'Name cannot be just spaces';
                    if (trimmedValue.toLowerCase() == "unassigned")
                      return '"Unassigned" is a reserved name';
                    if (_isNameDuplicate(trimmedValue, excludePigpen: pigpen)) {
                      return 'Pigpen name already exists';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: capacityController,
                  decoration: const InputDecoration(
                    labelText: "Capacity (0 for unlimited)",
                    border: OutlineInputBorder(),
                    hintText: "Enter maximum number of pigs",
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter a number';
                    final num = int.tryParse(value);
                    if (num == null) return 'Please enter a valid number';
                    if (num < 0) return 'Capacity cannot be negative';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _savePigpen(
                  pigpen: pigpen,
                  name: nameController.text,
                  capacity: capacityController.text,
                  description: descriptionController.text,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _savePigpen({
    required String name,
    required String description,
    required String capacity,
    Pigpen? pigpen,
  }) async {
    try {
      final capacityValue = int.tryParse(capacity) ?? 0;

      if (pigpen == null) {
        final newPigpen = Pigpen(
          name: name,
          description: description,
          capacity: capacityValue,
        );
        await _pigpenBox.add(newPigpen);
      } else {
        final updated = pigpen.copyWith(
          name: name,
          description: description,
          capacity: capacityValue,
        );
        await _pigpenBox.put(pigpen.key, updated);
      }

      _loadExistingNames();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pigpen == null
                ? "Pigpen added successfully"
                : "Pigpen updated successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving pigpen: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error saving pigpen: $e');
    }
  }

  Future<void> _confirmDelete(Pigpen pigpen) async {
    if (pigpen.name == "Unassigned") {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cannot delete the Unassigned pigpen"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Are you sure you want to delete this pigpen?"),
            if (pigpen.pigs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "WARNING: All ${pigpen.pigs.length} pigs in this pen will be permanently deleted!",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete Anyway",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deletePigpen(pigpen);
    }
  }

  Future<void> _deletePigpen(Pigpen pigpen) async {
    try {
      // First get a copy of the pigs list since we'll be modifying it
      final pigsToDelete = List<Pig>.from(pigpen.pigs);

      // Clear the pigpen's pigs list first to avoid reference issues
      pigpen.pigs.clear();
      await pigpen.save(); // Save the empty pigpen first

      // Now delete each pig from Hive
      final pigBox = Hive.box<Pig>('pigs'); // Make sure you have this box open
      for (final pig in pigsToDelete) {
        await pigBox.delete(pig.key); // Delete using the Hive box
      }

      // Finally delete the pigpen itself
      await pigpen.delete();
      _loadExistingNames();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Pigpen and ${pigsToDelete.length} pigs deleted successfully"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting pigpen: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error details: $e');
    }
  }

  List<Pigpen> _filterPigpens(List<Pigpen> pigpens) {
    if (_searchQuery.isEmpty) return pigpens;
    return pigpens.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
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
                  'lib/assets/images/pigpen.png',
                  height: 40,
                  width: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Pigpen Management",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.green[700],
          actions: [
            TextButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Pigpen',
                style: TextStyle(color: Colors.white),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search pigpens...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Box<Pigpen>>(
              valueListenable: _pigpenBox.listenable(),
              builder: (context, box, _) {
                final pigpens = box.values.toList().cast<Pigpen>();
                final filteredPigpens = _filterPigpens(pigpens);

                if (filteredPigpens.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? "No pigpens available\nAdd your first pigpen!"
                          : "No pigpens match your search",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: filteredPigpens.length,
                    itemBuilder: (context, index) {
                      final pigpen = filteredPigpens[index];
                      return _PigpenCard(
                        pigpen: pigpen,
                        onEdit: () => _showAddEditDialog(pigpen: pigpen),
                        onDelete: () => _confirmDelete(pigpen),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PigpenCard extends StatelessWidget {
  final Pigpen pigpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PigpenCard({
    required this.pigpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUnassigned = pigpen.name == "Unassigned";
    final capacityText = pigpen.capacity == 0
        ? '${pigpen.pigs.length}'
        : '${pigpen.pigs.length}/${pigpen.capacity}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PigpenPigsListScreen(pigpen: pigpen),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pigpen.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isUnassigned ? Colors.grey : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // In your _PigpenCard widget
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          pigpen.isFull ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pigpen.capacity == 0
                          ? '${pigpen.pigs.length}'
                          : '${pigpen.pigs.length}/${pigpen.capacity}',
                      style: TextStyle(
                        color:
                            pigpen.isFull ? Colors.red[800] : Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  pigpen.description.isEmpty
                      ? "No description"
                      : pigpen.description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isUnassigned)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'view') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PigpenPigsListScreen(pigpen: pigpen),
                            ),
                          );
                        } else if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('View Pigs'),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                      icon: const Icon(Icons.more_vert), // three dots icon
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
