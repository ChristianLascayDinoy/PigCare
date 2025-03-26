import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/pigpen_model.dart';

class PigpenManagementScreen extends StatefulWidget {
  const PigpenManagementScreen({super.key});

  @override
  State<PigpenManagementScreen> createState() => _PigpenManagementScreenState();
}

class _PigpenManagementScreenState extends State<PigpenManagementScreen> {
  late final Box<Pigpen> _pigpenBox;
  final Set<String> _existingNames = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _pigpenBox = Hive.box<Pigpen>('pigpens');
    _loadExistingNames();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadExistingNames() {
    _existingNames.clear();
    _existingNames.addAll(_pigpenBox.values.map((p) => p.name.toLowerCase()));
  }

  bool _isNameDuplicate(String name, {Pigpen? excludePigpen}) {
    final lowerName = name.toLowerCase();
    if (excludePigpen != null) {
      return _existingNames
          .where((n) => n != excludePigpen.name.toLowerCase())
          .contains(lowerName);
    }
    return _existingNames.contains(lowerName);
  }

  Future<void> _showAddEditDialog({Pigpen? pigpen}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: pigpen?.name ?? '');
    final descriptionController = TextEditingController(
      text: pigpen?.description ?? '',
    );

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
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    if (value.toLowerCase() == "unassigned") {
                      return '"Unassigned" is a reserved name';
                    }
                    if (_isNameDuplicate(value, excludePigpen: pigpen)) {
                      return 'Pigpen name already exists';
                    }
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
              backgroundColor: Theme.of(context).primaryColor,
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _savePigpen(
                  pigpen: pigpen,
                  name: nameController.text,
                  description: descriptionController.text,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text(
              pigpen == null ? "Add" : "Save",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePigpen({
    required String name,
    required String description,
    Pigpen? pigpen,
  }) async {
    try {
      if (pigpen == null) {
        // Create new pigpen
        final newPigpen = Pigpen(
          name: name,
          description: description,
        );
        await _pigpenBox.add(newPigpen);
      } else {
        // Update existing pigpen
        final updated = pigpen.copyWith(
          name: name,
          description: description,
        );
        await updated.save();
      }

      _loadExistingNames();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pigpen == null
                  ? "Pigpen added successfully"
                  : "Pigpen updated successfully",
            ),
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
        title: const Text("Confirm Deletion"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Are you sure you want to delete this pigpen?"),
            if (pigpen.pigs.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "All pigs in this pen will be moved to Unassigned",
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
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
      final unassigned = await _ensureUnassignedPigpenExists();

      if (pigpen.pigs.isNotEmpty) {
        await unassigned.transferPigs(pigpen.pigs);
      }

      await pigpen.delete();
      _loadExistingNames();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pigpen deleted successfully"),
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
    }
  }

  Future<Pigpen> _ensureUnassignedPigpenExists() async {
    try {
      return _pigpenBox.values.firstWhere((p) => p.name == "Unassigned");
    } catch (e) {
      final newPigpen = Pigpen(name: "Unassigned", description: '');
      await _pigpenBox.add(newPigpen);
      return newPigpen;
    }
  }

  List<Pigpen> _filterPigpens(List<Pigpen> pigpens) {
    if (_searchQuery.isEmpty) return pigpens;
    return pigpens.where((p) {
      return p.name.toLowerCase().contains(_searchQuery) ||
          p.description.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pigpen Management"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: PigpenSearchDelegate(_pigpenBox.values.toList()),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<Pigpen>>(
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
            padding: const EdgeInsets.all(12.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Navigate to pigpen details screen
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
                  Text(
                    "${pigpen.pigs.length} pigs",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
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
              const SizedBox(height: 8),
              if (!isUnassigned)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      color: Colors.blue,
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      color: Colors.red,
                      onPressed: onDelete,
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

class PigpenSearchDelegate extends SearchDelegate {
  final List<Pigpen> pigpens;

  PigpenSearchDelegate(this.pigpens);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = query.isEmpty
        ? pigpens
        : pigpens.where((p) {
            return p.name.toLowerCase().contains(query.toLowerCase()) ||
                p.description.toLowerCase().contains(query.toLowerCase());
          }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final pigpen = results[index];
        return ListTile(
          title: Text(pigpen.name),
          subtitle: Text(pigpen.description),
          trailing: Text("${pigpen.pigs.length} pigs"),
          onTap: () {
            // TODO: Navigate to pigpen details
            close(context, pigpen);
          },
        );
      },
    );
  }
}
