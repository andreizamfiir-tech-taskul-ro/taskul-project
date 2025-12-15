import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

Future<List<Task>> fetchTasks() async {
  final res = await http.get(
    Uri.parse('http://localhost:3000/tasks'),
  );

  if (res.statusCode == 200) {
    final List data = jsonDecode(res.body);
    return data.map((e) => Task.fromJson(e)).toList();
  } else {
    throw Exception('Backend-ul a zis nu');
  }
}

// 🔹 ACCEPT TASK (mock)
Future<void> acceptTaskApi(int taskId) async {
  await http.post(
    Uri.parse('http://localhost:3000/tasks/$taskId/accept'),
  );
}

// 🔹 REFUZ TASK (mock)
Future<void> refuseTaskApi(int taskId) async {
  await http.post(
    Uri.parse('http://localhost:3000/tasks/$taskId/refuse'),
  );
}
