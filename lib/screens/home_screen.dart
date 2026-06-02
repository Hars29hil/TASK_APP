import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../models/project.dart';

import '../services/task_service.dart';
import 'task_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Project> projects;
  final bool isLoading;
  final VoidCallback onRefresh;

  const HomeScreen({
    super.key,
    required this.projects,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await TaskService.instance.getCurrentProfile();
    if (profile != null && mounted) {
      setState(() {
        _userName = profile['full_name'] ?? profile['email']?.toString().split('@')[0] ?? 'User';
      });
    }
  }

  int get _activeProjectsCount => widget.projects.where((p) => !p.isCompleted).length;
  int get _completedProjectsCount => widget.projects.where((p) => p.isCompleted).length;

  List<Project> get _recentProjects {
    final active = widget.projects.where((p) => !p.isCompleted).toList();
    // Assuming we want the first 3
    return active.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          color: AppColors.electricBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildStatsRow(),
                const SizedBox(height: 32),
                Text(
                  'Recent Active Tasks',
                  style: AppTypography.h3,
                ),
                const SizedBox(height: 16),
                _buildRecentTasks(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning,\n${_userName.isNotEmpty ? _userName : 'User'}',
                style: AppTypography.h1,
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrentDate(),
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.electricBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Active Tasks',
            count: _activeProjectsCount.toString(),
            icon: Icons.play_circle_outline_rounded,
            color: AppColors.electricBlue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Completed',
            count: _completedProjectsCount.toString(),
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.emerald,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            count,
            style: AppTypography.h2.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasks() {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.electricBlue));
    }
    
    if (_recentProjects.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.done_all_rounded, color: AppColors.emerald, size: 48),
            const SizedBox(height: 16),
            Text('All caught up!', style: AppTypography.h3),
            const SizedBox(height: 8),
            Text('No active tasks at the moment.', style: AppTypography.bodySmall),
          ],
        ),
      );
    }

    return Column(
      children: _recentProjects.map((project) => _buildSimpleTaskCard(project)).toList(),
    );
  }

  Widget _buildSimpleTaskCard(Project project) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: project.id)),
        ).then((_) => widget.onRefresh());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.blueDim,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.folder_outlined, color: AppColors.electricBlue),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: AppTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step ${project.completedStageCount}/${project.stages.length} • ${project.currentStepLabel}',
                    style: AppTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }
}
