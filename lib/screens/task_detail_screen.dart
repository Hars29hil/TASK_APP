import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'task_chat_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _task;
  bool _isLoading = true;
  bool _isCompleting = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  RealtimeChannel? _channel;

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

    if (Theme.of(context).platform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fetchTaskDetail();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _channel = _supabase
        .channel('task-detail-${widget.taskId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_steps',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'task_id',
            value: widget.taskId,
          ),
          callback: (_) => _fetchTaskDetail(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.taskId,
          ),
          callback: (_) => _fetchTaskDetail(),
        )
        .subscribe();
  }

  Future<void> _fetchTaskDetail() async {
    try {
      final resp = await http.get(
        Uri.parse('$_backendUrl/tasks/detail/${widget.taskId}'),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _task = data['task'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeStep(String stepId) async {
    setState(() => _isCompleting = true);
    try {
      final resp = await http.post(
        Uri.parse('$_backendUrl/tasks/${widget.taskId}/complete-step'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _currentUserId, 'step_id': stepId}),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        _fetchTaskDetail();
        if (data['task_completed'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🎉 Task Completed!"),
              backgroundColor: Color(0xFF34C759),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  bool _canCompleteStep(Map<String, dynamic> step) {
    if (step['status'] != 'active') return false;
    final assigned = step['assigned_users'] as List? ?? [];
    final isAssigned = assigned.any(
      (u) =>
          u['user_id'] == _currentUserId ||
          (u['profiles'] != null && u['profiles']['id'] == _currentUserId),
    );
    // Check if admin/leader
    final members = _task?['task_members'] as List? ?? [];
    final myMembership = members
        .where((m) => m['user_id'] == _currentUserId)
        .toList();
    final isPrivileged =
        myMembership.isNotEmpty &&
        (myMembership.first['role'] == 'admin' ||
            myMembership.first['role'] == 'leader');
    return isAssigned || isPrivileged;
  }

  double get _progress {
    final steps = _task?['task_steps'] as List? ?? [];
    if (steps.isEmpty) return 0;
    return steps.where((s) => s['status'] == 'completed').length / steps.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFF),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4A00E0)),
        ),
      );
    }
    if (_task == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text("Task not found")),
      );
    }

    final steps = _task!['task_steps'] as List? ?? [];
    final members = _task!['task_members'] as List? ?? [];
    final isCompleted = _task!['status'] == 'completed';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF4A00E0),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskChatScreen(
                        taskId: widget.taskId,
                        taskTitle: _task!['title'] ?? 'Task',
                      ),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _task!['title'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF34C759),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "✓ Done",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _priorityBadge(_task!['priority']),
                            const SizedBox(width: 10),
                            Text(
                              "${((_progress) * 100).toInt()}% complete",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          isCompleted
                              ? const Color(0xFF34C759)
                              : const Color(0xFF4A00E0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${steps.where((s) => s['status'] == 'completed').length}/${steps.length} steps completed",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),

                    // Description
                    if (_task!['description'] != null &&
                        _task!['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.description_rounded,
                              color: Color(0xFF4A00E0),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _task!['description'],
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Deadline
                    if (_task!['deadline'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              color: Color(0xFFFF9500),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Deadline: ${_formatDate(_task!['deadline'])}",
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Members
                    const SizedBox(height: 24),
                    const Text(
                      "Team Members",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: members.length,
                        itemBuilder: (ctx, i) {
                          final m = members[i];
                          final profile = m['profiles'];
                          final name = profile?['full_name'] ?? 'User';
                          final role = m['role'] ?? 'member';
                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: role == 'admin'
                                    ? const Color(
                                        0xFF8E2DE2,
                                      ).withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: NetworkImage(
                                    'https://i.pravatar.cc/150?u=${m['user_id']}',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name.toString().split(' ').first,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  role == 'admin'
                                      ? '👑'
                                      : role == 'leader'
                                      ? '⭐'
                                      : '👤',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // TIMELINE
                    const SizedBox(height: 24),
                    const Text(
                      "Workflow Timeline",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...steps.asMap().entries.map(
                      (e) => _buildTimelineStep(e.value, e.key, steps.length),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(Map<String, dynamic> step, int index, int total) {
    final status = step['status'] ?? 'pending';
    final isActive = status == 'active';
    final isDone = status == 'completed';
    final isLast = index == total - 1;
    final assigned = step['assigned_users'] as List? ?? [];
    final canComplete = _canCompleteStep(step);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline connector
        SizedBox(
          width: 40,
          child: Column(
            children: [
              // Node
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (ctx, child) {
                  return Container(
                    width: isActive ? 32 : 24,
                    height: isActive ? 32 : 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? const Color(0xFF34C759)
                          : isActive
                          ? const Color(0xFF4A00E0)
                          : Colors.grey[300],
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4A00E0).withValues(
                                  alpha: _pulseAnimation.value * 0.5,
                                ),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            )
                          : isActive
                          ? const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  );
                },
              ),
              // Line
              if (!isLast)
                Container(
                  width: 3,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDone
                          ? [
                              const Color(0xFF34C759),
                              const Color(0xFF34C759).withValues(alpha: 0.5),
                            ]
                          : [Colors.grey[300]!, Colors.grey[200]!],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Content card
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF4A00E0).withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF4A00E0).withValues(alpha: 0.3)
                    : isDone
                    ? const Color(0xFF34C759).withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4A00E0).withValues(alpha: 0.08),
                        blurRadius: 15,
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step['step_title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDone ? Colors.grey : const Color(0xFF1A1A2E),
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF34C759).withValues(alpha: 0.1)
                            : isActive
                            ? const Color(0xFF4A00E0).withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDone
                              ? const Color(0xFF34C759)
                              : isActive
                              ? const Color(0xFF4A00E0)
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                if (assigned.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: assigned.map<Widget>((a) {
                      final name = a['profiles']?['full_name'] ?? 'User';
                      return Chip(
                        avatar: CircleAvatar(
                          radius: 10,
                          backgroundImage: NetworkImage(
                            'https://i.pravatar.cc/150?u=${a['user_id']}',
                          ),
                        ),
                        label: Text(name, style: const TextStyle(fontSize: 10)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.grey[50],
                      );
                    }).toList(),
                  ),
                ],
                if (isDone && step['completed_at'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Completed: ${_formatDate(step['completed_at'])}",
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
                if (canComplete && !_isCompleting) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _completeStep(step['id']),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        "Mark as Complete",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A00E0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                if (_isCompleting && isActive)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _priorityBadge(String? p) {
    final color = switch (p) {
      'urgent' => const Color(0xFFFF3B30),
      'high' => const Color(0xFFFF9500),
      'low' => const Color(0xFF34C759),
      _ => const Color(0xFF007AFF),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        (p ?? 'medium').toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      return "${d.day}/${d.month}/${d.year}";
    } catch (_) {
      return iso;
    }
  }
}
