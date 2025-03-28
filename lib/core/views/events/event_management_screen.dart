import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../models/pig_model.dart';

class EventManagementScreen extends StatefulWidget {
  final List<Pig> allPigs;
  final List<String> initialSelectedPigs;

  const EventManagementScreen(
      {super.key, required this.allPigs, required this.initialSelectedPigs});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  late Box<PigEvent> _eventsBox;
  List<PigEvent> _allEvents = [];
  String _searchQuery = '';
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    _eventsBox = Hive.box<PigEvent>('pig_events');
    _loadEvents();
  }

  void _loadEvents() {
    setState(() {
      _allEvents = _eventsBox.values.toList();
    });
  }

  List<PigEvent> get _filteredEvents {
    var filtered = _allEvents.where((event) {
      final matchesSearch = event.name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          event.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType =
          _filterType == 'All' || event.eventType == _filterType;
      return matchesSearch && matchesType;
    }).toList();

    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
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
            onPressed: _showAddEventDialog,
            tooltip: 'Add new event',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
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

    return ListView.builder(
      itemCount: _filteredEvents.length,
      itemBuilder: (context, index) {
        final event = _filteredEvents[index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(PigEvent event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
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
                color: event.isUpcoming ? Colors.green[700] : Colors.grey,
              ),
            ),
            if (event.isUpcoming)
              Chip(
                label: const Text("Upcoming"),
                backgroundColor: Colors.green[50],
              ),
            const SizedBox(height: 8),
            Text(
              event.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              "Pigs: ${event.pigTags.length}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (event.isUpcoming) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _markEventAsComplete(event),
                  child: const Text("Mark Complete"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markEventAsComplete(PigEvent event) async {
    final updatedEvent = PigEvent(
      id: event.id,
      name: event.name,
      date: DateTime.now(), // Set to current time when completed
      description: event.description,
      pigTags: event.pigTags,
      eventType: event.eventType,
    );

    await _eventsBox.put(event.id, updatedEvent);
    _loadEvents();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event marked as complete')),
      );
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

  Future<void> _showAddEventDialog() async {
    final result = await showDialog<PigEvent>(
      context: context,
      builder: (context) => AddEditEventDialog(
        allPigs: widget.allPigs,
        existingEvent: null,
        initialSelectedPigs: widget.initialSelectedPigs,
      ),
    );

    if (result != null) {
      await _saveEvent(result);
    }
  }

  Future<void> _showEventDetails(PigEvent event) async {
    final result = await showDialog<PigEvent?>(
      context: context,
      builder: (context) => AddEditEventDialog(
        allPigs: widget.allPigs,
        existingEvent: event,
        initialSelectedPigs: event.pigTags,
      ),
    );

    if (result != null) {
      await _saveEvent(result);
    }
  }

  Future<void> _saveEvent(PigEvent event) async {
    try {
      await _eventsBox.put(event.id, event);
      _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving event: ${e.toString()}')));
      }
    }
  }

  Future<void> _deleteEvent(PigEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this event?"),
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
        await _eventsBox.delete(event.id);
        _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting event: ${e.toString()}')));
        }
      }
    }
  }
}

class AddEditEventDialog extends StatefulWidget {
  final List<Pig> allPigs;
  final PigEvent? existingEvent;
  final List<String> initialSelectedPigs;

  const AddEditEventDialog({
    super.key,
    required this.allPigs,
    this.existingEvent,
    required this.initialSelectedPigs,
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
    return AlertDialog(
      title:
          Text(widget.existingEvent != null ? "Edit Event" : "Add New Event"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  labelText: "Description *",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required field' : null,
              ),
              const SizedBox(height: 16),
              _buildPigSelection(),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.existingEvent != null)
          TextButton(
            onPressed: () => _confirmDelete(),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _saveEvent,
          child: const Text("Save"),
        ),
      ],
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
            borderRadius: BorderRadius.circular(4),
          ),
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPigTags.isEmpty) return;

    final event = PigEvent(
      id: widget.existingEvent?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      date: _selectedDate,
      description: _descriptionController.text,
      pigTags: _selectedPigTags,
      eventType: _selectedEventType,
    );

    Navigator.pop(context, event);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this event?"),
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
      Navigator.pop(context, null); // Return null to indicate deletion
    }
  }
}
