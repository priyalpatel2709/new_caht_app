/// Row from `groups`.
class Group {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String createdBy;
  final DateTime? createdAt;

  Group({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.createdBy,
    this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: (json['name'] ?? 'Group') as String,
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdBy: (json['created_by'] ?? '') as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// One membership row with nested group (from `group_members` + `groups`).
class GroupMembership {
  final String groupId;
  final String userId;
  final String role;
  final Group group;

  GroupMembership({
    required this.groupId,
    required this.userId,
    required this.role,
    required this.group,
  });

  factory GroupMembership.fromJson(Map<String, dynamic> json) {
    final nested = json['groups'];
    Map<String, dynamic> groupMap;
    if (nested is Map<String, dynamic>) {
      groupMap = nested;
    } else if (nested is List && nested.isNotEmpty) {
      groupMap = nested.first as Map<String, dynamic>;
    } else {
      throw FormatException('Missing nested groups on group_members row');
    }

    return GroupMembership(
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      role: (json['role'] ?? 'member') as String,
      group: Group.fromJson(groupMap),
    );
  }
}
