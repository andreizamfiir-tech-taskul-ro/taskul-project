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
  List<Task> visibleTasks = [];

  @override
  void initState() {
    super.initState();
    futureTasks = fetchTasks();
  }

  Future<void> _acceptTask(Task task) async {
    await acceptTaskApi(task.id); // mock backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ai acceptat: ${task.title}')),
    );
  }

  void _refuseTask(Task task) {
    setState(() {
      visibleTasks.removeWhere((t) => t.id == task.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task-uri pe hartă'),
      ),
      body: FutureBuilder<List<Task>>(
        future: futureTasks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Eroare: ${snapshot.error}'));
          }

          if (visibleTasks.isEmpty) {
            visibleTasks = List.from(snapshot.data!);
          }

          return Row(
            children: [
              // STÂNGA – LISTA TASK-URI
              Container(
                width: 340,
                color: Colors.grey.shade100,
                child: ListView.builder(
                  itemCount: visibleTasks.length,
                  itemBuilder: (context, index) {
                    final task = visibleTasks[index];

                    return Card(
                      margin: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // CREATOR
                            Text(
                              task.creatorName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 4),

                            // TITLU TASK
                            Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // DETALII
                            Text(
                              '💰 ${task.price.toStringAsFixed(0)} lei'
                              '  •  🕒 ${_formatTime(task.startTime)}'
                              '  •  ${task.statusLabel}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // BUTOANE
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _acceptTask(task),
                                  child: const Text('Acceptă'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _refuseTask(task),
                                  child: const Text('Refuză'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // DREAPTA – HARTA
              Expanded(
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(44.4268, 26.1025), // București
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.taskul.app',
                    ),
                    MarkerLayer(
                      markers: visibleTasks.map((task) {
                        return Marker(
                          point: LatLng(task.lat, task.lng),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        );
                      }).toList(),
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
