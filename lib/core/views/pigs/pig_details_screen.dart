import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:share/share.dart';
import '../../models/pig_model.dart';
import '../../models/pigpen_model.dart';
import '../../models/event_model.dart';
import 'pig_management_screen.dart';
import '../events/event_management_screen.dart';
import 'dart:io';

class PigDetailsScreen extends StatefulWidget {
  final Pig pig;
  final List<Pigpen> pigpens;
  final List<Pig> allPigs;
  final Function(Pig) onPigUpdated;
  final Function(Pig) onPigDeleted;

  const PigDetailsScreen({
    super.key,
    required this.pig,
    required this.pigpens,
    required this.allPigs,
    required this.onPigUpdated,
    required this.onPigDeleted,
  });

  @override
  State<PigDetailsScreen> createState() => _PigDetailsScreenState();
}

class _PigDetailsScreenState extends State<PigDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Pig _currentPig;
  late Box<PigEvent> _eventsBox;
  List<PigEvent> _upcomingEvents = [];
  List<PigEvent> _pastEvents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentPig = widget.pig;
    _initHive();
  }

  Future<void> _initHive() async {
    _eventsBox = Hive.box<PigEvent>('pig_events');
    _loadPigEvents();
  }

  void _loadPigEvents() {
    final allEvents = _eventsBox.values
        .where((event) => event.pigTags.contains(_currentPig.tag))
        .toList();

    setState(() {
      _upcomingEvents = allEvents.where((e) => e.isUpcoming).toList()
        ..sort((a, b) => a.date.compareTo(b.date)); // Nearest first
      _pastEvents = allEvents.where((e) => e.isPast).toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // Newest first
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _isValidImage(String path) async {
    try {
      final file = File(path);
      final exists = await file.exists();
      return exists;
    } catch (e) {
      return false;
    }
  }

  void _navigateToParent(String? tag) {
    if (tag == null) return;

    try {
      final parentPig = widget.allPigs.firstWhere((p) => p.tag == tag);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PigDetailsScreen(
            pig: parentPig,
            pigpens: widget.pigpens,
            allPigs: widget.allPigs,
            onPigUpdated: widget.onPigUpdated,
            onPigDeleted: widget.onPigDeleted,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parent pig not found')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _currentPig.name?.isNotEmpty ?? false
              ? _currentPig.name!
              : "#${_currentPig.tag}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editPigDetails,
            tooltip: 'Edit pig',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderSection(),
          TabBar(
            controller: _tabController,
            labelColor: Colors.green[700],
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green[700],
            tabs: const [
              Tab(text: "Details"),
              Tab(text: "Events"),
              Tab(text: "History"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(),
                _buildEventsTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.green[700],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        Positioned(
          top: 20,
          child: _buildPigAvatar(),
        ),
      ],
    );
  }

  Widget _buildPigAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: (_currentPig.imagePath?.isNotEmpty ?? false)
            ? FutureBuilder(
                future: _isValidImage(_currentPig.imagePath!),
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return Image.file(
                      File(_currentPig.imagePath!),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildDefaultAvatar(),
                    );
                  }
                  return _buildDefaultAvatar();
                },
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.pets, size: 50, color: Colors.green[700]),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow("Tag Number", _currentPig.tag),
              _buildDetailRow("Name", _currentPig.name ?? "-"),
              _buildDetailRow("Breed", _currentPig.breed),
              _buildDetailRow("Gender", _currentPig.gender),
              _buildDetailRow("Stage", _currentPig.stage),
              _buildDetailRow("Age", _currentPig.getFormattedAge()),
              _buildDetailRow("Weight", "${_currentPig.weight} kg"),
              _buildDetailRow("Source", _currentPig.source),
              _buildDetailRow("Date of Birth", _currentPig.dob),
              _buildDetailRow("Date of Entry", _currentPig.doe),
              _buildDetailRow(
                "Pigpen",
                _currentPig.pigpenKey != null
                    ? _currentPig.getPigpenName(widget.pigpens) ?? "Unknown"
                    : "Unassigned",
              ),
              _buildDetailRow(
                "Mother's Tag",
                _currentPig.motherTag ?? "-",
                isClickable: _currentPig.motherTag != null,
                onTap: _currentPig.motherTag != null
                    ? () => _navigateToParent(_currentPig.motherTag)
                    : null,
              ),
              _buildDetailRow(
                "Father's Tag",
                _currentPig.fatherTag ?? "-",
                isClickable: _currentPig.fatherTag != null,
                onTap: _currentPig.fatherTag != null
                    ? () => _navigateToParent(_currentPig.fatherTag)
                    : null,
              ),
              _buildDetailRow(
                "Notes",
                (_currentPig.notes ?? "").isNotEmpty ? _currentPig.notes! : "-",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    return _upcomingEvents.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event, size: 50, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No upcoming events",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = _upcomingEvents[index];
              return _buildEventCard(event, isUpcoming: true);
            },
          );
  }

  Widget _buildHistoryTab() {
    return _pastEvents.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 50, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No past events",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _pastEvents.length,
            itemBuilder: (context, index) {
              final event = _pastEvents[index];
              return _buildEventCard(event, isUpcoming: false);
            },
          );
  }

  Widget _buildEventCard(PigEvent event, {required bool isUpcoming}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  event.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isUpcoming ? Colors.green[700] : Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
                Chip(
                  label: Text(event.eventType),
                  backgroundColor: _getEventTypeColor(event.eventType),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy').format(event.date),
              style: TextStyle(
                color: isUpcoming ? Colors.green[700] : Colors.grey,
              ),
            ),
            if (isUpcoming)
              Chip(
                label: const Text("Upcoming"),
                backgroundColor: Colors.green[50],
              ),
            const SizedBox(height: 8),
            Text(event.description),
          ],
        ),
      ),
    );
  }

  Color _getEventTypeColor(String type) {
    switch (type) {
      case 'Health':
        return Colors.red[100]!;
      case 'Breeding':
        return Colors.purple[100]!;
      case 'Feeding':
        return Colors.orange[100]!;
      case 'Movement':
        return Colors.blue[100]!;
      default:
        return Colors.grey[200]!;
    }
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isClickable = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green[700],
              ),
            ),
          ),
          Expanded(
            child: isClickable
                ? GestureDetector(
                    onTap: onTap,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text("Share Pig Details"),
              onTap: () {
                Navigator.pop(context);
                _sharePigDetails();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete Pig"),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePig();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _editPigDetails() async {
    final updatedPig = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PigManagementScreen(
          pig: _currentPig,
          pigpens: widget.pigpens,
          allPigs: widget.allPigs,
          pigpenIndex: 0,
          key: widget.key,
        ),
      ),
    );

    if (updatedPig != null && mounted) {
      setState(() {
        _currentPig = updatedPig;
      });
      widget.onPigUpdated(updatedPig);
    }
  }

  void _sharePigDetails() {
    final String shareText = '''
Pig Details:
Tag: ${_currentPig.tag}
Name: ${_currentPig.name ?? '-'}
Breed: ${_currentPig.breed}
Weight: ${_currentPig.weight} kg
Age: ${_currentPig.getFormattedAge()}
Pigpen: ${_currentPig.pigpenKey != null ? _currentPig.getPigpenName(widget.pigpens) ?? "Unknown" : "Unassigned"}
Mother: ${_currentPig.motherTag ?? '-'}
Father: ${_currentPig.fatherTag ?? '-'}
''';
    Share.share(shareText);
  }

  void _confirmDeletePig() {
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
            onPressed: () {
              Navigator.pop(context);
              widget.onPigDeleted(_currentPig);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addNewEvent() async {
    final newEvent = await Navigator.push<PigEvent>(
      context,
      MaterialPageRoute(
        builder: (context) => EventManagementScreen(
          allPigs: [_currentPig],
          initialSelectedPigs: [_currentPig.tag],
        ),
      ),
    );

    if (newEvent != null && mounted) {
      _loadPigEvents();
      widget.onPigUpdated(_currentPig);
    }
  }
}
