import 'package:flutter/material.dart';
import 'pig_management_screen.dart'; // Import the new screen

class PigpenManagementScreen extends StatefulWidget {
  const PigpenManagementScreen({super.key});

  @override
  _PigpenManagementScreenState createState() => _PigpenManagementScreenState();
}

class _PigpenManagementScreenState extends State<PigpenManagementScreen> {
  List<Map<String, String>> pigpens = []; // Store pigpens

  void _showPigpenDialog({int? index}) {
    TextEditingController nameController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();

    if (index != null) {
      nameController.text = pigpens[index]["name"]!;
      descriptionController.text = pigpens[index]["description"]!;
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
              decoration: InputDecoration(labelText: "Pigpen Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: "Description"),
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
                  if (index == null) {
                    pigpens.add({
                      "name": nameController.text,
                      "description": descriptionController.text
                    });
                  } else {
                    pigpens[index] = {
                      "name": nameController.text,
                      "description": descriptionController.text
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
                pigpens.removeAt(index);
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
        child: pigpens.isEmpty
            ? const Center(child: Text("No pigpens added yet."))
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: pigpens.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PigManagementScreen(pigpen: pigpens[index]),
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
                            Text(pigpens[index]["name"]!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 5),
                            Text(
                              pigpens[index]["description"]!.isNotEmpty
                                  ? pigpens[index]["description"]!
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
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _showPigpenDialog(index: index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
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
