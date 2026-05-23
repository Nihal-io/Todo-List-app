import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/task.dart';

/// Persists the user's tasks as a single JSON file in the platform
/// application-support directory. Chosen over Drift because it avoids
/// requiring `build_runner` codegen and is trivially debuggable on disk.
///
/// File layout: `<appSupportDir>/todo_list/tasks_v1.json`
class TaskRepository {
  TaskRepository({this.fileName = 'tasks_v1.json'});

  final String fileName;
  File? _cachedFile;

  /// Serialises [save] calls so concurrent writes do not corrupt the file.
  Future<void> _writeChain = Future<void>.value();

  Future<File> _file() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationSupportDirectory();
    final folder = Directory(p.join(dir.path, 'todo_list'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    _cachedFile = File(p.join(folder.path, fileName));
    return _cachedFile!;
  }

  /// Returns the persisted task list, or `null` when the file does not yet
  /// exist (caller should seed with samples).
  Future<List<Task>?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return <Task>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Task>[];
      final tasks = <Task>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            tasks.add(Task.fromJson(item));
          } catch (_) {
            // Skip corrupt entries rather than discarding the whole file.
          }
        } else if (item is Map) {
          try {
            tasks.add(Task.fromJson(item.cast<String, dynamic>()));
          } catch (_) {}
        }
      }
      return tasks;
    } catch (_) {
      return null;
    }
  }

  /// Writes [tasks] atomically. Writes are queued so callers can fire-and-
  /// forget without risking interleaved file contents.
  Future<void> save(List<Task> tasks) {
    final next = _writeChain.then((_) => _doSave(tasks));
    _writeChain = next.catchError((_) {});
    return next;
  }

  Future<void> _doSave(List<Task> tasks) async {
    final f = await _file();
    final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(encoded, flush: true);
    if (await f.exists()) {
      await f.delete();
    }
    await tmp.rename(f.path);
  }

  Future<void> deleteAll() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
