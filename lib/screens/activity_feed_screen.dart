import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../models/activity_event.dart';
import '../models/project.dart';
import '../services/task_service.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  String _selectedFilter = 'All';
  List<String> _filters = ['All'];
  List<ActivityEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() => _isLoading = true);
    try {
      final projects = await TaskService.instance.fetchProjects();
      final events = _buildEventsFromProjects(projects);
      
      // Build unique project title filters
      final projectTitles = projects.map((p) => p.title).toSet().toList();
      
      if (mounted) {
        setState(() {
          _events = events;
          _filters = ['All', ...projectTitles.take(3)];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading activity: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ActivityEvent> _buildEventsFromProjects(List<Project> projects) {
    final List<ActivityEvent> events = [];
    
    for (final project in projects) {
      // Task creation event
      events.add(ActivityEvent(
        id: 'created_${project.id}',
        type: 'task_created',
        actorName: project.members.isNotEmpty ? project.members.first.name : 'Admin',
        description: 'Created new project "${project.title}"',
        timestamp: project.createdAt,
        projectTitle: project.title,
      ));
      
      // Member events
      for (final member in project.members) {
        if (member.role != 'admin') {
          events.add(ActivityEvent(
            id: 'member_${project.id}_${member.userId}',
            type: 'member_added',
            actorName: 'Admin',
            description: 'Added ${member.name} to "${project.title}"',
            timestamp: project.createdAt.add(const Duration(minutes: 1)),
            projectTitle: project.title,
          ));
        }
      }
      
      // Stage events
      for (final stage in project.stages) {
        if (stage.startedAt != null) {
          events.add(ActivityEvent(
            id: 'started_${stage.id}',
            type: 'step_started',
            actorName: stage.assignedUserNames.isNotEmpty ? stage.assignedUserNames.first : 'System',
            description: 'Started "${stage.title}"',
            timestamp: stage.startedAt!,
            projectTitle: project.title,
          ));
        }
        
        if (stage.status == 'completed') {
          events.add(ActivityEvent(
            id: 'completed_${stage.id}',
            type: 'step_completed',
            actorName: stage.assignedUserNames.isNotEmpty ? stage.assignedUserNames.first : 'System',
            description: 'Completed "${stage.title}"',
            timestamp: stage.startedAt?.add(Duration(days: stage.durationDays)) ?? project.createdAt,
            projectTitle: project.title,
          ));
        }
        
        if (stage.status == 'blocked') {
          events.add(ActivityEvent(
            id: 'blocked_${stage.id}',
            type: 'step_blocked',
            actorName: stage.assignedUserNames.isNotEmpty ? stage.assignedUserNames.first : 'System',
            description: 'Blocked "${stage.title}" — ${stage.blockedReason ?? 'No reason'}',
            timestamp: stage.startedAt ?? project.createdAt,
            projectTitle: project.title,
          ));
        }
        
        if (stage.extensionDays > 0) {
          events.add(ActivityEvent(
            id: 'extension_${stage.id}',
            type: 'extension_approved',
            actorName: 'Leader',
            description: 'Extension +${stage.extensionDays} days approved for "${stage.title}"',
            timestamp: stage.startedAt?.add(Duration(days: stage.durationDays ~/ 2)) ?? project.createdAt,
            projectTitle: project.title,
          ));
        }
      }
    }
    
    // Sort by most recent
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events;
  }

  List<ActivityEvent> get _filteredEvents {
    if (_selectedFilter == 'All') return _events;
    return _events.where((e) => e.projectTitle == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.electricBlue))
                  : events.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_rounded, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text('No activity yet', style: AppTypography.h3),
                              const SizedBox(height: 8),
                              Text('Activity events will appear here.', style: AppTypography.bodySmall),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadActivity,
                          color: AppColors.electricBlue,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              return _buildTimelineItem(events[index], isLast: index == events.length - 1);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Activity', style: AppTypography.h1),
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceGrey),
                  boxShadow: AppShadows.soft,
                ),
                child: const Icon(Icons.notifications_none_rounded, color: AppColors.ink),
              ),
              if (_events.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.electricBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 2),
                    ),
                    child: Text('${_events.length > 99 ? '99+' : _events.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: _filters.map((filter) {
          final isActive = filter == _selectedFilter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? AppColors.ink : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isActive ? AppColors.ink : AppColors.surfaceGrey),
                boxShadow: isActive ? AppShadows.soft : [],
              ),
              child: Text(
                filter,
                style: AppTypography.labelMedium.copyWith(
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineItem(ActivityEvent event, {required bool isLast}) {
    final iconData = _getEventIcon(event.type);
    final iconColor = _getEventColor(event.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(iconData, size: 14, color: iconColor),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.surfaceGrey,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.ink),
                      children: [
                        TextSpan(
                          text: '${event.actorName} ',
                          style: AppTypography.labelLarge.copyWith(color: AppColors.electricBlue),
                        ),
                        TextSpan(
                          text: _actionVerb(event.type),
                          style: AppTypography.labelMedium,
                        ),
                        TextSpan(
                          text: ' ${_eventTarget(event)}',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGrey.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🚀 ', style: TextStyle(fontSize: 12)),
                            Text(
                              event.projectTitle ?? 'General',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _timeAgo(event.timestamp),
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String type) {
    if (type == 'step_completed') return Icons.check_rounded;
    if (type == 'step_started') return Icons.bolt_rounded;
    if (type == 'member_added') return Icons.person_rounded;
    if (type == 'task_created') return Icons.add_task_rounded;
    if (type == 'step_blocked') return Icons.block_rounded;
    if (type == 'extension_approved') return Icons.schedule_rounded;
    return Icons.science_rounded;
  }

  Color _getEventColor(String type) {
    if (type == 'step_completed') return AppColors.emerald;
    if (type == 'step_started') return AppColors.electricBlue;
    if (type == 'member_added') return AppColors.highlight;
    if (type == 'task_created') return AppColors.warning;
    if (type == 'step_blocked') return AppColors.danger;
    if (type == 'extension_approved') return AppColors.warning;
    return AppColors.emerald;
  }

  String _actionVerb(String type) {
    if (type == 'step_completed') return 'completed';
    if (type == 'step_started') return 'activated';
    if (type == 'member_added') return 'assigned';
    if (type == 'task_created') return 'created';
    if (type == 'step_blocked') return 'blocked';
    if (type == 'extension_approved') return 'approved extension for';
    return 'updated';
  }

  String _eventTarget(ActivityEvent event) {
    final match = RegExp(r'"([^"]+)"').firstMatch(event.description);
    if (match != null) return match.group(1) ?? '';
    return event.description.split(' ').skip(1).join(' ');
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }
}
