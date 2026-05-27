/// A single activity event for the activity feed.
class ActivityEvent {
  final String id;
  final String type;
  final String actorName;
  final String description;
  final DateTime timestamp;
  final String? projectTitle;
  final Map<String, dynamic>? metadata;

  const ActivityEvent({
    required this.id,
    required this.type,
    required this.actorName,
    required this.description,
    required this.timestamp,
    this.projectTitle,
    this.metadata,
  });

  /// Mock data for initial build
  static List<ActivityEvent> mockEvents() {
    final now = DateTime.now();
    return [
      ActivityEvent(
        id: '1',
        type: 'step_started',
        actorName: 'Priya',
        description: 'Started "UI Review"',
        timestamp: now.subtract(const Duration(hours: 2)),
        projectTitle: 'App Redesign',
      ),
      ActivityEvent(
        id: '2',
        type: 'step_completed',
        actorName: 'Harshil',
        description: 'Completed "Research Phase"',
        timestamp: now.subtract(const Duration(hours: 5)),
        projectTitle: 'App Redesign',
      ),
      ActivityEvent(
        id: '3',
        type: 'extension_approved',
        actorName: 'Leader',
        description: 'Extension +3 days approved for "Design"',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        projectTitle: 'Marketing Campaign',
      ),
      ActivityEvent(
        id: '4',
        type: 'step_blocked',
        actorName: 'Raj',
        description: 'Blocked "API Integration" — Waiting API keys',
        timestamp: now.subtract(const Duration(days: 1, hours: 8)),
        projectTitle: 'Backend Overhaul',
      ),
      ActivityEvent(
        id: '5',
        type: 'task_created',
        actorName: 'Harshil',
        description: 'Created new project "Mobile App v2"',
        timestamp: now.subtract(const Duration(days: 2)),
      ),
      ActivityEvent(
        id: '6',
        type: 'member_added',
        actorName: 'Admin',
        description: 'Added Priya to "App Redesign"',
        timestamp: now.subtract(const Duration(days: 2, hours: 4)),
        projectTitle: 'App Redesign',
      ),
    ];
  }
}
