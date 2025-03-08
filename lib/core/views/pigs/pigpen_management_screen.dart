import 'package:flutter/material.dart';
import 'pig_management_screen.dart';
import '../../models/pigpen_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PigpenManagementScreen extends StatefulWidget {
  const PigpenManagementScreen({super.key});

  @override
  _PigpenManagementScreenState createState() => _PigpenManagementScreenState();
}

class _PigpenManagementScreenState extends State<PigpenManagementScreen> {
  final Box pigpenBox = Hive.box('pigpens');

  void _showPigpenDialog({int? index}) {
    TextEditingController nameController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();

    if (index != null) {
      Pigpen pigpen = pigpenBox.getAt(index);
      nameController.text = pigpen.name;
      descriptionController.text = pigpen.description;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(index == null ? "Add Pigpen" : "Edit Pigpen"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Pigpen Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  Pigpen pigpen = Pigpen(
                    name: nameController.text,
                    description: descriptionController.text,
                    pigs: [],
                  );

                  if (index == null) {
                    pigpenBox.add(pigpen);
                  } else {
                    pigpenBox.putAt(index, pigpen);
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

  void _deletePigpen(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Pigpen"),
        content: const Text("Are you sure you want to delete this pigpen?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                pigpenBox.deleteAt(index);
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
          title: const Text("Pigpen Management"),
          backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder(
          valueListenable: pigpenBox.listenable(),
          builder: (context, box, _) {
            if (box.isEmpty) {
              return const Center(child: Text("No pigpens added yet."));
            }

            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemCount: box.length,
              itemBuilder: (context, index) {
                Pigpen pigpen = box.getAt(index);
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PigManagementScreen(pigpenIndex: index),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(pigpen.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 5),
                          Text(
                            pigpen.description.isNotEmpty
                                ? pigpen.description
                                : "No Description",
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _showPigpenDialog(index: index),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deletePigpen(index),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () => _showPigpenDialog(),
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }
}
