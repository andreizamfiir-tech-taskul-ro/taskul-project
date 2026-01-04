class TaskReview {
  final int id;
  final int taskId;
  final int authorId;
  final int targetId;
  final int rating;
  final String? comment;
  final String? authorName;
  final String? targetName;
  final DateTime? createdAt;

  TaskReview({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.targetId,
    required this.rating,
    this.comment,
    this.authorName,
    this.targetName,
    this.createdAt,
  });

  factory TaskReview.fromJson(Map<String, dynamic> json) {
    return TaskReview(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      authorId: json['author_id'] as int,
      targetId: json['target_id'] as int,
      rating: json['rating'] as int,
      comment: json['comment']?.toString(),
      authorName: json['author_name']?.toString(),
      targetName: json['target_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
