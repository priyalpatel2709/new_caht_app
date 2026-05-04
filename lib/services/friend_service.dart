import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend_request.dart';
import '../models/outgoing_friend_request.dart';
import '../models/profile.dart';

class FriendService {
  final SupabaseClient _supabase;
  final Map<String, Profile> _profileCache = {};

  FriendService(this._supabase);

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Call 5: search users by username (ilike).
  Future<List<Profile>> searchUsersByUsername(String searchQuery) async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final q = searchQuery.trim();
    if (q.isEmpty) return [];

    try {
      final List<dynamic> response = await _supabase
          .from('profiles')
          .select()
          .ilike('username', '%$q%')
          .neq('id', uid)
          .limit(20);

      return response
          .cast<Map<String, dynamic>>()
          .map(Profile.fromJson)
          .toList(growable: false);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 6: send friend request (status pending).
  Future<void> sendFriendRequest(String targetUserId) async {
    final uid = _currentUserId!;
    try {
      await _supabase.from('friend_requests').insert({
        'sender_id': uid,
        'receiver_id': targetUserId,
        'status': 'pending',
      });
    } on PostgrestException {
      rethrow;
    }
  }

  /// Pending requests you sent (for outgoing tab).
  Future<List<OutgoingFriendRequest>> fetchOutgoingPendingRequests() async {
    final uid = _currentUserId!;
    try {
      final rows = await _supabase
          .from('friend_requests')
          .select()
          .eq('sender_id', uid)
          .eq('status', 'pending');

      final list = rows.cast<Map<String, dynamic>>().toList();
      if (list.isEmpty) return [];

      final receiverIds =
          list.map((r) => r['receiver_id'] as String).toSet().toList();
      final profilesById = <String, Profile>{};

      try {
        final List<dynamic> resp = await _supabase
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', receiverIds);

        for (final raw in resp) {
          final map = Map<String, dynamic>.from(raw as Map);
          final id = map['id'] as String;
          profilesById[id] = Profile.fromJson(map);
        }
      } on PostgrestException {
        // fall through with unknown profiles
      }

      for (final id in receiverIds) {
        profilesById.putIfAbsent(id, () => Profile.unknown(id));
      }

      return list.map((row) {
        final rid = row['receiver_id'] as String;
        final p = profilesById[rid] ?? Profile.unknown(rid);
        return OutgoingFriendRequest.fromJson({
          ...row,
          'profiles': {
            'id': p.id,
            'username': p.username,
            'avatar_url': p.avatarUrl,
          },
        });
      }).toList();
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 7: incoming pending requests with sender profile.
  Future<List<FriendRequest>> fetchIncomingRequests() async {
    final uid = _currentUserId!;
    try {
      final List<dynamic> response = await _supabase
          .from('friend_requests')
          .select('*, profiles!sender_id(username, avatar_url)')
          .eq('receiver_id', uid)
          .eq('status', 'pending');

      return response
          .cast<Map<String, dynamic>>()
          .map(FriendRequest.fromJson)
          .toList(growable: false);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 8: accept (DB trigger should insert into `friends`).
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'accepted'}).eq('id', requestId);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 9: reject.
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'rejected'}).eq('id', requestId);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Call 10: friends list with friend profile.
  Future<List<FriendEdge>> fetchFriendsList() async {
    final uid = _currentUserId!;
    try {
      final List<dynamic> response = await _supabase
          .from('friends')
          .select('*, profiles!friend_id(id, username, avatar_url)')
          .eq('user_id', uid);

      return response
          .cast<Map<String, dynamic>>()
          .map(FriendEdge.fromJson)
          .toList(growable: false);
    } on PostgrestException {
      rethrow;
    }
  }

  /// Badge count for Home app bar.
  Stream<int> watchIncomingPendingCount() {
    return streamIncomingPendingRequests().map((list) => list.length);
  }

  /// Call 11: realtime incoming pending requests for badge + list.
  /// Stream rows are plain `friend_requests`; sender profiles are merged in.
  Stream<List<FriendRequest>> streamIncomingPendingRequests() {
    final uid = _currentUserId!;
    // `.stream()` allows only one `.eq()` filter — filter `pending` in [_attachSenderProfiles].
    final base = _supabase
        .from('friend_requests')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', uid)
        .order('created_at', ascending: true)
        .asBroadcastStream();

    return base.asyncMap(_attachSenderProfiles);
  }

  Future<List<FriendRequest>> _attachSenderProfiles(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return [];

    final pending =
        rows.where((r) => (r['status'] ?? 'pending') == 'pending').toList();
    if (pending.isEmpty) return [];

    final senderIds =
        pending.map((r) => r['sender_id'] as String).toSet().toList();
    final missing =
        senderIds.where((id) => !_profileCache.containsKey(id)).toList();

    if (missing.isNotEmpty) {
      try {
        final List<dynamic> resp = await _supabase
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', missing);

        for (final raw in resp) {
          final map = Map<String, dynamic>.from(raw as Map);
          final id = map['id'] as String;
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

    return pending.map((row) {
      final sid = row['sender_id'] as String;
      final p = _profileCache[sid] ?? Profile.unknown(sid);
      return FriendRequest.fromJson({
        ...row,
        'profiles': {
          'username': p.username,
          'avatar_url': p.avatarUrl,
        },
      });
    }).toList();
  }
}
