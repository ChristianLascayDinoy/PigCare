import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../models/pig_model.dart';

class EventManagementScreen extends StatefulWidget {
  final List<Pig> allPigs;
  final List<String> initialSelectedPigs;

  const EventManagementScreen({
    super.key,
    required this.allPigs,
    required this.initialSelectedPigs,
  });

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  late Box<PigEvent> _eventsBox;
  List<PigEvent> _allEvents = [];
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
      _eventsBox = await Hive.openBox<PigEvent>('pig_events');
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing database: $e')),
        );
      }
    }
  }

  Future<void> _loadEvents() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final events = _eventsBox.values.toList();
      setState(() => _allEvents = events);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteEvent(PigEvent event) async {
    try {
      await _eventsBox.delete(event.id);
      await _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event successfully deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  List<PigEvent> get _filteredEvents {
    return _allEvents.where((event) {
      final matchesSearch =
          event.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (event.description
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false);
      final matchesType =
          _filterType == 'All' || event.eventType == _filterType;
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
        title: const Text("Event Management"),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEventDialog(context),
            tooltip: 'Add new event',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading ? _buildLoadingIndicator() : _buildEventList(),
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
              hintText: 'Search events...',
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

  Widget _buildEventList() {
    if (_filteredEvents.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? "No events found\nAdd your first event!"
              : "No events match your search",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _filteredEvents.length,
        itemBuilder: (context, index) {
          final event = _filteredEvents[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  Widget _buildEventCard(PigEvent event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showEventDetails(context, event),
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
                      event.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: event.isCompleted ? Colors.green[700] : null,
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
                    event.isCompleted
                        ? Icons.check_circle
                        : Icons.calendar_today,
                    size: 16,
                    color: event.isCompleted ? Colors.green : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(event.date),
                    style: TextStyle(
                      color: event.isCompleted
                          ? Colors.green[700]
                          : event.date.isAfter(DateTime.now())
                              ? Colors.green[700]
                              : Colors.grey,
                    ),
                  ),
                  if (event.isCompleted) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• Completed',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ] else if (event.date.isAfter(DateTime.now())) ...[
                    const Spacer(),
                    Chip(
                      label: const Text("Upcoming"),
                      backgroundColor: Colors.green[50],
                      labelStyle: const TextStyle(color: Colors.green),
                    ),
                  ],
                ],
              ),
              if (event.isCompleted && event.completedDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Completed on: ${DateFormat('MMM dd, yyyy').format(event.completedDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (event.description != null &&
                  event.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  event.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                "Pigs: ${event.pigTags.length}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!event.isCompleted) ...[
                    TextButton(
                      onPressed: () => _markEventAsComplete(event),
                      child: const Text("Mark Complete"),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEventDetails(context, event),
                      tooltip: 'Edit event',
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

  Future<void> _markEventAsComplete(PigEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Completion"),
        content: const Text(
            "This will lock the event from further edits. Continue?"),
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
        final completedEvent = event.copyWith(
          isCompleted: true,
          completedDate: DateTime.now(),
        );
        await _eventsBox.put(event.id, completedEvent);
        await _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event marked as complete')),
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

  Future<void> _showAddEventDialog(BuildContext context) async {
    final result = await Navigator.of(context).push<PigEvent>(
      MaterialPageRoute(
        builder: (context) => AddEditEventDialog(
          allPigs: widget.allPigs,
          existingEvent: null,
          initialSelectedPigs: widget.initialSelectedPigs,
          eventsBox: _eventsBox,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      await _saveEvent(result);
    }
  }

  Future<void> _showEventDetails(BuildContext context, PigEvent event) async {
    if (event.isCompleted) {
      // Read-only view for completed events with delete option
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(event.name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${event.eventType}'),
                Text('Date: ${DateFormat.yMMMd().format(event.date)}'),
                if (event.completedDate != null)
                  Text(
                      'Completed: ${DateFormat.yMMMd().format(event.completedDate!)}'),
                const SizedBox(height: 16),
                const Text('Pigs in this event:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Column(
                  children: event.pigTags.map((tag) => Text(tag)).toList(),
                ),
                const SizedBox(height: 16),
                Text(event.description),
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
                    content: Text("Delete ${event.name} event?"),
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
        await _deleteEvent(event);
      }
    } else {
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (context) => AddEditEventDialog(
            allPigs: widget.allPigs,
            existingEvent: event,
            initialSelectedPigs: event.pigTags,
            eventsBox: _eventsBox,
          ),
        ),
      );

      if (mounted) {
        if (result is bool) {
          if (result) {
            await _loadEvents();
          }
        } else if (result is PigEvent) {
          await _saveEvent(result);
        }
      }
    }
  }

  Future<void> _saveEvent(PigEvent event) async {
    try {
      await _eventsBox.put(event.id, event);
      await _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving event: $e')),
        );
      }
    }
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

class AddEditEventDialog extends StatefulWidget {
  final List<Pig> allPigs;
  final PigEvent? existingEvent;
  final List<String> initialSelectedPigs;
  final Box<PigEvent> eventsBox;

  const AddEditEventDialog({
    super.key,
    required this.allPigs,
    this.existingEvent,
    required this.initialSelectedPigs,
    required this.eventsBox,
  });

  @override
  State<AddEditEventDialog> createState() => _AddEditEventDialogState();
}

class _AddEditEventDialogState extends State<AddEditEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late String _selectedEventType;
  late List<String> _selectedPigTags;

  final List<String> _eventTypes = [
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
        TextEditingController(text: widget.existingEvent?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingEvent?.description ?? '');
    _selectedDate = widget.existingEvent?.date ?? DateTime.now();
    _selectedEventType = widget.existingEvent?.eventType ?? 'Health';
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
        title: Text(widget.existingEvent != null ? "Edit Event" : "Add Event"),
        actions: [
          if (widget.existingEvent != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmDeleteEvent,
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
                  labelText: "Event Name *",
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedEventType,
                decoration: const InputDecoration(
                  labelText: "Event Type *",
                  border: OutlineInputBorder(),
                ),
                items: _eventTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedEventType = value!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Event Date *",
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
                      onPressed: _saveEvent,
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

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPigTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one pig')),
      );
      return;
    }

    final event = PigEvent(
      id: widget.existingEvent?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      date: _selectedDate,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : '',
      pigTags: _selectedPigTags,
      eventType: _selectedEventType,
      isCompleted: widget.existingEvent?.isCompleted ?? false,
      completedDate: widget.existingEvent?.completedDate,
    );

    Navigator.pop(context, event);
  }

  Future<void> _confirmDeleteEvent() async {
    if (widget.existingEvent == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete ${widget.existingEvent!.name} event?"),
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
        await widget.eventsBox.delete(widget.existingEvent!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event successfully deleted'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting event: $e'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, false);
        }
      }
    }
  }
}
