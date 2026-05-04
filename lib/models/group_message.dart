import 'profile.dart';

/// Row from `group_messages` with optional `profiles` embed on `sender_id`.
class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String messageType;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? filePath;
  final Profile profile;

  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.messageType,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.filePath,
    required this.profile,
  });

  bool get isText => messageType == 'text';
  bool get isImage => messageType == 'image';

  bool isFromCurrentUser(String? authUserId) {
    if (authUserId == null || authUserId.isEmpty) return false;
    if (senderId.isEmpty) return false;
    return senderId.toLowerCase() == authUserId.toLowerCase();
  }

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    final authorId = _authorIdFromRow(json);

    final dynamic rawProfile = json['profiles'];
    Map<String, dynamic>? profileMap;

    if (rawProfile is Map<String, dynamic>) {
      profileMap = rawProfile;
    } else if (rawProfile is List && rawProfile.isNotEmpty) {
      final first = rawProfile.first;
      if (first is Map<String, dynamic>) {
        profileMap = first;
      }
    }

    final profile = profileMap == null
        ? Profile.unknown(authorId)
        : Profile(
            id: authorId,
            username: (profileMap['username'] ?? 'Unknown user') as String,
            avatarUrl: profileMap['avatar_url'] as String?,
          );

    final type = (json['message_type'] ?? 'text') as String;

    return GroupMessage(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: authorId,
      content: (json['content'] ?? '') as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      messageType: type,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] != null
          ? int.tryParse(json['file_size'].toString())
          : null,
      filePath: json['file_path'] as String?,
      profile: profile,
    );
  }

  static String _authorIdFromRow(Map<String, dynamic> json) {
    final v = json['_authorId'] ??
        json['sender_id'] ??
        json['user_id'] ??
        json['senderId'] ??
        json['userId'];
    if (v == null) {
      throw FormatException('Group message row missing sender id: $json');
    }
    return v.toString();
  }
}
