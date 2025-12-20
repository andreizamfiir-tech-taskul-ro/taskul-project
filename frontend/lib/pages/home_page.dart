import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/tasks_api.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import 'task_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Task>> futureTasks;
  final Set<int> _loadingActions = {};

  @override
  void initState() {
    super.initState();
    futureTasks = fetchTasks();
  }

  Future<void> _refresh() async {
    setState(() {
      futureTasks = fetchTasks();
    });
  }

  bool _isAcceptedTask(Task task) {
    final status = task.statusLabel.toLowerCase();
    return status.contains('acceptat') || status.contains('accepted');
  }

  Future<void> _handleAction({
    required Task task,
    required bool accept,
  }) async {
    setState(() {
      _loadingActions.add(task.id);
    });

    try {
      if (accept) {
        await acceptTaskApi(task.id);
      } else {
        await refuseTaskApi(task.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'Task acceptat' : 'Task refuzat',
            ),
          ),
        );
      }

      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A aparut o eroare: $e'),
          ),
        );
      }
    } finally {
      setState(() {
        _loadingActions.remove(task.id);
      });
    }
  }

  void _openTaskDetails(Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(task: task),
      ),
    );
  }

  void _showTaskOnMap(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (_) {
        return SizedBox(
          height: 320,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(task.lat, task.lng),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.taskul.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(task.lat, task.lng),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      size: 40,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EEF6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: CircleAvatar(
            backgroundColor: Colors.indigo.shade100,
            child: const Text(
              'TU',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.indigo,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Profilul tau',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            Text(
              'Tasker',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.star, color: Colors.amber, size: 18),
                SizedBox(width: 4),
                Text(
                  '4.8',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Task>>(
          future: futureTasks,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text('Eroare: ${snapshot.error}'),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _refresh,
                          child: const Text('Incearca din nou'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final tasks = snapshot.data ?? [];
            final acceptedTasks =
                tasks.where((task) => _isAcceptedTask(task)).toList();

            if (acceptedTasks.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nu ai task-uri acceptate momentan.')),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: acceptedTasks.length,
              itemBuilder: (context, index) {
                final task = acceptedTasks[index];
                final isLoading = _loadingActions.contains(task.id);

                return TaskCard(
                  task: task,
                  isLoading: isLoading,
                  onAccept: () => _handleAction(
                    task: task,
                    accept: true,
                  ),
                  onRefuse: () => _handleAction(
                    task: task,
                    accept: false,
                  ),
                  onViewDetails: () => _openTaskDetails(task),
                  onViewOnMap: () => _showTaskOnMap(task),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
