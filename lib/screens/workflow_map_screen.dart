import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../models/project.dart';
import '../services/task_service.dart';
import 'task_detail_screen.dart';

class WorkflowMapScreen extends StatefulWidget {
  final String taskId;

  const WorkflowMapScreen({super.key, required this.taskId});

  @override
  State<WorkflowMapScreen> createState() => _WorkflowMapScreenState();
}

class _WorkflowMapScreenState extends State<WorkflowMapScreen> {
  final _service = TaskService.instance;
  Project? _project;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    setState(() => _isLoading = true);
    final detail = await _service.fetchProjectDetail(widget.taskId);
    if (detail != null) {
      if (mounted) setState(() { _project = detail; _isLoading = false; });
      return;
    }
    final all = await _service.fetchProjects();
    final found = all.where((p) => p.id == widget.taskId).toList();
    if (mounted) {
      setState(() {
        _project = found.isNotEmpty ? found.first : null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.electricBlue))
            : _project == null
                ? const Center(child: Text('Project not found'))
                : Stack(
                    children: [
                      Column(
                        children: [
                          _buildHeader(),
                          Expanded(
                            child: _buildNodeGraph(),
                          ),
                        ],
                      ),
                      // Bottom sheet for active step
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildBottomSheet(),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft,
                border: Border.all(color: AppColors.surfaceGrey),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink),
            ),
          ),
          // Title
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🚀 ', style: TextStyle(fontSize: 20)),
                    Text(
                      _project!.title,
                      style: AppTypography.h2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_project!.stages.length} Stages • ${_project!.stages.where((s) => s.status == 'in_progress').length} Active',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          // Options Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: widget.taskId)),
              ).then((_) => _loadProject());
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppShadows.soft,
                border: Border.all(color: AppColors.surfaceGrey),
              ),
              child: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeGraph() {
    final stages = _project!.stages;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 260), // Space for bottom sheet
      itemCount: stages.length,
      itemBuilder: (context, index) {
        final stage = stages[index];
        final isLast = index == stages.length - 1;
        final nextStage = isLast ? null : stages[index + 1];

        return Column(
          children: [
            _buildNodeCard(stage),
            if (!isLast) _buildConnector(stage, nextStage!),
          ],
        );
      },
    );
  }

  Widget _buildNodeCard(Stage stage) {
    final isCompleted = stage.status == 'completed';
    final isActive = ['in_progress', 'ready', 'extended'].contains(stage.status);

    Color borderColor = AppColors.surfaceGrey;
    Color bgColor = Colors.white;
    Color titleColor = AppColors.ink;
    Color subtitleColor = AppColors.textSecondary;
    Color dotColor = AppColors.surfaceGrey;

    if (isCompleted) {
      borderColor = AppColors.emerald;
      dotColor = AppColors.emerald;
    } else if (isActive) {
      bgColor = AppColors.electricBlue;
      borderColor = AppColors.electricBlue;
      titleColor = Colors.white;
      subtitleColor = Colors.white70;
      dotColor = Colors.white;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: isActive ? AppShadows.glow(AppColors.electricBlue) : AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stage.title,
                style: AppTypography.h2.copyWith(color: titleColor),
              ),
              Icon(Icons.circle, size: 10, color: dotColor),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Avatar
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.emerald : (isActive ? Colors.white24 : AppColors.surfaceGrey),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stage.assignedUsers.isNotEmpty ? stage.assignedUserNames.first[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isCompleted ? Colors.white : (isActive ? Colors.white : AppColors.textTertiary),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${stage.assignedUsers.isNotEmpty ? stage.assignedUserNames.first : 'Unassigned'} • ${_formatStatus(stage.status)}',
                style: AppTypography.bodySmall.copyWith(color: subtitleColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(Stage current, Stage next) {
    final isActivePath = current.status == 'completed' || current.status == 'in_progress';
    return Container(
      height: 32,
      width: 2,
      color: isActivePath ? AppColors.electricBlue : AppColors.surfaceGrey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.arrow_drop_down, color: isActivePath ? AppColors.electricBlue : AppColors.surfaceGrey, size: 24),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    final activeStage = _service.getMyCurrentTask([_project!]) ?? _project!.currentStage;
    if (activeStage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${activeStage.title} Phase',
                style: AppTypography.h2,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatStatus(activeStage.status),
                  style: AppTypography.labelSmall.copyWith(color: AppColors.electricBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildTab('Info', true),
              const SizedBox(width: 16),
              _buildTab('Files', false),
              const SizedBox(width: 16),
              _buildTab('Chat', false),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Assigned', activeStage.assignedUserNames.isNotEmpty ? activeStage.assignedUserNames.first : 'Unassigned'),
          _buildInfoRow('Due Date', 'Today, 6 PM', valueColor: AppColors.warning), // Hardcoded for mockup match
          _buildInfoRow('Dependencies', 'Design ✓'), // Hardcoded for mockup match
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTypography.labelMedium.copyWith(
          color: isActive ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium),
          Text(
            value,
            style: AppTypography.labelMedium.copyWith(color: valueColor ?? AppColors.ink),
          ),
        ],
      ),
    );
  }

  String _formatStatus(String s) {
    if (s == 'in_progress') return 'In Progress';
    return s[0].toUpperCase() + s.substring(1);
  }
}
