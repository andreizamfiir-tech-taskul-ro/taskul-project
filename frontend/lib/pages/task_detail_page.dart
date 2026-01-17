import 'package:flutter/material.dart';

import '../api/tasks_api.dart';
import '../models/task.dart';
import '../models/task_review.dart';
import '../state/auth_state.dart';
import '../widgets/auth_dialog.dart';
import 'map_page.dart';

class TaskDetailPage extends StatefulWidget {
  final Task task;
  final bool isPreview;

  const TaskDetailPage({
    super.key,
    required this.task,
    this.isPreview = false,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  bool _isActionLoading = false;
  late Future<List<TaskReview>> _futureReviews;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmittingReview = false;
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _futureReviews = fetchTaskReviews(widget.task.id);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _handleAction(bool accept) async {
    if (widget.isPreview) return;
    final auth = AuthState.instance;
    if (!auth.isAuthenticated || auth.user == null) {
      if (mounted) {
        await showAuthDialog(context);
      }
      return;
    }
    if (auth.user!.id == widget.task.creatorId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nu poti accepta sau refuza propriul tau task.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _isActionLoading = true;
    });

    try {
      final userId = auth.user!.id;
      if (accept) {
        await acceptTaskApi(widget.task.id, userId: userId);
      } else {
        await refuseTaskApi(widget.task.id, userId: userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(accept ? 'Task acceptat' : 'Task refuzat'),
          ),
        );
      }
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

  Future<void> _submitReview({required int targetId}) async {
    final auth = AuthState.instance;
    if (!auth.isAuthenticated || auth.user == null) {
      await showAuthDialog(context);
      return;
    }
    final userId = auth.user!.id;
    if (userId != widget.task.creatorId ||
        widget.task.statusId != 3 ||
        widget.task.assignedUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nu ai dreptul sa lasi review la acest task.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _isSubmittingReview = true;
    });
    try {
      await createTaskReview(
        taskId: widget.task.id,
        authorId: userId,
        targetId: targetId,
        rating: _rating,
        comment: _reviewController.text.trim().isEmpty
            ? null
            : _reviewController.text.trim(),
      );
      _reviewController.clear();
      setState(() {
        _futureReviews = fetchTaskReviews(widget.task.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review trimis')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nu am putut salva review-ul: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final auth = AuthState.instance;
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        final userId = auth.user?.id;
        final canReview = userId != null &&
            userId == task.creatorId &&
            task.assignedUserId != null &&
            task.statusId == 3;
        final isOwnTask = userId != null && task.creatorId == userId;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: AppBar(
            elevation: 0.5,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            title: Text(widget.isPreview ? 'Previzualizare task' : 'Detalii task'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(task: task, onTapAddress: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MapPage(focusTask: task),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                if (task.images.isNotEmpty) _Gallery(images: task.images),
                const SizedBox(height: 12),
                _InfoGrid(task: task),
                if (!widget.isPreview) ...[
                  const SizedBox(height: 16),
                  _ReviewsSection(
                    future: _futureReviews,
                    canReview: canReview,
                    currentUserId: userId,
                    targetName: task.assignedName,
                    onSubmit: task.assignedUserId == null
                        ? null
                        : () => _submitReview(targetId: task.assignedUserId!),
                    reviewController: _reviewController,
                    rating: _rating,
                    isSubmitting: _isSubmittingReview,
                    onRatingChanged: (value) {
                      setState(() {
                        _rating = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                _ActionRow(
                  isLoading: _isActionLoading,
                  onAccept: () => _handleAction(true),
                  onRefuse: () => _handleAction(false),
                  isOwnTask: isOwnTask,
                ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTapAddress;

  const _HeaderCard({
    required this.task,
    required this.onTapAddress,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'de ${task.creatorName}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '${task.price.toStringAsFixed(0)} lei',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 18, color: Colors.deepOrange),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: onTapAddress,
                  child: Text(
                    task.shortAddress,
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Chip(
                icon: Icons.schedule,
                label: 'Start ${_formatTime(task.startTime)}',
                color: Colors.blue,
              ),
              _Chip(
                icon: Icons.flag_outlined,
                label: task.statusLabel,
                color: Colors.indigo,
              ),
              if (task.assignedName != null)
                _Chip(
                  icon: Icons.person_pin_circle_outlined,
                  label: 'Asignat: ${task.assignedName}',
                  color: Colors.teal,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  final List<String> images;

  const _Gallery({required this.images});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Galerie foto',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                images[i],
                width: 280,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final Future<List<TaskReview>> future;
  final bool canReview;
  final int? currentUserId;
  final String? targetName;
  final VoidCallback? onSubmit;
  final TextEditingController reviewController;
  final int rating;
  final bool isSubmitting;
  final ValueChanged<int> onRatingChanged;

  const _ReviewsSection({
    required this.future,
    required this.canReview,
    required this.currentUserId,
    required this.targetName,
    required this.onSubmit,
    required this.reviewController,
    required this.rating,
    required this.isSubmitting,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskReview>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final reviews = snapshot.data ?? [];
        final userReview = currentUserId == null
            ? null
            : reviews.cast<TaskReview?>().firstWhere(
                (r) => r != null && r.authorId == currentUserId,
                orElse: () => null,
              );
        final hasReviewed = userReview != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reviews.isNotEmpty) ...[
              const Text(
                'Review-uri',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...reviews.map(
                (r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StarRow(rating: r.rating, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            r.authorName ?? 'Utilizator',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          if (r.createdAt != null)
                            Text(
                              r.createdAt!.toLocal().toString().split('.').first,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                      if ((r.comment ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(r.comment!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (canReview && !hasReviewed) ...[
              const SizedBox(height: 8),
              _ReviewComposer(
                targetName: targetName,
                controller: reviewController,
                rating: rating,
                isSubmitting: isSubmitting,
                onRatingChanged: onRatingChanged,
                onSubmit: onSubmit,
              ),
            ],
            if (canReview && hasReviewed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review-ul tau',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      _StarRow(rating: userReview!.rating, size: 18),
                      if ((userReview.comment ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(userReview.comment!),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReviewComposer extends StatelessWidget {
  final String? targetName;
  final TextEditingController controller;
  final int rating;
  final bool isSubmitting;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback? onSubmit;

  const _ReviewComposer({
    required this.targetName,
    required this.controller,
    required this.rating,
    required this.isSubmitting,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final name = targetName ?? 'executant';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lasa un review pentru $name',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (index) {
                final value = index + 1;
                return IconButton(
                  onPressed: isSubmitting ? null : () => onRatingChanged(value),
                  icon: Icon(
                    value <= rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              },
            ),
          ),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Scrie un comentariu (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Trimite review'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const _StarRow({
    required this.rating,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final count = rating.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (_) => Icon(Icons.star, color: Colors.green, size: size),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final Task task;

  const _InfoGrid({required this.task});

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Status', task.statusLabel),
      ('Start', '${task.startTime.toLocal()}'.split('.').first),
      ('Locatie', task.shortAddress),
      ('Pret', '${task.price.toStringAsFixed(0)} lei'),
      if (task.assignedName != null) ('Asignat', task.assignedName!),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards
          .map(
            (c) => Container(
              width: 180,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.$1,
                    style: const TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final bool isOwnTask;

  const _ActionRow({
    required this.isLoading,
    required this.onAccept,
    required this.onRefuse,
    required this.isOwnTask,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
          ),
            onPressed: isLoading || isOwnTask ? null : onAccept,
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
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.deepPurple),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: Colors.deepPurple,
            ),
            onPressed: isLoading || isOwnTask ? null : onRefuse,
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
    );
  }
}
