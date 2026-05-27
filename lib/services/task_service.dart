import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';

/// Centralized service for all task/project API calls.
/// Eliminates duplicated _backendUrl logic across screens.
class TaskService {
  TaskService._();
  static final TaskService instance = TaskService._();

  final _supabase = Supabase.instance.client;

  String get _backendUrl {
    if (kIsWeb) {
      final envUrl = dotenv.maybeGet('BACKEND_URL');
      if (envUrl != null &&
          envUrl.contains('http') &&
          !envUrl.contains('10.0.2.2')) {
        return envUrl;
      }
      return 'http://localhost:5000';
    }
    final envUrl = dotenv.maybeGet('BACKEND_URL');
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    // Android emulator
    return 'http://10.0.2.2:5000';
  }

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  /// Fetch all projects for a user
  Future<List<Project>> fetchProjects() async {
    final userId = currentUserId;
    if (userId.isEmpty) return [];
    try {
      final resp = await http.get(Uri.parse('$_backendUrl/tasks/$userId'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) {
          final tasks = data['tasks'] as List? ?? [];
          return tasks
              .map((t) => Project.fromMap(t as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('TaskService.fetchProjects error: $e');
    }
    return [];
  }

  /// Fetch a single project detail
  Future<Project?> fetchProjectDetail(String taskId) async {
    final userId = currentUserId;
    if (userId.isEmpty) return null;
    try {
      final resp =
          await http.get(Uri.parse('$_backendUrl/tasks/detail/$taskId'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true && data['task'] != null) {
          return Project.fromMap(data['task'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('TaskService.fetchProjectDetail error: $e');
    }
    return null;
  }

  /// Get the user's current actionable task (for "Your Turn" card)
  Stage? getMyCurrentTask(List<Project> projects) {
    for (final project in projects) {
      for (final stage in project.stages) {
        if (['ready', 'in_progress', 'extended'].contains(stage.status) &&
            stage.isAssignedTo(currentUserId)) {
          return stage;
        }
      }
    }
    return null;
  }

  /// Get the project that contains the current task
  Project? getMyCurrentProject(List<Project> projects) {
    for (final project in projects) {
      for (final stage in project.stages) {
        if (['ready', 'in_progress', 'extended'].contains(stage.status) &&
            stage.isAssignedTo(currentUserId)) {
          return project;
        }
      }
    }
    return null;
  }

  /// Start a step
  Future<Map<String, dynamic>> startStep(String taskId, String stepId) async {
    return _postAction('$_backendUrl/tasks/$taskId/steps/$stepId/start', {
      'user_id': currentUserId,
    });
  }

  /// Complete a step
  Future<Map<String, dynamic>> completeStep(
      String taskId, String stepId) async {
    return _postAction('$_backendUrl/tasks/$taskId/complete-step', {
      'user_id': currentUserId,
      'step_id': stepId,
    });
  }

  /// Request extension
  Future<Map<String, dynamic>> requestExtension(
    String taskId,
    String stepId,
    int days,
    String reason,
  ) async {
    return _postAction(
        '$_backendUrl/tasks/$taskId/steps/$stepId/request-extension', {
      'user_id': currentUserId,
      'days_requested': days,
      'reason': reason,
    });
  }

  /// Block a step
  Future<Map<String, dynamic>> blockStep(
    String taskId,
    String stepId,
    String reason,
  ) async {
    return _postAction('$_backendUrl/tasks/$taskId/steps/$stepId/block', {
      'user_id': currentUserId,
      'reason': reason,
    });
  }

  /// Unblock a step
  Future<Map<String, dynamic>> unblockStep(
      String taskId, String stepId) async {
    return _postAction('$_backendUrl/tasks/$taskId/steps/$stepId/unblock', {
      'user_id': currentUserId,
    });
  }

  /// Fetch extension requests
  Future<List<Map<String, dynamic>>> fetchExtensionRequests(
      String taskId) async {
    try {
      final resp = await http
          .get(Uri.parse('$_backendUrl/tasks/$taskId/extension-requests'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['extensions'] ?? []);
        }
      }
    } catch (e) {
      debugPrint('TaskService.fetchExtensionRequests error: $e');
    }
    return [];
  }

  /// Resolve extension (approve / reject)
  Future<Map<String, dynamic>> resolveExtension(
    String taskId,
    String extensionId,
    String status,
  ) async {
    return _postAction(
        '$_backendUrl/tasks/$taskId/extensions/$extensionId/resolve', {
      'user_id': currentUserId,
      'status': status,
    });
  }

  /// Get current user profile
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final userId = currentUserId;
    if (userId.isEmpty) return null;
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('TaskService.getCurrentProfile error: $e');
    }
    return null;
  }

  // ── Internal ──

  Future<Map<String, dynamic>> _postAction(
      String url, Map<String, dynamic> body) async {
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('TaskService._postAction error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
