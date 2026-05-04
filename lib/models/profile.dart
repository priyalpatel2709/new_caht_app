/// Row in `profiles` (id matches `auth.users.id` in the usual setup).
class Profile {
  final String id;
  final String username;
  final String? avatarUrl;
  final DateTime? createdAt;

  Profile({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: (json['username'] ?? 'Unknown user') as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  factory Profile.unknown(String id) {
    return Profile(id: id, username: 'Unknown user');
  }
}
