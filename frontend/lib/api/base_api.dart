import 'package:flutter/foundation.dart';

/// Centralized base URL helper shared by API layers.
String get baseUrl {
  if (kIsWeb) {
    final base = Uri.base;
    final host = base.host.isNotEmpty ? base.host : 'localhost';
    final isLocal = host == 'localhost' || host == '127.0.0.1';
    if (isLocal) {
      return 'http://$host:3000';
    }
    final scheme = base.scheme.isNotEmpty ? base.scheme : 'https';
    return '$scheme://$host/api';
  }
  return 'http://localhost:3000';
}
