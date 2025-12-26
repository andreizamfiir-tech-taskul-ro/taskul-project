import 'package:flutter/foundation.dart';

/// Centralized base URL helper shared by API layers.
String get baseUrl {
  if (kIsWeb) {
    final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
    return 'http://$host:3000';
  }
  return 'http://localhost:3000';
}
