import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import '../models/profile.dart';
import '../models/room.dart';

class ChatService {
  final SupabaseClient _supabase;

  /// `messages.user_id` / `user_id` → `profiles.id`.
  final Map<String, Profile> _profileCache = {};

  ChatService(this._supabase);

  /// Stable DM room name so the same pair always shares one [rooms] row.
  static String directRoomSlug(String userIdA, String userIdB) {
    final a = userIdA.compareTo(userIdB) < 0 ? userIdA : userIdB;
    final b = userIdA.compareTo(userIdB) < 0 ? userIdB : userIdA;
    return 'dm|$a|$b';
  }

  Future<List<Room>> fetchAllRooms() async {
    try {
      final List<dynamic> response =
          await _supabase.from('rooms').select().order('created_at');
      return response
          .cast<Map<String, dynamic>>()
          .map(Room.fromJson)
          .toList(growable: false);
    } on PostgrestException {
      rethrow;
    }
  }

  Future<Room> createRoom({required String name}) async {
    try {
      final Map<String, dynamic> row = await _supabase
          .from('rooms')
          .insert({'name': name})
          .select()
          .single();
      return Room.fromJson(row);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Opens or creates a private 1:1 room row; show [chatTitle] in the app bar.
  Future<Room> getOrCreateDirectRoom({
    required String otherUserId,
  }) async {
    final me = _supabase.auth.currentUser!.id;
    final slug = directRoomSlug(me, otherUserId);
    try {
      final existing = await _supabase
          .from('rooms')
          .select()
          .eq('name', slug)
          .maybeSingle();

      if (existing != null) {
        return Room.fromJson(Map<String, dynamic>.from(existing as Map));
      }

      final Map<String, dynamic> row = await _supabase
          .from('rooms')
          .insert({'name': slug})
          .select()
          .single();
      return Room.fromJson(row);
    } on PostgrestException {
      rethrow;
    }
  }

  Future<Message?> fetchLatestMessageForRoom(String roomId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('messages')
          .select('*, profiles(username, avatar_url)')
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(1);
      if (response.isEmpty) return null;
      return Message.fromJson(
        Map<String, dynamic>.from(response.first as Map),
      );
    } on PostgrestException {
      rethrow;
    }
  }

  Future<List<Message>> fetchMessagesForRoom(String roomId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('messages')
          .select('*, profiles(username, avatar_url)')
          .eq('room_id', roomId)
          .order('created_at', ascending: true)
          .limit(100);

      return response
          .cast<Map<String, dynamic>>()
          .map(Message.fromJson)
          .toList(growable: false);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Text DM (call 15 style with `message_type`: text).
  Future<void> sendMessage({
    required String roomId,
    required String text,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'room_id': roomId,
        'user_id': _supabase.auth.currentUser!.id,
        'content': text,
        'message_type': 'text',
      });
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 15: message with file / image metadata.
  Future<void> sendFileMessage({
    required String roomId,
    required String fileName,
    required String signedUrl,
    required String messageType,
    required int fileSizeInBytes,
    String? storagePath,
  }) async {
    final payload = {
      'room_id': roomId,
      'user_id': _supabase.auth.currentUser!.id,
      'content': fileName,
      'message_type': messageType,
      'file_url': signedUrl,
      'file_name': fileName,
      'file_size': fileSizeInBytes,
      ...? (storagePath == null ? null : {'file_path': storagePath}),
    };
    try {
      await _supabase.from('messages').insert(payload);
    } on PostgrestException {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamMessagesForRoom(String roomId) {
    final base = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .asBroadcastStream();

    return base.asyncMap(_attachProfilesToMessageRows);
  }

  static String _messageAuthorId(Map<String, dynamic> r) {
    final v = r['user_id'] ??
        r['sender_id'] ??
        r['userId'] ??
        r['senderId'];
    return v?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> _attachProfilesToMessageRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return rows;

    final ids = rows
        .map((r) => _messageAuthorId(r).toLowerCase())
        .where((id) => id.isNotEmpty)
        .toSet();
    final missing =
        ids.where((id) => !_profileCache.containsKey(id)).toList();

    if (missing.isNotEmpty) {
      try {
        final List<dynamic> resp = await _supabase
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', missing);

        final fetchedIds = <String>{};
        for (final raw in resp) {
          final map = Map<String, dynamic>.from(raw as Map);
          final id = (map['id'] as String).toLowerCase();
          _profileCache[id] = Profile.fromJson(map);
          fetchedIds.add(id);
        }
        for (final id in missing) {
          if (!fetchedIds.contains(id)) {
            _profileCache[id] = Profile.unknown(id);
          }
        }
      } on PostgrestException {
        for (final id in missing) {
          _profileCache.putIfAbsent(id, () => Profile.unknown(id));
        }
      }
    }

    return rows.map((row) {
      final uid = _messageAuthorId(row);
      final key = uid.toLowerCase();
      final profile = _profileCache[key] ?? Profile.unknown(uid);
      return {
        ...row,
        'profiles': {
          'username': profile.username,
          'avatar_url': profile.avatarUrl,
        },
        // Last so it overrides any stale key on [row].
        '_authorId': uid,
      };
    }).toList();
  }

  Future<Profile> fetchUserProfile(String userId) async {
    try {
      final Map<String, dynamic> response =
          await _supabase.from('profiles').select().eq('id', userId).single();
      return Profile.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return Profile.unknown(userId);
      }
      rethrow;
    }
  }

  Future<void> updateUsername(String newUsername) async {
    final uid = _supabase.auth.currentUser!.id;
    try {
      await _supabase
          .from('profiles')
          .update({'username': newUsername})
          .eq('id', uid);
      _profileCache.remove(uid);
      _profileCache.remove(uid.toLowerCase());
    } on PostgrestException {
      rethrow;
    }
  }
}
