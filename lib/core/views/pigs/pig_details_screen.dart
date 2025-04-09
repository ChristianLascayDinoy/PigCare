import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../models/pig_model.dart';
import '../../models/pigpen_model.dart';
import '../../models/task_model.dart'; // This should be updated to task_model.dart
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
  late Box<PigTask> _tasksBox; // Changed from PigEvent to PigTask
  List<PigTask> _upcomingTasks = []; // Changed from Events to Tasks
  List<PigTask> _pastTasks = []; // Changed from Events to Tasks
  bool _isLoadingTasks = false; // Changed from Events to Tasks

  List<Pig> _getOffspring() {
    return widget.allPigs
        .where((pig) =>
            pig.motherTag == _currentPig.tag ||
            pig.fatherTag == _currentPig.tag)
        .toList();
  }

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
      _loadPigTasks(); // Changed from Events to Tasks
    }
  }

  Future<void> _initHive() async {
    _tasksBox =
        await Hive.openBox<PigTask>('pig_tasks'); // Changed from pig_events
  }

  Future<void> _loadPigTasks() async {
    // Changed from Events to Tasks
    setState(() => _isLoadingTasks = true);

    try {
      final allTasks = _tasksBox.values
          .where((task) => task.pigTags.contains(_currentPig.tag))
          .toList();

      setState(() {
        _upcomingTasks = allTasks
            .where((e) => !e.isCompleted) // Only incomplete tasks
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        _pastTasks = allTasks
            .where((e) => e.isCompleted) // Only completed tasks
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error loading tasks: ${e.toString()}')), // Changed from events
        );
      }
    } finally {
      setState(() => _isLoadingTasks = false);
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
            Tab(
                icon: Icon(Icons.task_alt),
                text: "Tasks"), // Changed from events
            Tab(icon: Icon(Icons.history), text: "History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildTasksTab(), // Changed from events
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
        _buildParentDetailRow("Mother's Tag", _currentPig.motherTag),
        _buildParentDetailRow("Father's Tag", _currentPig.fatherTag),
        _buildDetailRow(
          "Notes",
          (_currentPig.notes ?? "").isNotEmpty ? _currentPig.notes! : "-",
        ),
        _buildOffspringSection(),
      ],
    );
  }

  Widget _buildTasksTab() {
    // Changed from Events to Tasks
    return _isLoadingTasks
        ? _buildLoadingIndicator()
        : _upcomingTasks.isEmpty
            ? _buildEmptyState(
                "No upcoming tasks", // Changed from events
                Icons.task, // Changed from event
              )
            : RefreshIndicator(
                onRefresh: _loadPigTasks, // Changed from events
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _upcomingTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(
                        _upcomingTasks[index]); // Changed from event
                  },
                ),
              );
  }

  Widget _buildHistoryTab() {
    return _isLoadingTasks
        ? _buildLoadingIndicator()
        : _pastTasks.isEmpty
            ? _buildEmptyState(
                "No past tasks", Icons.history) // Changed from events
            : RefreshIndicator(
                onRefresh: _loadPigTasks, // Changed from events
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _pastTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(
                        _pastTasks[index]); // Changed from event
                  },
                ),
              );
  }

  Widget _buildTaskCard(PigTask task) {
    // Changed from Event to Task
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showTaskDetails(task), // Changed from event
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
                      task.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: task.isUpcoming
                            ? Colors.green[700]
                            : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Chip(
                    label: Text(task.taskType), // Changed from eventType
                    backgroundColor:
                        _getTaskTypeColor(task.taskType), // Changed from event
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
                    DateFormat('MMM dd, yyyy').format(task.date),
                    style: TextStyle(
                      color: task.isUpcoming ? Colors.green[700] : Colors.grey,
                    ),
                  ),
                  if (task.isUpcoming) ...[
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
                task.description,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOffspringSection() {
    final offspring = _getOffspring();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          "Offspring (${offspring.length})",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.green[700],
          ),
        ),
        const SizedBox(height: 8),
        if (offspring.isEmpty)
          _buildNoOffspringMessage()
        else
          Column(
            children: offspring.map((pig) => _buildOffspringItem(pig)).toList(),
          ),
      ],
    );
  }

  Widget _buildNoOffspringMessage() {
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "No offspring linked yet!",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "To link one, go and edit the offspring's record, "
              "enter this pig's tag number in the 'Father's tag no' or "
              "'Mother's tag no' field, and save.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffspringItem(Pig pig) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[200],
          child: Text(pig.genderSymbol),
        ),
        title: Text(pig.name ?? "Tag: ${pig.tag}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${pig.breed} • ${pig.getFormattedAge()}"),
            Text(
              "Born: ${pig.dob}",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToPig(pig),
      ),
    );
  }

  void _navigateToPig(Pig pig) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PigDetailsScreen(
          pig: pig,
          pigpens: widget.pigpens,
          allPigs: widget.allPigs,
          onPigUpdated: widget.onPigUpdated,
          onPigDeleted: widget.onPigDeleted,
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool showSearchIcon = false,
    VoidCallback? onSearchTap,
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
            child: Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ),
                if (showSearchIcon && onSearchTap != null)
                  IconButton(
                    icon: const Icon(Icons.search, size: 18),
                    onPressed: onSearchTap,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentDetailRow(String label, String? tag) {
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
            child: Row(
              children: [
                Text(tag ?? "-", style: const TextStyle(fontSize: 16)),
                if (tag != null)
                  IconButton(
                    icon: const Icon(Icons.search, size: 18),
                    onPressed: () => _navigateToParent(tag),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
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

  Future<void> _showTaskDetails(PigTask task) async {
    // Changed from Event to Task
    final result = await showDialog<PigTask>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.yMMMMd().add_jm().format(task.date),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(task.taskType), // Changed from eventType
                backgroundColor:
                    _getTaskTypeColor(task.taskType), // Changed from event
              ),
              const SizedBox(height: 16),
              Text(
                task.description,
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
        ],
      ),
    );

    if (result != null && mounted) {
      await _loadPigTasks(); // Changed from events
    }
  }

  // ==================== Pig Methods ====================

  void _navigateToParent(String? tag) {
    if (tag == null) return;

    try {
      final parent = widget.allPigs.firstWhere((p) => p.tag == tag);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PigDetailsScreen(
            pig: parent,
            pigpens: widget.pigpens,
            allPigs: widget.allPigs,
            onPigUpdated: widget.onPigUpdated,
            onPigDeleted: widget.onPigDeleted,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parent with tag $tag not found')),
      );
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

  Color _getTaskTypeColor(String type) {
    // Changed from Event to Task
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
