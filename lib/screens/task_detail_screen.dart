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
  int _selectedTabIndex = 0;

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
      return const Scaffold(
        backgroundColor: Color(0xFF0F265C),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_project == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F265C),
        body: Center(child: Text('Not found', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F265C), // Dark blue
      body: Column(
        children: [
          _buildTopHeader(),
          Expanded(child: _buildBottomCard()),
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
              _buildAvatar('H', Colors.blue),
              _buildAvatar('B', Colors.green),
              _buildAvatar('A', Colors.purple),
              _buildAvatar('R', Colors.orange),
              const SizedBox(width: 12),
              Text('+2 members', style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
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

  Widget _buildBottomCard() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              children: [
                _buildTab('Workflow', 0),
                const SizedBox(width: 24),
                _buildTab('Timeline', 1),
                const SizedBox(width: 24),
                _buildTab('Files', 2),
                const SizedBox(width: 24),
                _buildTab('Chat', 3),
                const SizedBox(width: 24),
                _buildTab('Members', 4),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: AppColors.surfaceGrey),
          // Content
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                  itemCount: _project!.stages.length,
                  itemBuilder: (context, index) {
                    return _buildStageItem(_project!.stages[index]);
                  },
                ),
                // Mock Chat Overlay
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Container(
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Column(
        children: [
          Text(
            title,
            style: AppTypography.labelMedium.copyWith(
              color: isActive ? AppColors.electricBlue : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 40,
            color: isActive ? AppColors.electricBlue : Colors.transparent,
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
}
