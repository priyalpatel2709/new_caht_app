import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Storage: `chat-files`, `avatars`, `group-avatars`.
class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  static const String chatFilesBucket = 'chat-files';
  static const String avatarsBucket = 'avatars';
  static const String groupAvatarsBucket = 'group-avatars';

  /// Call 13: upload binary to `chat-files/uploads/{userId}/{fileName}`.
  /// Returns storage object path (key) for later signing.
  Future<String> uploadChatFile({
    required String currentUserId,
    required String fileName,
    required Uint8List fileBytes,
    String? mimeType,
  }) async {
    final path = 'uploads/$currentUserId/$fileName';
    final type =
        mimeType ?? lookupMimeType(fileName) ?? 'application/octet-stream';
    try {
      await _client.storage.from(chatFilesBucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(contentType: type, upsert: true),
          );
      return path;
    } on StorageException {
      rethrow;
    }
  }

  /// Call 14: signed URL for chat file (default 7 days).
  Future<String> createChatFileSignedUrl(
    String filePath, {
    int expiresInSeconds = 60 * 60 * 24 * 7,
  }) async {
    try {
      return await _client.storage
          .from(chatFilesBucket)
          .createSignedUrl(filePath, expiresInSeconds);
    } on StorageException {
      rethrow;
    }
  }

  /// Call 16: short-lived URL to open/download.
  Future<String> createChatFileSignedUrlForOpen(String filePath) async {
    return createChatFileSignedUrl(filePath, expiresInSeconds: 3600);
  }

  /// Group avatar upload (call 18 step 1).
  Future<String> uploadGroupAvatarJpeg({
    required String groupId,
    required Uint8List imageBytes,
  }) async {
    final path = '$groupId/avatar.jpg';
    try {
      await _client.storage.from(groupAvatarsBucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return path;
    } on StorageException {
      rethrow;
    }
  }

  /// Call 18: public URL for group avatar (bucket should allow public reads).
  String getGroupAvatarPublicUrl(String pathInBucket) {
    return _client.storage.from(groupAvatarsBucket).getPublicUrl(pathInBucket);
  }

  /// Optional: profile avatar to `avatars` bucket.
  Future<String> uploadUserAvatar({
    required String userId,
    required Uint8List imageBytes,
  }) async {
    final path = '$userId/avatar.jpg';
    try {
      await _client.storage.from(avatarsBucket).uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return path;
    } on StorageException {
      rethrow;
    }
  }

  String getUserAvatarPublicUrl(String pathInBucket) {
    return _client.storage.from(avatarsBucket).getPublicUrl(pathInBucket);
  }
}
