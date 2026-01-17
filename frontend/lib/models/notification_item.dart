class NotificationItem {
  final int id;
  final int profileId;
  final String type;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.profileId,
    required this.type,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      profileId: json['profile_id'] as int,
      type: json['type']?.toString() ?? '',
      payload: (json['payload'] as Map<String, dynamic>? ?? {}),
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
