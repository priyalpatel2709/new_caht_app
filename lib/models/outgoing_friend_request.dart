import 'profile.dart';

/// Pending request you sent — [receiver] is the invitee.
class OutgoingFriendRequest {
  final String id;
  final String receiverId;
  final String status;
  final Profile receiver;

  OutgoingFriendRequest({
    required this.id,
    required this.receiverId,
    required this.status,
    required this.receiver,
  });

  factory OutgoingFriendRequest.fromJson(Map<String, dynamic> json) {
    final rid = json['receiver_id'] as String;
    final dynamic raw = json['profiles'];
    Map<String, dynamic> p = {};
    if (raw is Map<String, dynamic>) {
      p = raw;
    } else if (raw is List && raw.isNotEmpty) {
      p = Map<String, dynamic>.from(raw.first as Map);
    }

    return OutgoingFriendRequest(
      id: json['id'] as String,
      receiverId: rid,
      status: (json['status'] ?? 'pending') as String,
      receiver: Profile(
        id: p['id'] as String? ?? rid,
        username: (p['username'] ?? 'Unknown') as String,
        avatarUrl: p['avatar_url'] as String?,
      ),
    );
  }
}
