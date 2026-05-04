import 'profile.dart';

/// Row from `friend_requests` with optional nested sender `profiles`.
class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final Profile? senderProfile;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    this.senderProfile,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final dynamic raw = json['profiles'];
    Profile? sender;
    if (raw is Map<String, dynamic>) {
      sender = Profile(
        id: json['sender_id'] as String,
        username: (raw['username'] ?? 'Unknown') as String,
        avatarUrl: raw['avatar_url'] as String?,
      );
    } else if (raw is List && raw.isNotEmpty) {
      final m = raw.first as Map<String, dynamic>;
      sender = Profile(
        id: json['sender_id'] as String,
        username: (m['username'] ?? 'Unknown') as String,
        avatarUrl: m['avatar_url'] as String?,
      );
    }

    return FriendRequest(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: (json['status'] ?? 'pending') as String,
      senderProfile: sender,
    );
  }
}

/// Row from `friends` with nested friend `profiles`.
class FriendEdge {
  final String userId;
  final String friendId;
  final Profile friendProfile;

  FriendEdge({
    required this.userId,
    required this.friendId,
    required this.friendProfile,
  });

  factory FriendEdge.fromJson(Map<String, dynamic> json) {
    final dynamic raw = json['profiles'];
    Map<String, dynamic> p;
    if (raw is Map<String, dynamic>) {
      p = raw;
    } else if (raw is List && raw.isNotEmpty) {
      p = raw.first as Map<String, dynamic>;
    } else {
      p = {};
    }

    final fid = json['friend_id'] as String;
    return FriendEdge(
      userId: json['user_id'] as String,
      friendId: fid,
      friendProfile: Profile(
        id: p['id'] as String? ?? fid,
        username: (p['username'] ?? 'Unknown') as String,
        avatarUrl: p['avatar_url'] as String?,
      ),
    );
  }
}
