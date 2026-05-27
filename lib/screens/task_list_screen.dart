import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../components/avatar_widget.dart';
import '../components/badge_chip.dart';
import '../components/progress_bar.dart';
import '../components/filter_chip_widget.dart';
import '../models/project.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _supabase = Supabase.instance.client;
  List<Project> _projects = [];
  bool _isLoading = true;
  String _filter = 'all';
  RealtimeChannel? _taskChannel;

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
    return 'http://10.0.2.2:5000';
  }

  @override
  void initState() {
    super.initState();
    _fetchTasks();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _taskChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _taskChannel = _supabase
        .channel('task-list-updates')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tasks',
            callback: (_) => _fetchTasks())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'task_steps',
            callback: (_) => _fetchTasks())
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
          final tasks = (data['tasks'] as List? ?? [])
              .map((t) => Project.fromMap(t as Map<String, dynamic>))
              .toList();
          setState(() {
            _projects = tasks;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Project> get _filteredProjects {
    if (_filter == 'all') return _projects;
    if (_filter == 'active') {
      return _projects.where((p) => p.status != 'completed').toList();
    }
    return _projects.where((p) => p.status == _filter).toList();
  }

  int get _activeCount =>
      _projects.where((p) => p.status != 'completed').length;
  int get _completedCount =>
      _projects.where((p) => p.status == 'completed').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.electricBlue))
                  : _filteredProjects.isEmpty
                      ? _buildEmpty()
                      : _buildProjectList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spaces', style: AppTypography.h1),
              const SizedBox(height: 4),
              Text(
                '${_projects.length} projects · $_activeCount active',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
              );
              if (result == true) _fetchTasks();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text('New',
                      style: AppTypography.button
                          .copyWith(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChipWidget(
              label: 'All',
              isActive: _filter == 'all',
              count: _projects.length,
              onTap: () => setState(() => _filter = 'all'),
            ),
            const SizedBox(width: 8),
            FilterChipWidget(
              label: 'Active',
              isActive: _filter == 'active',
              count: _activeCount,
              onTap: () => setState(() => _filter = 'active'),
            ),
            const SizedBox(width: 8),
            FilterChipWidget(
              label: 'Completed',
              isActive: _filter == 'completed',
              count: _completedCount,
              onTap: () => setState(() => _filter = 'completed'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 64,
            color: AppColors.electricBlue.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text('No projects yet', style: AppTypography.h3),
          const SizedBox(height: 8),
          Text('Create your first project!', style: AppTypography.bodyMedium),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    return RefreshIndicator(
      onRefresh: _fetchTasks,
      color: AppColors.electricBlue,
      backgroundColor: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth > 1000 ? 3 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: _filteredProjects.length,
              itemBuilder: (ctx, i) => _buildProjectCard(_filteredProjects[i]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: _filteredProjects.length,
            itemBuilder: (ctx, i) => _buildProjectCard(_filteredProjects[i]),
          );
        },
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: project.id),
          ),
        );
        _fetchTasks();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: project.isCompleted
                ? AppColors.emerald.withValues(alpha: 0.2)
                : AppColors.surfaceGrey,
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Priority
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: AppTypography.labelLarge.copyWith(
                      fontSize: 15,
                      decoration: project.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: project.isCompleted
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                PriorityChip(priority: project.priority),
              ],
            ),
            // Role badge
            if (project.myRole == 'admin' || project.myRole == 'leader') ...[
              const SizedBox(height: 6),
              RoleBadge(role: project.myRole!),
            ],
            const SizedBox(height: 12),
            // Progress bar
            GradientProgressBar(
              progress: project.progress,
              startColor: project.isCompleted
                  ? AppColors.emerald
                  : null,
              endColor: project.isCompleted
                  ? AppColors.emerald.withValues(alpha: 0.6)
                  : null,
            ),
            const SizedBox(height: 10),
            // Bottom row: current step + step count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        project.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_fill_rounded,
                        size: 14,
                        color: project.isCompleted
                            ? AppColors.emerald
                            : AppColors.electricBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          project.currentStepLabel,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Team avatars
                if (project.members.isNotEmpty) ...[
                  AvatarStack(
                    imageUrls:
                        project.members.take(3).map((m) => m.avatarUrl).toList(),
                    names:
                        project.members.take(3).map((m) => m.name).toList(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${project.completedStageCount}/${project.stages.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
