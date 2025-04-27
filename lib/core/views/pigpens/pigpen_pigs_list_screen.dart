import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pigcare/core/models/pig_model.dart';
import 'package:pigcare/core/models/pigpen_model.dart';

class PigpenPigsListScreen extends StatefulWidget {
  final Pigpen pigpen;

  const PigpenPigsListScreen({super.key, required this.pigpen});

  @override
  State<PigpenPigsListScreen> createState() => _PigpenPigsListScreenState();
}

class _PigpenPigsListScreenState extends State<PigpenPigsListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'lib/assets/images/pig.png',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text('Pigs in ${widget.pigpen.name} Pigpen'),
            const SizedBox(width: 8),
            ClipOval(
              child: Image.asset(
                'lib/assets/images/pigpen.png',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<Box<Pigpen>>(
        valueListenable: Hive.box<Pigpen>('pigpens').listenable(),
        builder: (context, box, _) {
          final updatedPigpen = box.get(widget.pigpen.key);
          final pigs = updatedPigpen?.pigs ?? widget.pigpen.pigs;

          if (pigs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'lib/assets/images/pig.png',
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pigs in ${widget.pigpen.name} pen',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: pigs.length,
            itemBuilder: (context, index) => _buildPigCard(pigs[index]),
          );
        },
      ),
    );
  }

  Widget _buildPigCard(Pig pig) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              _buildPigAvatar(pig),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tag: ${pig.tag}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${pig.gender} • ${pig.stage} • ${pig.getFormattedAge()}",
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${pig.weight} kg",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPigAvatar(Pig pig) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: Colors.grey[200],
      backgroundImage:
          pig.imagePath != null ? FileImage(File(pig.imagePath!)) : null,
      child: pig.imagePath == null
          ? Image.asset(
              'lib/assets/images/pig.png',
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            )
          : null,
    );
  }
}
