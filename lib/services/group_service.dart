import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group.dart';
import '../models/group_message.dart';
import '../models/profile.dart';

class GroupService {
  final SupabaseClient _supabase;
  final Map<String, Profile> _profileCache = {};

  GroupService(this._supabase);

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Call 17: create group row.
  Future<Group> createGroup({
    required String groupName,
    required String description,
  }) async {
    final uid = _currentUserId!;
    try {
      final Map<String, dynamic> row = await _supabase.from('groups').insert({
        'name': groupName,
        'description': description,
        'created_by': uid,
      }).select().single();
      return Group.fromJson(row);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 18 (DB part): set `avatar_url` on group after upload.
  Future<void> updateGroupAvatarUrl({
    required String groupId,
    required String avatarUrl,
  }) async {
    try {
      await _supabase.from('groups').update({
        'avatar_url': avatarUrl,
      }).eq('id', groupId);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 19: bulk insert members.
  Future<void> addMembersToGroup({
    required String groupId,
    required List<String> friendUserIds,
  }) async {
    final uid = _currentUserId!;
    final rows = <Map<String, dynamic>>[
      {'group_id': groupId, 'user_id': uid, 'role': 'admin'},
      ...friendUserIds.map(
        (id) => {'group_id': groupId, 'user_id': id, 'role': 'member'},
      ),
    ];

    try {
      await _supabase.from('group_members').insert(rows);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 20: groups current user belongs to.
  Future<List<GroupMembership>> fetchMyGroups() async {
    final uid = _currentUserId!;
    try {
      final List<dynamic> response = await _supabase
          .from('group_members')
          .select('*, groups(id, name, avatar_url, description, created_by)')
          .eq('user_id', uid);

      return response
          .cast<Map<String, dynamic>>()
          .map(GroupMembership.fromJson)
          .toList(growable: false);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 21: members + profiles + role.
  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('group_members')
          .select('*, profiles(id, username, avatar_url)')
          .eq('group_id', groupId);

      return response.cast<Map<String, dynamic>>().toList(growable: false);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 22: initial history (optional; realtime drives UI).
  Future<List<GroupMessage>> fetchGroupMessages(String groupId) async {
    try {
      final List<dynamic> response = await _supabase
          .from('group_messages')
          .select('*, profiles!sender_id(username, avatar_url)')
          .eq('group_id', groupId)
          .order('created_at', ascending: true)
          .limit(100);

      return response
          .cast<Map<String, dynamic>>()
          .map(GroupMessage.fromJson)
          .toList(growable: false);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 23: text message.
  Future<void> sendGroupTextMessage({
    required String groupId,
    required String text,
  }) async {
    final uid = _currentUserId!;
    try {
      await _supabase.from('group_messages').insert({
        'group_id': groupId,
        'sender_id': uid,
        'content': text,
        'message_type': 'text',
      });
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 24: file/image message after upload + signed URL.
  Future<void> sendGroupFileMessage({
    required String groupId,
    required String fileName,
    required String signedUrl,
    required String messageType,
    required int fileSizeInBytes,
    String? storagePath,
  }) async {
    final uid = _currentUserId!;
    final payload = {
      'group_id': groupId,
      'sender_id': uid,
      'content': fileName,
      'message_type': messageType,
      'file_url': signedUrl,
      'file_name': fileName,
      'file_size': fileSizeInBytes,
      // ...? (storagePath == null ? null : {'file_url': storagePath}),
    };
    try {
      await _supabase.from('group_messages').insert(payload);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 25: realtime group messages (profiles merged like DMs).
  Stream<List<Map<String, dynamic>>> streamGroupMessages(String groupId) {
    final base = _supabase
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: true)
        .asBroadcastStream();

    return base.asyncMap((rows) => _attachSenderProfilesToGroupRows(rows));
  }

  static String _groupMessageAuthorId(Map<String, dynamic> r) {
    final v = r['sender_id'] ??
        r['user_id'] ??
        r['senderId'] ??
        r['userId'];
    return v?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> _attachSenderProfilesToGroupRows(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return rows;

    final ids = rows
        .map((r) => _groupMessageAuthorId(r).toLowerCase())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final missing = ids.where((id) => !_profileCache.containsKey(id)).toList();

    if (missing.isNotEmpty) {
      try {
        final List<dynamic> resp = await _supabase
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', missing);

        for (final raw in resp) {
          final map = Map<String, dynamic>.from(raw as Map);
          final id = (map['id'] as String).toLowerCase();
          _profileCache[id] = Profile.fromJson(map);
        }
        for (final id in missing) {
          _profileCache.putIfAbsent(id, () => Profile.unknown(id));
        }
      } on PostgrestException {
        for (final id in missing) {
          _profileCache.putIfAbsent(id, () => Profile.unknown(id));
        }
      }
    }

    return rows.map((row) {
      final sid = _groupMessageAuthorId(row);
      final key = sid.toLowerCase();
      final p = _profileCache[key] ?? Profile.unknown(sid);
      return {
        ...row,
        'profiles': {
          'username': p.username,
          'avatar_url': p.avatarUrl,
        },
        '_authorId': sid,
      };
    }).toList();
  }

  /// Call 26: admin removes member.
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String targetUserId,
  }) async {
    try {
      await _supabase
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', targetUserId);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 27: current user leaves group.
  Future<void> leaveGroup(String groupId) async {
    final uid = _currentUserId!;
    try {
      await _supabase
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', uid);
    } on PostgrestException {
      rethrow;
    }
  }
}
