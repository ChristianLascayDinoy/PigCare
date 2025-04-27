import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart'; // This should be updated to task_model.dart
import '../../models/pig_model.dart';

class TaskManagementScreen extends StatefulWidget {
  final List<Pig> allPigs;
  final List<String> initialSelectedPigs;

  const TaskManagementScreen({
    super.key,
    required this.allPigs,
    required this.initialSelectedPigs,
  });

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  late Box<PigTask> _tasksBox;
  List<PigTask> _allTasks = [];
  String _searchQuery = '';
  String _filterType = 'All';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    try {
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(PigTaskAdapter());
      }
      _tasksBox = await Hive.openBox<PigTask>('pig_tasks');
      _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing database: $e')),
        );
      }
    }
  }

  Future<void> _loadTasks() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final tasks = _tasksBox.values.toList();
      setState(() => _allTasks = tasks);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tasks: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTask(PigTask task) async {
    try {
      await _tasksBox.delete(task.id);
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task successfully deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting task: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  List<PigTask> get _filteredTasks {
    return _allTasks.where((task) {
      final matchesSearch =
          task.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (task.description
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false);
      final matchesType = _filterType == 'All' || task.taskType == _filterType;
      return matchesSearch && matchesType;
    }).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.date.compareTo(a.date);
      });
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
                'lib/assets/images/task.png',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Task Management",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ), // Changed from Event Management
        centerTitle: true,
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTaskDialog(context),
            tooltip: 'Add new task', // Changed from event
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading ? _buildLoadingIndicator() : _buildTaskList(),
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

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search tasks...', // Changed from events
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _filterType,
            items: ['All', 'Health', 'Breeding', 'Feeding', 'Movement', 'Other']
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _filterType = value!),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (_filteredTasks.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? "No tasks found\nAdd your first task!" // Changed from events
              : "No tasks match your search", // Changed from events
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _filteredTasks.length,
        itemBuilder: (context, index) {
          final task = _filteredTasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(PigTask task) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showTaskDetails(context, task),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: task.isCompleted ? Colors.green[700] : null,
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
                    task.isCompleted
                        ? Icons.check_circle
                        : Icons.calendar_today,
                    size: 16,
                    color: task.isCompleted ? Colors.green : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(task.date),
                    style: TextStyle(
                      color: task.isCompleted
                          ? Colors.green[700]
                          : task.date.isAfter(DateTime.now())
                              ? Colors.green[700]
                              : Colors.grey,
                    ),
                  ),
                  if (task.isCompleted) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• Completed',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else if (task.date.isAfter(DateTime.now())) ...[
                    const Spacer(),
                    Chip(
                      label: const Text("Upcoming"),
                      backgroundColor: Colors.green[50],
                      labelStyle: const TextStyle(color: Colors.green),
                    ),
                  ],
                ],
              ),
              if (task.isCompleted && task.completedDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Completed on: ${DateFormat('MMM dd, yyyy').format(task.completedDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                "Pigs: ${task.pigTags.length}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!task.isCompleted) ...[
                    TextButton(
                      onPressed: () =>
                          _markTaskAsComplete(task), // Changed from event
                      child: const Text("Mark Complete"),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () =>
                          _showTaskDetails(context, task), // Changed from event
                      tooltip: 'Edit task', // Changed from event
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markTaskAsComplete(PigTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Completion"),
        content:
            const Text("This will lock the task from further edits. Continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Complete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final completedTask = task.copyWith(
          isCompleted: true,
          completedDate: DateTime.now(),
        );
        await _tasksBox.put(task.id, completedTask); // This saves to Hive
        await _loadTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task marked as complete')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final result = await Navigator.of(context).push<PigTask>(
      MaterialPageRoute(
        builder: (context) => AddEditTaskDialog(
          // Changed from Event
          allPigs: widget.allPigs,
          existingTask: null, // Changed from event
          initialSelectedPigs: widget.initialSelectedPigs,
          tasksBox: _tasksBox, // Changed from eventsBox
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      await _saveTask(result); // Changed from event
    }
  }

  Future<void> _showTaskDetails(BuildContext context, PigTask task) async {
    if (task.isCompleted) {
      // Read-only view for completed tasks with delete option
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(task.name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${task.taskType}'), // Changed from eventType
                Text('Date: ${DateFormat.yMMMd().format(task.date)}'),
                if (task.completedDate != null)
                  Text(
                      'Completed: ${DateFormat.yMMMd().format(task.completedDate!)}'),
                const SizedBox(height: 16),
                const Text('Pigs in this task:', // Changed from event
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Column(
                  children: task.pigTags.map((tag) => Text(tag)).toList(),
                ),
                const SizedBox(height: 16),
                Text(task.description),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Close"),
            ),
            TextButton(
              onPressed: () async {
                // Show confirmation before actual deletion
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Confirm Delete"),
                    content:
                        Text("Delete ${task.name} task?"), // Changed from event
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                // Close both dialogs and return the confirmation result
                Navigator.pop(context, confirmed ?? false);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (shouldDelete == true && mounted) {
        await _deleteTask(task); // Changed from event
      }
    } else {
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (context) => AddEditTaskDialog(
            // Changed from Event
            allPigs: widget.allPigs,
            existingTask: task, // Changed from event
            initialSelectedPigs: task.pigTags,
            tasksBox: _tasksBox, // Changed from eventsBox
          ),
        ),
      );

      if (mounted) {
        if (result is bool) {
          if (result) {
            await _loadTasks();
          }
        } else if (result is PigTask) {
          await _saveTask(result); // Changed from event
        }
      }
    }
  }

  Future<void> _saveTask(PigTask task) async {
    try {
      await _tasksBox.put(task.id, task);
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Task saved successfully')), // Changed from event
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving task: $e')), // Changed from event
        );
      }
    }
  }

  Color _getTaskTypeColor(String type) {
    // Changed from event
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

class AddEditTaskDialog extends StatefulWidget {
  // Changed from Event
  final List<Pig> allPigs;
  final PigTask? existingTask; // Changed from event
  final List<String> initialSelectedPigs;
  final Box<PigTask> tasksBox; // Changed from eventsBox

  const AddEditTaskDialog({
    super.key,
    required this.allPigs,
    this.existingTask,
    required this.initialSelectedPigs,
    required this.tasksBox,
  });

  @override
  State<AddEditTaskDialog> createState() => _AddEditTaskDialogState();
}

class _AddEditTaskDialogState extends State<AddEditTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late String _selectedTaskType; // Changed from event
  late List<String> _selectedPigTags;

  final List<String> _taskTypes = [
    // Changed from event
    'Health',
    'Breeding',
    'Feeding',
    'Movement',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.existingTask?.name ?? ''); // Changed from event
    _descriptionController = TextEditingController(
        text: widget.existingTask?.description ?? ''); // Changed from event
    _selectedDate =
        widget.existingTask?.date ?? DateTime.now(); // Changed from event
    _selectedTaskType =
        widget.existingTask?.taskType ?? 'Health'; // Changed from event
    _selectedPigTags = List.from(widget.initialSelectedPigs);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTask != null
            ? "Edit Task"
            : "Add Task"), // Changed from event
        actions: [
          if (widget.existingTask != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmDeleteTask, // Changed from event
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Task Name *", // Changed from event
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTaskType, // Changed from event
                decoration: const InputDecoration(
                  labelText: "Task Type *", // Changed from event
                  border: OutlineInputBorder(),
                ),
                items: _taskTypes // Changed from event
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) => setState(
                    () => _selectedTaskType = value!), // Changed from event
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Task Date *", // Changed from event
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description (Optional)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildPigSelection(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveTask, // Changed from event
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPigSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Pigs *",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(maxHeight: 200),
          child: widget.allPigs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No pigs available to select"),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.allPigs.length,
                  itemBuilder: (context, index) {
                    final pig = widget.allPigs[index];
                    return CheckboxListTile(
                      title: Text("${pig.tag} - ${pig.name ?? 'No name'}"),
                      value: _selectedPigTags.contains(pig.tag),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedPigTags.add(pig.tag);
                          } else {
                            _selectedPigTags.remove(pig.tag);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
        if (_selectedPigTags.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              "Please select at least one pig",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveTask() async {
    // Changed from event
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPigTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one pig')),
      );
      return;
    }

    final task = PigTask(
      // Changed from event
      id: widget.existingTask?.id ?? // Changed from event
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      date: _selectedDate,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : '',
      pigTags: _selectedPigTags,
      taskType: _selectedTaskType, // Changed from event
      isCompleted:
          widget.existingTask?.isCompleted ?? false, // Changed from event
      completedDate: widget.existingTask?.completedDate, // Changed from event
    );

    Navigator.pop(context, task); // Changed from event
  }

  Future<void> _confirmDeleteTask() async {
    // Changed from event
    if (widget.existingTask == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text(
            "Delete ${widget.existingTask!.name} task?"), // Changed from event
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
        await widget.tasksBox
            .delete(widget.existingTask!.id); // Changed from event
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task successfully deleted'), // Changed from event
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting task: $e'), // Changed from event
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, false);
        }
      }
    }
  }
}
