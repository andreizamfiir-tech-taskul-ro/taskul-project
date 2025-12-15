class Task {
  final int id;
  final String creatorName;
  final String title;
  final double price;
  final DateTime startTime;
  final String statusLabel;
  final double lat;
  final double lng;

  Task({
    required this.id,
    required this.creatorName,
    required this.title,
    required this.price,
    required this.startTime,
    required this.statusLabel,
    required this.lat,
    required this.lng,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
  return Task(
    id: json['id'],
    creatorName: json['creator_name'] ?? 'Necunoscut',
    title: json['title'] ?? '',
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    price: double.parse(json['price']?.toString() ?? '0'),
    startTime: json['start_time'] != null
        ? DateTime.parse(json['start_time'])
        : DateTime.now(),
    statusLabel: json['status_label'] ?? '—',
  );
}
}

