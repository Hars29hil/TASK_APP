import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../models/activity_event.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'App Launch', 'UI Redesign', 'E-Commerce'];

  @override
  Widget build(BuildContext context) {
    final events = ActivityEvent.mockEvents();

    return Scaffold(
      backgroundColor: AppColors.warmWhite,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  return _buildTimelineItem(events[index], isLast: index == events.length - 1);
                },
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
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.electricBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.warmWhite, width: 2),
                  ),
                  child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                            Text(event.projectTitle == 'App Redesign' ? '🎨 ' : '🚀 ', style: const TextStyle(fontSize: 12)),
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
    if (type == 'task_created') return Icons.attach_file_rounded;
    return Icons.science_rounded;
  }

  Color _getEventColor(String type) {
    if (type == 'step_completed') return AppColors.emerald;
    if (type == 'step_started') return AppColors.electricBlue;
    if (type == 'member_added') return AppColors.highlight;
    if (type == 'task_created') return AppColors.warning;
    return AppColors.emerald;
  }

  String _actionVerb(String type) {
    if (type == 'step_completed') return 'completed';
    if (type == 'step_started') return 'activated';
    if (type == 'member_added') return 'assigned';
    if (type == 'task_created') return 'uploaded';
    return 'updated';
  }

  String _eventTarget(ActivityEvent event) {
    final match = RegExp(r'"([^"]+)"').firstMatch(event.description);
    if (match != null) return match.group(1) ?? '';
    return event.description.split(' ').skip(1).join(' ');
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }
}
