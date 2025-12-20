import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/tasks_api.dart';
import '../models/task.dart';
import 'task_detail_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage> {
  late Future<List<Task>> futureTasks;
  List<Task> tasks = [];
  Task? selectedTask;
  Task? _pendingFocusTask;
  bool _isActionLoading = false;

  final MapController mapController = MapController();

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

  void _selectTask(Task task) {
    setState(() {
      selectedTask = task;
    });

    mapController.move(
      LatLng(task.lat, task.lng),
      14,
    );
  }

  // Can be used later if we want to jump from another tab.
  void focusOnTask(Task task) {
    if (tasks.isNotEmpty) {
      _selectTask(task);
    } else {
      _pendingFocusTask = task;
    }
  }

  void _openTaskDetails(Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(task: task),
      ),
    );
  }

  Future<void> _handleAction(Task task, bool accept) async {
    setState(() {
      _isActionLoading = true;
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
            content: Text(accept ? 'Task acceptat' : 'Task refuzat'),
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
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EEF6),
      appBar: AppBar(
        title: const Text('Taskuri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
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

          tasks = snapshot.data ?? [];

          if (_pendingFocusTask != null) {
            final pending = _pendingFocusTask!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _selectTask(pending);
              _pendingFocusTask = null;
            });
          }

          if (tasks.isEmpty) {
            return const Center(child: Text('Nu sunt task-uri disponibile.'));
          }

          return Row(
            children: [
              Container(
                width: 360,
                color: Colors.grey.shade100,
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final isSelected = selectedTask?.id == task.id;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      leading: const Icon(Icons.task_alt_outlined),
                      title: Text(
                        task.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('de ${task.creatorName}'),
                          const SizedBox(height: 2),
                          Text(
                            task.address,
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${task.price.toStringAsFixed(0)} lei | '
                            '${_formatTime(task.startTime)} | '
                            '${task.statusLabel}',
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => _openTaskDetails(task),
                              child: const Text('Vezi detalii'),
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          '${task.price.toStringAsFixed(0)} lei',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      isThreeLine: true,
                      onTap: () => _selectTask(task),
                    );
                  },
                ),
              ),
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
                          onViewDetails: () => _openTaskDetails(selectedTask!),
                          onAction: (accept) =>
                              _handleAction(selectedTask!, accept),
                          isLoading: _isActionLoading,
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
}

class _TaskDetailsPanel extends StatelessWidget {
  final Task task;
  final VoidCallback onClose;
  final VoidCallback onViewDetails;
  final void Function(bool accept) onAction;
  final bool isLoading;

  const _TaskDetailsPanel({
    required this.task,
    required this.onClose,
    required this.onViewDetails,
    required this.onAction,
    required this.isLoading,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

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
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: Colors.deepOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.address,
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Pret: ${task.price.toStringAsFixed(0)} lei\n'
                'Start: ${_formatTime(task.startTime)}\n'
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
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onViewDetails,
                      child: const Text('Vezi detalii complete'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () => onAction(true),
                          child: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Accepta'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading ? null : () => onAction(false),
                          child: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Refuza'),
                        ),
                      ),
                    ],
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
