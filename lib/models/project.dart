/// Represents a task/project in the workflow system.
class Project {
  final String id;
  final String title;
  final String? description;
  final String status; // 'active' | 'completed' | 'archived'
  final String priority; // 'low' | 'medium' | 'high' | 'urgent'
  final DateTime? deadline;
  final DateTime createdAt;
  final String createdBy;
  final String? myRole;
  final List<Stage> stages;
  final List<Member> members;

  const Project({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.deadline,
    required this.createdAt,
    required this.createdBy,
    this.myRole,
    this.stages = const [],
    this.members = const [],
  });

  double get progress {
    if (stages.isEmpty) return 0;
    return stages.where((s) => s.status == 'completed').length / stages.length;
  }

  Stage? get currentStage {
    for (final s in stages) {
      if (['ready', 'in_progress', 'active', 'extended', 'waiting_approval', 'blocked']
          .contains(s.status)) {
        return s;
      }
    }
    return null;
  }

  String get currentStepLabel {
    final current = currentStage;
    if (current != null) return current.title;
    return status == 'completed' ? 'All completed' : 'Not started';
  }

  int get completedStageCount =>
      stages.where((s) => s.status == 'completed').length;

  bool get isCompleted => status == 'completed';

  factory Project.fromMap(Map<String, dynamic> map) {
    final stepsRaw = map['task_steps'] as List? ?? [];
    final membersRaw = map['task_members'] as List? ?? [];

    return Project(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled',
      description: map['description'],
      status: map['status'] ?? 'active',
      priority: map['priority'] ?? 'medium',
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      createdBy: map['created_by'] ?? '',
      myRole: map['my_role'],
      stages: stepsRaw
          .map((s) => Stage.fromMap(s as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.stepNumber.compareTo(b.stepNumber)),
      members: membersRaw
          .map((m) => Member.fromMap(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single stage/step in a project's workflow pipeline.
class Stage {
  final String id;
  final String title;
  final int stepNumber;
  final String status;
  final int durationDays;
  final int extensionDays;
  final DateTime? deadline;
  final DateTime? startedAt;
  final String? startedBy;
  final String? blockedReason;
  final List<Map<String, dynamic>> assignedUsers;

  const Stage({
    required this.id,
    required this.title,
    required this.stepNumber,
    required this.status,
    this.durationDays = 2,
    this.extensionDays = 0,
    this.deadline,
    this.startedAt,
    this.startedBy,
    this.blockedReason,
    this.assignedUsers = const [],
  });

  List<String> get assignedUserIds =>
      assignedUsers.map((u) => (u['user_id'] ?? '') as String).toList();

  List<String> get assignedUserNames =>
      assignedUsers.map((u) => (u['name'] ?? u['user_id'] ?? '?') as String).toList();

  bool isAssignedTo(String userId) => assignedUserIds.contains(userId);

  factory Stage.fromMap(Map<String, dynamic> map) {
    final usersRaw = map['step_users'] as List? ?? [];
    return Stage(
      id: map['id'] ?? '',
      title: map['step_title'] ?? 'Untitled Step',
      stepNumber: map['step_number'] ?? 0,
      status: map['status'] ?? 'pending',
      durationDays: map['duration_days'] ?? 2,
      extensionDays: map['extension_days'] ?? 0,
      deadline:
          map['deadline'] != null ? DateTime.tryParse(map['deadline']) : null,
      startedAt:
          map['started_at'] != null ? DateTime.tryParse(map['started_at']) : null,
      startedBy: map['started_by'],
      blockedReason: map['blocked_reason'],
      assignedUsers: usersRaw
          .map((u) => u as Map<String, dynamic>)
          .toList(),
    );
  }
}

/// A member of a project/task.
class Member {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String role; // 'admin' | 'leader' | 'member'
  final bool isOnline;

  const Member({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.isOnline = false,
  });

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      userId: map['user_id'] ?? '',
      name: map['name'] ?? map['user_id'] ?? 'Unknown',
      avatarUrl: map['avatar_url'],
      role: map['role'] ?? 'member',
      isOnline: map['is_online'] ?? false,
    );
  }
}
