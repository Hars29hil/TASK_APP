import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../models/project.dart';

import '../services/task_service.dart';
import 'workflow_map_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          color: AppColors.electricBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 80, 100), // Right padding for dock
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildYourTurnCard(),
                const SizedBox(height: 40),
                Text(
                  'WORKFLOW RADAR',
                  style: AppTypography.labelMedium.copyWith(
                    letterSpacing: 1.2,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                _buildWorkflowRadar(),
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
            color: AppColors.highlight,
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

  Widget _buildYourTurnCard() {
    final service = TaskService.instance;
    final currentStage = service.getMyCurrentTask(widget.projects);
    final currentProject = service.getMyCurrentProject(widget.projects);

    if (currentStage == null || currentProject == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 48),
            const SizedBox(height: 16),
            Text('All caught up!', style: AppTypography.h3.copyWith(color: Colors.white)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.medium,
        gradient: LinearGradient(
          colors: [AppColors.ink, const Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.electricBlue,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, color: Colors.white, size: 8),
                const SizedBox(width: 6),
                Text(
                  'YOUR TURN NOW',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            currentStage.title,
            style: AppTypography.h1.copyWith(color: Colors.white, fontSize: 28),
          ),
          const SizedBox(height: 8),
          Text(
            '${currentProject.title} • Step ${currentStage.stepNumber}',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (currentStage.deadline != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.warning),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.warning, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _formatDeadline(currentStage.deadline!),
                        style: AppTypography.labelMedium.copyWith(color: AppColors.warning),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WorkflowMapScreen(taskId: currentProject.id)),
                  ).then((_) => widget.onRefresh());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Text('Open Task', style: AppTypography.button.copyWith(color: Colors.white)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowRadar() {
    // Collect all stages across projects
    List<Map<String, dynamic>> radarItems = [];
    for (final p in widget.projects) {
      for (final s in p.stages) {
        radarItems.add({'project': p, 'stage': s});
      }
    }
    
    // Take first 5 items to mimic the UI screenshot
    radarItems = radarItems.take(5).toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: radarItems.map((item) {
          final p = item['project'] as Project;
          final s = item['stage'] as Stage;
          return _buildRadarItem(s, p);
        }).toList(),
      ),
    );
  }

  Widget _buildRadarItem(Stage stage, Project project) {
    IconData iconData;
    Color iconBgColor;
    Color iconColor = Colors.white;

    if (stage.status == 'completed') {
      iconData = Icons.check_rounded;
      iconBgColor = AppColors.emerald.withValues(alpha: 0.15);
      iconColor = AppColors.emerald;
    } else if (stage.status == 'in_progress' || stage.status == 'extended') {
      iconData = Icons.play_arrow_rounded;
      iconBgColor = AppColors.electricBlue;
    } else {
      iconData = Icons.circle; // Just a placeholder, we use text
      iconBgColor = AppColors.surfaceGrey;
      iconColor = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Left Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: stage.status == 'pending' || stage.status == 'blocked'
                  ? Text('${stage.stepNumber}', style: TextStyle(color: iconColor, fontWeight: FontWeight.bold))
                  : Icon(iconData, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.title, style: AppTypography.labelLarge.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${stage.assignedUserNames.join(', ')} • ${_formatStatus(stage.status)}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          // Status pill on the right
          _buildRightPill(stage),
        ],
      ),
    );
  }

  Widget _buildRightPill(Stage stage) {
    if (stage.status == 'completed') {
      return Text('Done', style: AppTypography.labelMedium.copyWith(color: AppColors.emerald));
    }
    if (stage.status == 'in_progress') {
      return Text('Active', style: AppTypography.labelMedium.copyWith(color: AppColors.electricBlue));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('Queue', style: AppTypography.labelSmall),
    );
  }

  String _formatStatus(String s) {
    if (s == 'in_progress') return 'In review';
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  String _formatDeadline(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return 'Overdue';
    if (diff.inHours < 24) return 'Due in ${diff.inHours} Hours';
    return 'Due in ${diff.inDays} Days';
  }
}
