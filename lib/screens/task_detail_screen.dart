import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../models/project.dart';
import '../services/task_service.dart';

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
        backgroundColor: Color(0xFF0F265C),
        body: Center(child: Text('Not found', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F265C), // Dark blue
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
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: _buildChatOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F265C), Color(0xFF1E3A8A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
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
                    const Icon(Icons.arrow_back, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text('Spaces', style: AppTypography.bodyMedium.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.horizontal_rule_rounded, color: Colors.white54), // Close/minimize icon
            ],
          ),
          const SizedBox(height: 32),
          const Text('🚀', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 16),
          Text(
            _project!.title,
            style: AppTypography.h1.copyWith(color: Colors.white, fontSize: 36),
          ),
          const SizedBox(height: 8),
          Text(
            'Mobile App • ${_project!.stages.length} stages • Due Jun 15', // Hardcoded subtitle match
            style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          // Avatars
          Row(
            children: [
              if (_project!.members.isEmpty)
                Text('No members assigned', style: AppTypography.bodySmall.copyWith(color: Colors.white70))
              else ...[
                ..._project!.members.take(4).map((member) {
                  final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
                  final colors = [Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.teal, Colors.red, Colors.indigo];
                  final color = colors[member.name.hashCode % colors.length];
                  return _buildAvatar(initial, color);
                }),
                if (_project!.members.length > 4) ...[
                  const SizedBox(width: 12),
                  Text('+${_project!.members.length - 4} members', style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
                ],
              ],
            ],
          ),
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
          border: Border.all(color: const Color(0xFF0F265C), width: 2),
        ),
        child: Center(
          child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F265C),
      body: Column(
        children: [
          // Mock Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F265C), Color(0xFF1E3A8A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_back, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Container(
                          width: 60,
                          height: 14,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                        ),
                      ],
                    ),
                    const Icon(Icons.horizontal_rule_rounded, color: Colors.white54),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 150,
                  height: 16,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
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
                            color: Colors.white24,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0F265C), width: 2),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Container(
                      width: 80,
                      height: 14,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
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
                color: AppColors.warmWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                            decoration: const BoxDecoration(color: Colors.black12, shape: BoxShape.circle),
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
                                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 120,
                                  height: 12,
                                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
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
        color: AppColors.warmWhite,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textTertiary, size: 16),
                  const SizedBox(width: 8),
                  Text('Team Chat', style: AppTypography.labelMedium),
                ],
              ),
              Text('Open', style: AppTypography.labelMedium.copyWith(color: AppColors.electricBlue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAvatar('H', Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pushed the design files to Figma ✅',
                  style: AppTypography.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
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
      rightTextTop = 'May 10'; // Mock
      rightTextBottom = 'Done';
      rightTextColor = AppColors.emerald;
    } else if (isActive) {
      bg = AppColors.electricBlue.withValues(alpha: 0.1);
      iconColor = AppColors.electricBlue;
      icon = Icons.bolt_rounded; // Lightning bolt matching mockup
      rightTextTop = 'May 27'; // Mock
      rightTextBottom = 'Today';
      rightTextColor = AppColors.electricBlue;
    } else {
      bg = AppColors.surfaceGrey;
      iconColor = AppColors.textTertiary;
      icon = Icons.stop_rounded; // Square
      rightTextTop = 'Jun 5'; // Mock
      rightTextBottom = '9d';
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
                if (isCompleted || isActive)
                  Text(
                    '${stage.assignedUsers.isNotEmpty ? stage.assignedUserNames.first : 'Unassigned'} • ${isCompleted ? '3 deliverables' : '72% done'}', // Mock details
                    style: AppTypography.bodySmall,
                  )
                else
                  GestureDetector(
                    onTap: () async {
                      await _service.completeStep(_project!.id, stage.id);
                      _loadProject();
                    },
                    child: Text(
                      'Complete task',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.electricBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
}
