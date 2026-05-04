import 'profile.dart';

/// Row from `messages` with optional embedded `profiles` (join or merged after realtime).
///
/// `user_id` is `profiles.id`.
class Message {
  final String id;
  final String roomId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String messageType;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  /// Storage object key when available (e.g. from upload); optional DB column.
  final String? filePath;
  final Profile profile;

  Message({
    required this.id,
    required this.roomId,
    required this.userId,
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
  bool get isFile => messageType == 'file';

  /// Compares to [authUserId] case-insensitively (UUID strings can differ in casing).
  bool isFromCurrentUser(String? authUserId) {
    if (authUserId == null || authUserId.isEmpty) return false;
    if (userId.isEmpty) return false;
    return userId.toLowerCase() == authUserId.toLowerCase();
  }

  factory Message.fromJson(Map<String, dynamic> json) {
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

    return Message(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: authorId,
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

  /// Prefer synthetic `_authorId` from [ChatService] merge, then common column names.
  static String _authorIdFromRow(Map<String, dynamic> json) {
    final v = json['_authorId'] ??
        json['user_id'] ??
        json['sender_id'] ??
        json['userId'] ??
        json['senderId'];
    if (v == null) {
      throw FormatException('Message row missing user id: $json');
    }
    return v.toString();
  }
}
