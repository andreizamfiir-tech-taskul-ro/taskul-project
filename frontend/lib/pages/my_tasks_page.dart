import 'package:flutter/material.dart';

import '../api/tasks_api.dart';
import '../models/task.dart';
import '../state/auth_state.dart';
import '../widgets/auth_dialog.dart';

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  Future<List<Task>>? _future;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  void _maybeLoad() {
    final user = AuthState.instance.user;
    if (user != null) {
      setState(() {
        _future = fetchMyTasks(user.id);
      });
    } else {
      setState(() {
        _future = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0040FF);

    return AnimatedBuilder(
      animation: AuthState.instance,
      builder: (context, _) {
        final user = AuthState.instance.user;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Task-urile mele'),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Autentificati-va pentru a vedea task-urile.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await showAuthDialog(context);
                      _maybeLoad();
                    },
                    child: const Text('Autentificare'),
                  ),
                ],
              ),
            ),
          );
        }

        if (_future == null) {
          _maybeLoad();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Task-urile mele'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _maybeLoad,
              ),
            ],
          ),
          body: _future == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<Task>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Eroare: ${snapshot.error}'));
                    }
                    final tasks = snapshot.data ?? [];
                    final createdByMe =
                        tasks.where((t) => t.creatorId == user.id).toList();
                    final assignedToMe =
                        tasks.where((t) => t.assignedUserId == user.id).toList();

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Section(
                            title: 'Asignate mie',
                            color: Colors.green.shade700,
                            tasks: assignedToMe,
                            emptyLabel: 'Nu ai task-uri asignate.',
                            isUpdating: _isUpdating,
                            currentUserId: user.id,
                            onChangeStatus: _handleChangeStatus,
                            onReview: _handleReview,
                          ),
                          const SizedBox(height: 20),
                          _Section(
                            title: 'Create de mine',
                            color: primaryBlue,
                            tasks: createdByMe,
                            emptyLabel: 'Nu ai creat inca task-uri.',
                            isUpdating: _isUpdating,
                            currentUserId: user.id,
                            onChangeStatus: _handleChangeStatus,
                            onReview: _handleReview,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _handleChangeStatus(Task task, int nextStatus, {String? note}) async {
    setState(() => _isUpdating = true);
    try {
      await updateTaskStatus(taskId: task.id, statusId: nextStatus, note: note);
      _maybeLoad();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _handleReview(Task task, int rating, String? comment) async {
    final user = AuthState.instance.user;
    if (user == null) return;
    final targetId = user.id == task.creatorId ? (task.assignedUserId ?? 0) : task.creatorId;
    if (targetId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu exista destinatar pentru review.')),
      );
      return;
    }
    setState(() => _isUpdating = true);
    try {
      await createTaskReview(
        taskId: task.id,
        authorId: user.id,
        targetId: targetId,
        rating: rating,
        comment: comment,
      );
      _maybeLoad();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review salvat')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Color color;
  final List<Task> tasks;
  final String emptyLabel;
  final bool isUpdating;
  final void Function(Task task, int nextStatus, {String? note}) onChangeStatus;
  final void Function(Task task, int rating, String? comment) onReview;
  final int currentUserId;

  const _Section({
    required this.title,
    required this.color,
    required this.tasks,
    required this.emptyLabel,
    required this.isUpdating,
    required this.onChangeStatus,
    required this.onReview,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Text(
            emptyLabel,
            style: const TextStyle(color: Colors.black54),
          )
        else
          Column(
            children: tasks
                .map(
                  (t) => _TaskTile(
                    task: t,
                    isUpdating: isUpdating,
                    currentUserId: currentUserId,
                    onChangeStatus: onChangeStatus,
                    onReview: onReview,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final bool isUpdating;
  final int currentUserId;
  final void Function(Task task, int nextStatus, {String? note}) onChangeStatus;
  final void Function(Task task, int rating, String? comment) onReview;
  const _TaskTile({
    required this.task,
    required this.isUpdating,
    required this.currentUserId,
    required this.onChangeStatus,
    required this.onReview,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  task.statusLabel,
                  style: const TextStyle(
                    color: Colors.blue,
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
              Text(
                '${task.price.toStringAsFixed(0)} lei',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: Colors.deepOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.shortAddress,
                  style: const TextStyle(color: Colors.deepOrange),
                ),
              ),
            ],
          ),
          if (task.assignedName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Asignat: ${task.assignedName}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 8),
          _buildStatusActions(context),
        ],
      ),
    );
  }

  Widget _buildStatusActions(BuildContext context) {
    final isAssignee = task.assignedUserId == currentUserId;
    final isCreator = task.creatorId == currentUserId;

    if (!isAssignee && !isCreator) {
      return const SizedBox.shrink();
    }

    if (task.statusId < 3 && isAssignee) {
      String label;
      int nextStatus;
      VoidCallback onTap;

      if (task.statusId <= 1) {
        label = 'In desfasurare';
        nextStatus = 2;
        onTap = () => onChangeStatus(task, nextStatus);
      } else {
        label = 'Finalizeaza';
        nextStatus = 3;
        onTap = () async {
          final note = await _showNoteDialog(context);
          if (note != null) {
            onChangeStatus(task, nextStatus, note: note);
          }
        };
      }

      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ElevatedButton(
          onPressed: isUpdating ? null : onTap,
          child: isUpdating
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label),
        ),
      );
    }

    if (task.statusId == 3 && (isAssignee || isCreator)) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton(
          onPressed: isUpdating
              ? null
              : () async {
                  final result = await _showReviewDialog(context);
                  if (result != null) {
                    onReview(task, result.$1, result.$2);
                  }
                },
          child: const Text('Lasa review'),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<String?> _showNoteDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Adauga descriere scurta'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ce ai facut / observatii',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuleaza'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: const Text('Salveaza'),
            ),
          ],
        );
      },
    );
  }

  Future<(int, String?)?> _showReviewDialog(BuildContext context) async {
    int rating = 5;
    final ctrl = TextEditingController();
    return showDialog<(int, String?)>(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Lasa un review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Rating'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: rating,
                      items: [1, 2, 3, 4, 5]
                          .map((v) =>
                              DropdownMenuItem(value: v, child: Text('$v')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => rating = v);
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Comentariu (optional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Anuleaza'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop((rating, ctrl.text.trim())),
                child: const Text('Trimite'),
              ),
            ],
          );
        });
      },
    );
  }
}
