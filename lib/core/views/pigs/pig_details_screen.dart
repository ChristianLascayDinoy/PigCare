import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
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
  bool _isLoadingEvents = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentPig = widget.pig;
    _initHive();
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging &&
        (_tabController.index == 1 || _tabController.index == 2)) {
      _loadPigEvents();
    }
  }

  Future<void> _initHive() async {
    _eventsBox = await Hive.openBox<PigEvent>('pig_events');
  }

  Future<void> _loadPigEvents() async {
    if (_isLoadingEvents) return;

    setState(() => _isLoadingEvents = true);

    try {
      final allEvents = _eventsBox.values
          .where((event) => event.pigTags.contains(_currentPig.tag))
          .toList();

      setState(() {
        _upcomingEvents = allEvents.where((e) => e.isUpcoming).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        _pastEvents = allEvents.where((e) => e.isPast).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingEvents = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _isValidImage(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      final file = File(path);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // ==================== UI Components ====================
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: "Details"),
            Tab(icon: Icon(Icons.event_available), text: "Events"),
            Tab(icon: Icon(Icons.history), text: "History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildEventsTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPigAvatar(),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPigDetails(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPigAvatar() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.green[700]!, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: FutureBuilder<bool>(
          future: _isValidImage(_currentPig.imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingAvatar();
            }
            if (snapshot.data == true && _currentPig.imagePath != null) {
              return Image.file(
                File(_currentPig.imagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
              );
            }
            return _buildDefaultAvatar();
          },
        ),
      ),
    );
  }

  Widget _buildLoadingAvatar() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.pets, size: 60, color: Colors.green[700]),
    );
  }

  Widget _buildPigDetails() {
    return Column(
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
          onTap: () => _navigateToParent(_currentPig.motherTag),
        ),
        _buildDetailRow(
          "Father's Tag",
          _currentPig.fatherTag ?? "-",
          isClickable: _currentPig.fatherTag != null,
          onTap: () => _navigateToParent(_currentPig.fatherTag),
        ),
        _buildDetailRow(
          "Notes",
          (_currentPig.notes ?? "").isNotEmpty ? _currentPig.notes! : "-",
        ),
      ],
    );
  }

  Widget _buildEventsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Add New Event"),
            onPressed: _addNewEvent,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingEvents
              ? _buildLoadingIndicator()
              : _upcomingEvents.isEmpty
                  ? _buildEmptyState(
                      "No upcoming events\nAdd your first event!",
                      Icons.event,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPigEvents,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _upcomingEvents.length,
                        itemBuilder: (context, index) {
                          return _buildEventCard(_upcomingEvents[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return _isLoadingEvents
        ? _buildLoadingIndicator()
        : _pastEvents.isEmpty
            ? _buildEmptyState("No past events", Icons.history)
            : RefreshIndicator(
                onRefresh: _loadPigEvents,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pastEvents.length,
                  itemBuilder: (context, index) {
                    return _buildEventCard(_pastEvents[index]);
                  },
                ),
              );
  }

  Widget _buildEventCard(PigEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showEventDetails(event),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      event.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: event.isUpcoming
                            ? Colors.green[700]
                            : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Chip(
                    label: Text(event.eventType),
                    backgroundColor: _getEventTypeColor(event.eventType),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(event.date),
                    style: TextStyle(
                      color: event.isUpcoming ? Colors.green[700] : Colors.grey,
                    ),
                  ),
                  if (event.isUpcoming) ...[
                    const Spacer(),
                    Chip(
                      label: const Text("Upcoming"),
                      backgroundColor: Colors.green[50],
                      labelStyle: const TextStyle(color: Colors.green),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                event.description,
                style: const TextStyle(fontSize: 14),
              ),
              if (event.isUpcoming) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _markEventAsComplete(event),
                      child: const Text("Mark Complete"),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editEvent(event),
                      tooltip: 'Edit event',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // ==================== Event Methods ====================
  Future<void> _addNewEvent() async {
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
      await _loadPigEvents();
      widget.onPigUpdated(_currentPig);
    }
  }

  Future<void> _editEvent(PigEvent event) async {
    final updatedEvent = await Navigator.push<PigEvent>(
      context,
      MaterialPageRoute(
        builder: (context) => EventManagementScreen(
          allPigs: [_currentPig],
          initialSelectedPigs: [_currentPig.tag],
        ),
      ),
    );

    if (updatedEvent != null && mounted) {
      await _loadPigEvents();
    }
  }

  Future<void> _showEventDetails(PigEvent event) async {
    final result = await showDialog<PigEvent>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.yMMMMd().add_jm().format(event.date),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(event.eventType),
                backgroundColor: _getEventTypeColor(event.eventType),
              ),
              const SizedBox(height: 16),
              Text(
                event.description,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          if (event.isUpcoming)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _editEvent(event);
              },
              child: const Text("Edit"),
            ),
        ],
      ),
    );

    if (result != null && mounted) {
      await _loadPigEvents();
    }
  }

  Future<void> _markEventAsComplete(PigEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Completion"),
        content: const Text("Mark this event as completed?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final completedEvent = PigEvent(
          id: event.id,
          name: event.name,
          date: DateTime.now(), // Set to current time when completed
          description: event.description,
          pigTags: event.pigTags,
          eventType: event.eventType,
        );

        await _eventsBox.put(event.id, completedEvent);
        await _loadPigEvents();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event marked as complete')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  // ==================== Pig Methods ====================
  Future<void> _editPigDetails() async {
    final updatedPig = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PigManagementScreen(
          pig: _currentPig,
          pigpens: widget.pigpens,
          allPigs: widget.allPigs,
          pigpenIndex: 0,
        ),
      ),
    );

    if (updatedPig != null && mounted) {
      setState(() => _currentPig = updatedPig);
      widget.onPigUpdated(updatedPig);
    }
  }

  void _navigateToParent(String? tag) {
    if (tag == null || !mounted) return;

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

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
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
          ),
        );
      },
    );
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share: $shareText')),
      );
    }
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
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
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
}
