class Task {
  final int id;
  final int creatorId;
  final String creatorName;
  final String? assignedName;
  final int? assignedUserId;
  final String title;
  final double price;
  final DateTime startTime;
  final String statusLabel;
  final int statusId;
  final double lat;
  final double lng;
  final List<String> images;
  final String address;
  final String locationLabel;
  final String conciseAddress;
  final String locationLabelBackend;
  final String shortAddress;

  Task({
    required this.id,
    required this.creatorName,
    required this.title,
    required this.price,
    required this.startTime,
    required this.statusLabel,
    required this.statusId,
    this.assignedName,
    this.assignedUserId,
    required this.creatorId,
    required this.lat,
    required this.lng,
    this.images = const [],
    this.address = 'Adresa nespecificata',
    required this.locationLabel,
    required this.conciseAddress,
    this.locationLabelBackend = '',
    required this.shortAddress,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    final latValue = json['lat'] as num?;
    final lngValue = json['lng'] as num?;
    String resolvedAddress = json['address']?.toString() ?? 'Adresa nespecificata';
    if (resolvedAddress == 'Adresa nespecificata' &&
        latValue != null &&
        lngValue != null) {
      resolvedAddress =
          'Lat ${latValue.toStringAsFixed(3)}, Lng ${lngValue.toStringAsFixed(3)}';
    }

    String deriveLocationLabel() {
      final lower = resolvedAddress.toLowerCase();
      final parts = resolvedAddress
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // If we only had coords (Lat/Lng) as address, derive from bounding box.
      final lat = (latValue ?? 44.4268).toDouble();
      final lng = (lngValue ?? 26.1025).toDouble();
      final coordsOnly = lower.startsWith('lat ') || lower.contains('lng');

      // Heuristic for Bucuresti / Ilfov
      if (lower.contains('bucuresti') || lower.contains('sector')) {
        // Try to keep sector if present
        final sector = parts.firstWhere(
          (p) => p.toLowerCase().contains('sector'),
          orElse: () => '',
        );
        return sector.isNotEmpty ? 'Bucuresti, $sector' : 'Bucuresti';
      }
      if (lower.contains('ilfov')) {
        // Try to extract locality before Ilfov
        final ilfovIndex =
            parts.indexWhere((p) => p.toLowerCase().contains('ilfov'));
        if (ilfovIndex > 0) {
          return '${parts[ilfovIndex - 1]}, Ilfov';
        }
        return 'Ilfov';
      }

      // Generic: use last two parts (city, county)
      if (parts.length >= 2 && !coordsOnly) {
        return '${parts[parts.length - 2]}, ${parts.last}';
      }
      if (parts.isNotEmpty && !coordsOnly) return parts.first;

      // Fallback to coords area
      final isBucharest = lat >= 44.2 && lat <= 44.6 && lng >= 25.9 && lng <= 26.3;
      // Simple Ilfov bounding box around Bucharest
      final isIlfov = !isBucharest &&
          lat >= 44.0 &&
          lat <= 44.8 &&
          lng >= 25.6 &&
          lng <= 26.6;
      if (isBucharest) return 'Bucuresti';
      if (isIlfov) return 'Ilfov';
      return 'Romania';
    }

    final backendLocationLabel = json['location_label']?.toString();
    final locationLabel = backendLocationLabel ?? deriveLocationLabel();
    final bool coordsOnly =
        resolvedAddress.toLowerCase().contains('lat') &&
        resolvedAddress.toLowerCase().contains('lng');

    final concise = coordsOnly
        ? locationLabel
        : _buildConciseAddress(resolvedAddress);
    final shortAddress = coordsOnly
        ? locationLabel
        : _buildShortAddress(resolvedAddress, locationLabel);

    return Task(
      id: json['id'],
      creatorId: json['creator_id'] is int
          ? json['creator_id'] as int
          : int.tryParse(json['creator_id']?.toString() ?? '0') ?? 0,
      creatorName: json['creator_name'] ?? 'Necunoscut',
      assignedName: json['assigned_name']?.toString(),
      assignedUserId: json['assigned_user_id'] as int?,
      title: json['title'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : DateTime.now(),
      statusLabel: json['status_label'] ?? '-',
      statusId: json['status_id'] is int ? json['status_id'] as int : 0,
      lat: (latValue ?? 44.4268).toDouble(),
      lng: (lngValue ?? 26.1025).toDouble(),
      images: (json['images'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      address: resolvedAddress,
      locationLabel: locationLabel,
      conciseAddress: concise,
      locationLabelBackend: backendLocationLabel ?? '',
      shortAddress: shortAddress,
    );
  }

  static String _buildConciseAddress(String address) {
    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return address;
    // Keep first two parts for concise display
    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    return parts.first;
  }

  static String _buildShortAddress(String address, String fallback) {
    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return fallback;

    final seen = <String>{};
    final unique = <String>[];
    for (final p in parts) {
      final lower = p.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        unique.add(p);
      }
      if (unique.length >= 4) break;
    }
    if (unique.isEmpty) return fallback;

    final street = unique.first;
    String city = '';
    // try to find a city-like part
    for (final item in unique.skip(1)) {
      final lower = item.toLowerCase();
      if (lower.contains('bucure') || lower.contains('ilfov')) {
        city = item;
        break;
      }
      if (city.isEmpty) {
        city = item;
      }
    }

    final out = [
      if (street.isNotEmpty) street,
      if (city.isNotEmpty) city,
    ].join(', ');
    return out.isNotEmpty ? out : fallback;
  }
}
