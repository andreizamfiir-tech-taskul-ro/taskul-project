class Task {
  final int id;
  final String creatorName;
  final String title;
  final double price;
  final DateTime startTime;
  final String statusLabel;
  final double lat;
  final double lng;
  final List<String> images;

  Task({
    required this.id,
    required this.creatorName,
    required this.title,
    required this.price,
    required this.startTime,
    required this.statusLabel,
    required this.lat,
    required this.lng,
    required this.images,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      creatorName: json['creator_name'] ?? 'Necunoscut',
      title: json['title'] ?? '',
      price: double.parse(json['price']?.toString() ?? '0'),
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : DateTime.now(),
      statusLabel: json['status_label'] ?? '—',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      images: (json['images'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
