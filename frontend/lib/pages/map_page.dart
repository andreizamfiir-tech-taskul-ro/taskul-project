import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/tasks_api.dart';
import '../models/task.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late Future<List<Task>> futureTasks;
  List<Task> tasks = [];
  Task? selectedTask;

  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    futureTasks = fetchTasks();
  }

  void _selectTask(Task task) {
    setState(() {
      selectedTask = task;
    });

    mapController.move(
      LatLng(task.lat, task.lng),
      14,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task-uri pe hartă')),
      body: FutureBuilder<List<Task>>(
        future: futureTasks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Eroare: ${snapshot.error}'));
          }

          tasks = snapshot.data!;

          return Row(
            children: [
              // STÂNGA – LISTĂ TASK-URI
              Container(
                width: 360,
                color: Colors.grey.shade100,
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];

                    return ListTile(
                      title: Text(
                        task.creatorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${task.title}\n'
                        '💰 ${task.price.toStringAsFixed(0)} lei • '
                        '🕒 ${_formatTime(task.startTime)} • '
                        '${task.statusLabel}',
                      ),
                      isThreeLine: true,
                      onTap: () => _selectTask(task),
                      selected: selectedTask?.id == task.id,
                    );
                  },
                ),
              ),

              // DREAPTA – HARTA + PANEL
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: const MapOptions(
                        initialCenter: LatLng(44.4268, 26.1025),
                        initialZoom: 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.taskul.app',
                        ),
                        MarkerLayer(
                          markers: tasks.map((task) {
                            return Marker(
                              point: LatLng(task.lat, task.lng),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _selectTask(task),
                                child: Icon(
                                  Icons.location_pin,
                                  size: 40,
                                  color: selectedTask?.id == task.id
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    if (selectedTask != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: _TaskDetailsPanel(
                          task: selectedTask!,
                          onClose: () {
                            setState(() {
                              selectedTask = null;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TaskDetailsPanel extends StatelessWidget {
  final Task task;
  final VoidCallback onClose;

  const _TaskDetailsPanel({
    required this.task,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: double.infinity,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                task.creatorName,
                style: const TextStyle(color: Colors.grey),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '💰 ${task.price.toStringAsFixed(0)} lei\n'
                '🕒 ${task.startTime}\n'
                'Status: ${task.statusLabel}',
              ),
            ),

            if (task.images.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: task.images.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.network(
                        task.images[i],
                        width: 260,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Acceptă'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Refuză'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
