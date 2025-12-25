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
    mapController.move(LatLng(task.lat, task.lng), 14);
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
    const primaryBlue = Color(0xFF0040FF);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.map_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Harta taskuri',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          const SizedBox(width: 6),
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 860;
              final mapHeight = isMobile ? 220.0 : constraints.maxHeight;

              return Column(
                children: [
                  if (!isMobile) const SizedBox(height: 8),
                  Expanded(
                    child: isMobile
                        ? Column(
                            children: [
                              _buildMapArea(
                                height: mapHeight,
                                primaryBlue: primaryBlue,
                                isMobile: true,
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: _TaskList(
                                  tasks: tasks,
                                  selectedTask: selectedTask,
                                  onSelect: _selectTask,
                                  onOpenDetails: _openTaskDetails,
                                  onAccept: (task) =>
                                      _handleAction(task, true),
                                  onRefuse: (task) =>
                                      _handleAction(task, false),
                                  primaryBlue: primaryBlue,
                                  isMobile: true,
                                  isActionLoading: _isActionLoading,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              SizedBox(
                                width: 360,
                                child: _TaskList(
                                  tasks: tasks,
                                  selectedTask: selectedTask,
                                  onSelect: _selectTask,
                                  onOpenDetails: _openTaskDetails,
                                  onAccept: (task) =>
                                      _handleAction(task, true),
                                  onRefuse: (task) =>
                                      _handleAction(task, false),
                                  primaryBlue: primaryBlue,
                                  isMobile: false,
                                  isActionLoading: _isActionLoading,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMapArea(
                                  height: mapHeight,
                                  primaryBlue: primaryBlue,
                                  isMobile: false,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMapArea({
    required double height,
    required Color primaryBlue,
    required bool isMobile,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
      child: Container(
        height: height,
        color: Colors.white,
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.taskul.app',
                ),
                MarkerLayer(
                  markers: tasks.map((task) {
                    return Marker(
                      point: LatLng(task.lat, task.lng),
                      width: 42,
                      height: 42,
                      child: GestureDetector(
                        onTap: () => _selectTask(task),
                        child: Icon(
                          Icons.location_pin,
                          size: 42,
                          color: selectedTask?.id == task.id
                              ? primaryBlue
                              : Colors.green,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            if (selectedTask != null && isMobile)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _SelectedTaskCard(
                    task: selectedTask!,
                    primaryBlue: primaryBlue,
                    onClose: () {
                      setState(() => selectedTask = null);
                    },
                    onOpenDetails: () => _openTaskDetails(selectedTask!),
                    onAction: (accept) => _handleAction(selectedTask!, accept),
                    isLoading: _isActionLoading,
                  ),
                ),
              ),
            if (selectedTask != null && !isMobile)
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
                  onAction: (accept) => _handleAction(selectedTask!, accept),
                  isLoading: _isActionLoading,
                  primaryBlue: primaryBlue,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final Task? selectedTask;
  final ValueChanged<Task> onSelect;
  final ValueChanged<Task> onOpenDetails;
  final ValueChanged<Task> onAccept;
  final ValueChanged<Task> onRefuse;
  final Color primaryBlue;
  final bool isMobile;
  final bool isActionLoading;

  const _TaskList({
    required this.tasks,
    required this.selectedTask,
    required this.onSelect,
    required this.onOpenDetails,
    required this.onAccept,
    required this.onRefuse,
    required this.primaryBlue,
    required this.isMobile,
    required this.isActionLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final task = tasks[index];
          final isSelected = selectedTask?.id == task.id;
          return _TaskListCard(
            task: task,
            isSelected: isSelected,
            isMobile: isMobile,
            primaryBlue: primaryBlue,
            onTap: () => onSelect(task),
            onOpenDetails: () => onOpenDetails(task),
            onAccept: () => onAccept(task),
            onRefuse: () => onRefuse(task),
            isLoading: isActionLoading && isSelected,
          );
        },
      ),
    );
  }
}

class _TaskListCard extends StatelessWidget {
  final Task task;
  final bool isSelected;
  final bool isMobile;
  final Color primaryBlue;
  final VoidCallback onTap;
  final VoidCallback onOpenDetails;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final bool isLoading;

  const _TaskListCard({
    required this.task,
    required this.isSelected,
    required this.isMobile,
    required this.primaryBlue,
    required this.onTap,
    required this.onOpenDetails,
    required this.onAccept,
    required this.onRefuse,
    required this.isLoading,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: isSelected ? 4 : 1,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      task.statusLabel,
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Start ${_formatTime(task.startTime)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const Spacer(),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? primaryBlue : Colors.black26,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'de ${task.creatorName}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: Colors.deepOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.address,
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Oferta curenta',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        '${task.price.toStringAsFixed(0)} lei',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 10 : 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isLoading ? null : onRefuse,
                        child: isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Refuza'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isLoading ? null : onAccept,
                        child: isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Accepta'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: onOpenDetails,
                child: const Text('Vezi detalii'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedTaskCard extends StatelessWidget {
  final Task task;
  final Color primaryBlue;
  final VoidCallback onClose;
  final VoidCallback onOpenDetails;
  final void Function(bool accept) onAction;
  final bool isLoading;

  const _SelectedTaskCard({
    required this.task,
    required this.primaryBlue,
    required this.onClose,
    required this.onOpenDetails,
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
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'de ${task.creatorName}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: Colors.deepOrange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.address,
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Start ${_formatTime(task.startTime)} • ${task.statusLabel}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${task.price.toStringAsFixed(0)} lei',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: isLoading ? null : () => onAction(false),
                      child: isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Refuza'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isLoading ? null : () => onAction(true),
                      child: isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Accepta'),
                    ),
                  ],
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onOpenDetails,
                child: const Text('Vezi detalii'),
              ),
            ),
          ],
        ),
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
  final Color primaryBlue;

  const _TaskDetailsPanel({
    required this.task,
    required this.onClose,
    required this.onViewDetails,
    required this.onAction,
    required this.isLoading,
    required this.primaryBlue,
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                          ),
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
