import 'package:flutter/material.dart';
import '../../models/pig_model.dart';
import 'dart:io';

class PigDetailsScreen extends StatefulWidget {
  final Pig pig;

  const PigDetailsScreen({super.key, required this.pig});

  @override
  // ignore: library_private_types_in_public_api
  _PigDetailsScreenState createState() => _PigDetailsScreenState();
}

class _PigDetailsScreenState extends State<PigDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("#${widget.pig.tag}"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 180,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/farm_background.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 60,
                left: MediaQuery.of(context).size.width / 2 - 50,
                child: widget.pig.imagePath != null &&
                        widget.pig.imagePath!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: Image.file(
                          File(widget.pig.imagePath!),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green, width: 3),
                        ),
                        child: const Icon(Icons.pets,
                            size: 50, color: Colors.green),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          TabBar(
            controller: _tabController,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: const [
              Tab(text: "Details"),
              Tab(text: "Events"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(),
                _buildEventsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Tag Number", widget.pig.tag),
              _buildDetailRow("Breed", widget.pig.breed),
              _buildDetailRow("Gender", widget.pig.gender),
              _buildDetailRow("Stage", widget.pig.stage),
              _buildDetailRow("Weight", "${widget.pig.weight} kg"),
              _buildDetailRow("Source", widget.pig.source),
              _buildDetailRow("Date of Birth", widget.pig.dob),
              _buildDetailRow("Date of Entry", widget.pig.doe),
              _buildDetailRow(
                  "Notes",
                  widget.pig.notes.isNotEmpty
                      ? widget.pig.notes
                      : "No additional notes"),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _editPigDetails,
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Details"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    return Center(
      child: Text(
        "No events recorded yet",
        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              "$label:",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text("Share"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete"),
              onTap: () {
                widget.pig.delete();
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _editPigDetails() async {
    //Edit
  }
}
