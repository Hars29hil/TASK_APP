import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../models/project.dart';
import '../services/task_service.dart';
import 'chat_detail_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
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
    if (_isLoading) {
      return _buildSkeleton();
    }

    if (_project == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('Not found', style: TextStyle(color: AppColors.ink))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildTopHeader(),
                _buildBottomCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nav Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Text('Spaces', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 32),
          const Text('🚀', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 16),
          Text(
            _project!.title,
            style: AppTypography.h1,
          ),
          const SizedBox(height: 8),
          Text(
            '${_project!.description ?? 'Task'} • ${_project!.stages.length} stages${_project!.deadline != null ? ' • Due ${_formatDate(_project!.deadline!)}' : ''}',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 24),
          // Avatars
          Row(
            children: [
              if (_project!.members.isEmpty)
                Text('No members assigned', style: AppTypography.bodySmall)
              else ...[
                ..._project!.members.take(4).map((member) {
                  final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
                  final colors = [Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.teal, Colors.red, Colors.indigo];
                  final color = colors[member.name.hashCode % colors.length];
                  return _buildAvatar(initial, color);
                }),
                if (_project!.members.length > 4) ...[
                  const SizedBox(width: 12),
                  Text('+${_project!.members.length - 4} members', style: AppTypography.bodySmall),
                ],
              ],
            ],
          ),
          const SizedBox(height: 24),
          _buildChatOverlay(),
        ],
      ),
    );
  }

  Widget _buildAvatar(String letter, Color color) {
    return Align(
      widthFactor: 0.75,
      alignment: Alignment.centerLeft,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bg, width: 2),
        ),
        child: Center(
          child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Mock Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            color: AppColors.bg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_back, color: AppColors.surfaceGrey, size: 20),
                        const SizedBox(width: 8),
                        Container(
                          width: 60,
                          height: 14,
                          decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                    const Icon(Icons.more_horiz, color: AppColors.surfaceGrey),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.surfaceGrey, shape: BoxShape.circle),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 150,
                  height: 16,
                  decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 24),
                // Mock Avatars
                Row(
                  children: [
                    for (int i = 0; i < 4; i++)
                      Align(
                        widthFactor: 0.75,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGrey,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.bg, width: 2),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Container(
                      width: 80,
                      height: 14,
                      decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Mock Bottom Card
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.bg,
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              child: Column(
                children: [
                  for (int i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.all(Radius.circular(16))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  height: 16,
                                  decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(4)),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 120,
                                  height: 12,
                                  decoration: BoxDecoration(color: AppColors.surfaceGrey, borderRadius: BorderRadius.circular(4)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          children: _project!.stages.map((s) => _buildStageItem(s)).toList(),
        ),
      ),
    );
  }

  Widget _buildChatOverlay() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              roomId: _project!.id,
              roomType: 'project',
              roomName: '${_project!.title} Team Chat',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.medium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Team Chat', style: AppTypography.labelMedium),
                      Text('Open', style: AppTypography.labelMedium.copyWith(color: AppColors.electricBlue)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        child: const Center(child: Text('H', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pushed the design files to Figma ✅',
                          style: AppTypography.textXs.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageItem(Stage stage) {
    final isCompleted = stage.status == 'completed';
    final isActive = ['ready', 'in_progress', 'extended'].contains(stage.status);

    Color bg;
    Color iconColor;
    IconData icon;
    String rightTextTop;
    String rightTextBottom;
    Color rightTextColor;

    if (isCompleted) {
      bg = AppColors.emerald.withValues(alpha: 0.1);
      iconColor = AppColors.emerald;
      icon = Icons.check_box_rounded;
      rightTextTop = stage.deadline != null ? _formatDate(stage.deadline!) : '';
      rightTextBottom = 'Done';
      rightTextColor = AppColors.emerald;
    } else if (isActive) {
      bg = AppColors.electricBlue.withValues(alpha: 0.1);
      iconColor = AppColors.electricBlue;
      icon = Icons.bolt_rounded;
      rightTextTop = stage.deadline != null ? _formatDate(stage.deadline!) : '';
      rightTextBottom = stage.startedAt != null ? _timeLeft(stage) : 'Active';
      rightTextColor = AppColors.electricBlue;
    } else {
      bg = AppColors.surfaceGrey;
      iconColor = AppColors.textTertiary;
      icon = Icons.stop_rounded;
      rightTextTop = stage.deadline != null ? _formatDate(stage.deadline!) : '';
      rightTextBottom = '${stage.durationDays}d';
      rightTextColor = AppColors.textTertiary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? AppColors.electricBlue.withValues(alpha: 0.3) : AppColors.surfaceGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stage.title, style: AppTypography.labelLarge.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '${stage.assignedUsers.isNotEmpty ? stage.assignedUserNames.first : 'Unassigned'} • ${isCompleted ? '3 deliverables' : isActive ? '72% done' : 'Not started'}', // Mock details
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rightTextTop, style: AppTypography.bodySmall),
              const SizedBox(height: 4),
              Text(
                rightTextBottom,
                style: AppTypography.labelMedium.copyWith(color: rightTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _timeLeft(Stage stage) {
    if (stage.deadline != null) {
      final diff = stage.deadline!.difference(DateTime.now());
      if (diff.isNegative) return 'Overdue';
      if (diff.inDays == 0) return 'Today';
      return '${diff.inDays}d left';
    }
    return 'Active';
  }
}
