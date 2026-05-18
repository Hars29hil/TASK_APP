import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String _filter = 'all';
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  RealtimeChannel? _taskChannel;

  String get _backendUrl {
    if (kIsWeb) {
      final envUrl = dotenv.maybeGet('BACKEND_URL');
      if (envUrl != null && envUrl.contains('http') && !envUrl.contains('10.0.2.2')) {
        return envUrl;
      }
      return 'http://localhost:5000';
    }

    final envUrl = dotenv.maybeGet('BACKEND_URL');
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    
    if (Theme.of(context).platform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600), vsync: this,
    );
    _fabAnimation = CurvedAnimation(parent: _fabController, curve: Curves.elasticOut);
    _fabController.forward();
    _fetchTasks();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _taskChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _taskChannel = _supabase.channel('task-updates')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'tasks', callback: (_) => _fetchTasks())
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'task_steps', callback: (_) => _fetchTasks())
      .subscribe();
  }

  Future<void> _fetchTasks() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final resp = await http.get(Uri.parse('$_backendUrl/tasks/$userId'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true && mounted) {
          setState(() { _tasks = List<Map<String, dynamic>>.from(data['tasks']); _isLoading = false; });
        }
      } else { if (mounted) setState(() => _isLoading = false); }
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTasks {
    if (_filter == 'all') return _tasks;
    return _tasks.where((t) => t['status'] == _filter).toList();
  }

  int get _activeTasks => _tasks.where((t) => t['status'] == 'active').length;
  int get _completedTasks => _tasks.where((t) => t['status'] == 'completed').length;

  double _getProgress(Map<String, dynamic> task) {
    final steps = task['task_steps'] as List? ?? [];
    if (steps.isEmpty) return 0;
    return steps.where((s) => s['status'] == 'completed').length / steps.length;
  }

  String _getCurrentStep(Map<String, dynamic> task) {
    final steps = task['task_steps'] as List? ?? [];
    final active = steps.where((s) => s['status'] == 'active').toList();
    if (active.isNotEmpty) return active.first['step_title'] ?? '';
    return task['status'] == 'completed' ? 'All completed' : 'Not started';
  }

  Color _priorityColor(String? p) => switch (p) {
    'urgent' => const Color(0xFFFF3B30), 'high' => const Color(0xFFFF9500),
    'low' => const Color(0xFF34C759), _ => const Color(0xFF007AFF),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(children: [
              _buildHeader(),
              _buildStats(),
              _buildFilters(),
              Expanded(child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A00E0)))
                : _filteredTasks.isEmpty ? _buildEmpty() : _buildList()),
            ]),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90), // Lifted to avoid nav bar
        child: ScaleTransition(
          scale: _fabAnimation,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen()));
              if (result == true) _fetchTasks();
            },
            backgroundColor: const Color(0xFF4A00E0),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text("New Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Task Center", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        Text("${_tasks.length} tasks · $_activeTasks active", style: TextStyle(fontSize: 14, color: Colors.grey[500])),
      ]),
    ]),
  );

  Widget _buildStats() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
    child: Row(children: [
      _miniStat("Active", _activeTasks, const Color(0xFF6366F1), Icons.bolt_rounded),
      const SizedBox(width: 12),
      _miniStat("Done", _completedTasks, const Color(0xFF10B981), Icons.check_circle_rounded),
      const SizedBox(width: 12),
      _miniStat("Total", _tasks.length, const Color(0xFFF59E0B), Icons.folder_rounded),
    ]),
  );

  Widget _miniStat(String label, int count, Color c, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: c.withValues(alpha: 0.05)),
      ),
      child: Column(children: [
        Icon(icon, size: 16, color: c.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
        Text("$count", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
      ]),
    ),
  );

  Widget _buildFilters() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
    child: Row(children: [
      _chip("All", 'all'), const SizedBox(width: 8),
      _chip("Active", 'active'), const SizedBox(width: 8),
      _chip("Completed", 'completed'),
    ]),
  );

  Widget _chip(String label, String value) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF4A00E0) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: sel ? [BoxShadow(color: const Color(0xFF4A00E0).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.task_alt_rounded, size: 80, color: const Color(0xFF4A00E0).withValues(alpha: 0.2)),
    const SizedBox(height: 20),
    const Text("No tasks yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text("Create your first task!", style: TextStyle(color: Colors.grey[500])),
    const SizedBox(height: 80),
  ]));

  Widget _buildList() => RefreshIndicator(
    onRefresh: _fetchTasks, color: const Color(0xFF4A00E0),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.8,
            ),
            itemCount: _filteredTasks.length,
            itemBuilder: (ctx, i) => _taskCard(_filteredTasks[i]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          itemCount: _filteredTasks.length,
          itemBuilder: (ctx, i) => _taskCard(_filteredTasks[i]),
        );
      },
    ),
  );

  Widget _taskCard(Map<String, dynamic> task) {
    final progress = _getProgress(task);
    final steps = task['task_steps'] as List? ?? [];
    final done = steps.where((s) => s['status'] == 'completed').length;
    final isDone = task['status'] == 'completed';
    final role = task['my_role'];

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task['id'])));
        _fetchTasks();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: (isDone ? const Color(0xFF34C759) : const Color(0xFF4A00E0)).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))],
          border: isDone ? Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.2)) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(task['title'] ?? 'Untitled', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _priorityColor(task['priority']).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text((task['priority'] ?? 'medium').toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _priorityColor(task['priority']))),
            ),
          ]),
          if (role == 'admin' || role == 'leader') ...[
            const SizedBox(height: 4),
            Text(role == 'admin' ? '👑 Admin' : '⭐ Leader', style: const TextStyle(fontSize: 11, color: Color(0xFF8E2DE2))),
          ],
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey[100], valueColor: AlwaysStoppedAnimation(isDone ? const Color(0xFF34C759) : const Color(0xFF4A00E0)))),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(isDone ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded, size: 16, color: isDone ? const Color(0xFF34C759) : const Color(0xFF4A00E0)),
              const SizedBox(width: 6),
              Text(_getCurrentStep(task), style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ]),
            Text("$done/${steps.length} steps", style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}
