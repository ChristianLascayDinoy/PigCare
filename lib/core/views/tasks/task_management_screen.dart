import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../models/pig_model.dart';
import '../../models/pigpen_model.dart';

class TaskManagementScreen extends StatefulWidget {
  final List<Pig> allPigs;
  final List<Pigpen> allPigpens;
  final List<String> initialSelectedPigs;

  const TaskManagementScreen({
    super.key,
    required this.allPigs,
    required this.allPigpens,
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
          mainAxisSize: MainAxisSize.min,
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
        ),
        centerTitle: true,
        backgroundColor: Colors.green[700],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        backgroundColor: Colors.green[700],
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
              hintText: 'Search tasks...',
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/assets/images/task.png',
              width: 64,
              height: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? "No tasks found\nAdd your first task!"
                  : "No tasks match your search",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
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
                    label: Text(task.taskType),
                    backgroundColor: _getTaskTypeColor(task.taskType),
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
                      onPressed: () => _markTaskAsComplete(task),
                      child: const Text("Mark Complete"),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showTaskDetails(context, task),
                      tooltip: 'Edit task',
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
        await _tasksBox.put(task.id, completedTask);
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
          allPigs: widget.allPigs,
          allPigpens: widget.allPigpens,
          existingTask: null,
          initialSelectedPigs: widget.initialSelectedPigs,
          tasksBox: _tasksBox,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      await _saveTask(result);
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
                Text('Type: ${task.taskType}'),
                Text('Date: ${DateFormat.yMMMd().format(task.date)}'),
                if (task.completedDate != null)
                  Text(
                      'Completed: ${DateFormat.yMMMd().format(task.completedDate!)}'),
                const SizedBox(height: 16),
                const Text('Pigs in this task:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Column(
                  children: task.pigTags.map((tag) => Text(tag)).toList(),
                ),
                const SizedBox(height: 16),
                Text(task.description ?? 'No description'),
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
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Confirm Delete"),
                    content: Text("Delete ${task.name} task?"),
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
                Navigator.pop(context, confirmed ?? false);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (shouldDelete == true && mounted) {
        await _deleteTask(task);
      }
    } else {
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (context) => AddEditTaskDialog(
            allPigs: widget.allPigs,
            allPigpens: widget.allPigpens,
            existingTask: task,
            initialSelectedPigs: task.pigTags,
            tasksBox: _tasksBox,
          ),
        ),
      );

      if (mounted) {
        if (result is bool) {
          if (result) {
            await _loadTasks();
          }
        } else if (result is PigTask) {
          await _saveTask(result);
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
            content: Text('Task saved successfully'),
            backgroundColor: Colors.green, // Success color
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving task: $e'),
            backgroundColor: Colors.red, // Error color
          ),
        );
      }
    }
  }

  Color _getTaskTypeColor(String type) {
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
  final List<Pig> allPigs;
  final List<Pigpen> allPigpens;
  final PigTask? existingTask;
  final List<String> initialSelectedPigs;
  final Box<PigTask> tasksBox;

  const AddEditTaskDialog({
    super.key,
    required this.allPigs,
    required this.allPigpens,
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
  late String _selectedTaskType;
  late List<String> _selectedPigTags;
  late Pigpen? _selectedPigpen;
  late bool _assignToAllPigsInPen;
  late List<Pig> _pigsInSelectedPen;

  final List<String> _taskTypes = [
    'Health',
    'Breeding',
    'Feeding',
    'Movement',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingTask?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingTask?.description ?? '');
    _selectedDate = widget.existingTask?.date ?? DateTime.now();
    _selectedTaskType = widget.existingTask?.taskType ?? 'Health';
    _selectedPigTags = List.from(widget.initialSelectedPigs);
    _assignToAllPigsInPen = false;
    _pigsInSelectedPen = [];
    _selectedPigpen = null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updatePigsList(Pigpen? pigpen) {
    setState(() {
      _selectedPigpen = pigpen;
      _pigsInSelectedPen = pigpen?.pigs.toList() ?? [];
      if (_assignToAllPigsInPen) {
        _selectedPigTags = _pigsInSelectedPen.map((pig) => pig.tag).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTask != null ? "Edit Task" : "Add Task"),
        actions: [
          if (widget.existingTask != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmDeleteTask,
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
                  labelText: "Task Name *",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTaskType,
                decoration: const InputDecoration(
                  labelText: "Task Type *",
                  border: OutlineInputBorder(),
                ),
                items: _taskTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedTaskType = value!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Task Date *",
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
              _buildPigPenDropdown(),
              const SizedBox(height: 16),
              if (_selectedPigpen != null) _buildPigSelection(),
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
                      onPressed: _saveTask,
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

  Widget _buildPigPenDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Pig for this Task (Optional)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Pigpen>(
          decoration: const InputDecoration(
            labelText: "Pig Pen",
            border: OutlineInputBorder(),
          ),
          value: _selectedPigpen,
          items: widget.allPigpens.map((pen) {
            return DropdownMenuItem(
              value: pen,
              child: Text("${pen.name} (${pen.pigs.length} pigs)"),
            );
          }).toList(),
          onChanged: _updatePigsList,
        ),
      ],
    );
  }

  Widget _buildPigSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text("Apply to all pigs in this pen"),
          value: _assignToAllPigsInPen,
          onChanged: (value) {
            setState(() {
              _assignToAllPigsInPen = value!;
              if (_assignToAllPigsInPen) {
                _selectedPigTags =
                    _pigsInSelectedPen.map((pig) => pig.tag).toList();
              } else {
                _selectedPigTags.clear();
              }
            });
          },
        ),
        if (!_assignToAllPigsInPen) ...[
          const SizedBox(height: 8),
          const Text("Select Pigs:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _pigsInSelectedPen.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No pigs in this pen"),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _pigsInSelectedPen.length,
                    itemBuilder: (context, index) {
                      final pig = _pigsInSelectedPen[index];
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
        ],
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
    if (!_formKey.currentState!.validate()) return;

    final task = PigTask(
      id: widget.existingTask?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      date: _selectedDate,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : '',
      pigTags: _selectedPigTags,
      taskType: _selectedTaskType,
      isCompleted: widget.existingTask?.isCompleted ?? false,
      completedDate: widget.existingTask?.completedDate,
    );

    Navigator.pop(context, task);
  }

  Future<void> _confirmDeleteTask() async {
    if (widget.existingTask == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete ${widget.existingTask!.name} task?"),
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
        await widget.tasksBox.delete(widget.existingTask!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task successfully deleted'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting task: $e'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context, false);
        }
      }
    }
  }
}
