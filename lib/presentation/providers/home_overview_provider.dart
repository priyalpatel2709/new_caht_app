import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/group.dart';
import '../../models/message.dart';
import '../../models/room.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat_list_tile.dart';
import 'service_providers.dart';

class HomeOverview {
  HomeOverview({
    required this.dmChats,
    required this.groupChats,
    required this.publicRooms,
  });

  final List<ChatListItemData> dmChats;
  final List<ChatListItemData> groupChats;
  final List<PublicRoomRow> publicRooms;
}

class PublicRoomRow {
  PublicRoomRow({
    required this.room,
    required this.preview,
    this.timeLabel,
  });

  final Room room;
  final String preview;
  final String? timeLabel;
}

String _messagePreview(Message? m, String myId) {
  if (m == null) return 'No messages yet';
  if (m.isImage) return 'Photo';
  if (m.isFile) return m.fileName ?? 'File';
  final prefix = m.isFromCurrentUser(myId) ? 'You: ' : '';
  return '$prefix${m.content}';
}

String _timeLabel(Message? m) {
  if (m == null) return '';
  return timeago.format(m.createdAt);
}

String? _otherDmUserId(String dmName, String myUserId) {
  if (!dmName.startsWith('dm|')) return null;
  final parts = dmName.split('|');
  if (parts.length < 3) return null;
  final a = parts[1];
  final b = parts[2];
  if (a == myUserId) return b;
  if (b == myUserId) return a;
  return b;
}

Future<ChatListItemData> _roomToChatTile(
  Room room,
  String myUserId,
  ChatService chat,
) async {
  final last = await chat.fetchLatestMessageForRoom(room.id);
  final preview = _messagePreview(last, myUserId);
  final timeLabel = _timeLabel(last);

  if (room.name.startsWith('dm|')) {
    final otherId = _otherDmUserId(room.name, myUserId);
    if (otherId != null) {
      final p = await chat.fetchUserProfile(otherId);
      return ChatListItemData(
        id: room.id,
        name: p.username,
        lastMessage: preview,
        timeLabel: timeLabel,
        avatarUrl: p.avatarUrl,
        unreadCount: 0,
        isOnline: false,
        isGroup: false,
      );
    }
  }

  return ChatListItemData(
    id: room.id,
    name: room.name,
    lastMessage: preview,
    timeLabel: timeLabel,
    avatarUrl: null,
    unreadCount: 0,
    isGroup: false,
  );
}

final homeOverviewProvider =
    FutureProvider.autoDispose<HomeOverview>((ref) async {
  final chat = ref.watch(chatServiceProvider);
  final group = ref.watch(groupServiceProvider);
  final uid = ref.watch(supabaseProvider).auth.currentUser?.id;
  if (uid == null) {
    throw StateError('Unauthenticated');
  }

  final rooms = await chat.fetchAllRooms();
  final memberships = await group.fetchMyGroups();

  final dmRooms =
      rooms.where((r) => r.name.startsWith('dm|')).toList(growable: false);
  final publicRooms =
      rooms.where((r) => !r.name.startsWith('dm|')).toList(growable: false);

  final dmItems = await Future.wait(
    dmRooms.map((r) => _roomToChatTile(r, uid, chat)),
  );

  final groupItems = memberships.map((GroupMembership m) {
    final g = m.group;
    return ChatListItemData(
      id: g.id,
      name: g.name,
      lastMessage: 'You are ${m.role}',
      timeLabel: '',
      avatarUrl: g.avatarUrl,
      unreadCount: 0,
      isOnline: false,
      isGroup: true,
    );
  }).toList();

  final publicRows = await Future.wait(
    publicRooms.map((r) async {
      final last = await chat.fetchLatestMessageForRoom(r.id);
      return PublicRoomRow(
        room: r,
        preview: _messagePreview(last, uid),
        timeLabel: _timeLabel(last).isEmpty ? null : _timeLabel(last),
      );
    }),
  );

  return HomeOverview(
    dmChats: dmItems,
    groupChats: groupItems,
    publicRooms: publicRows,
  );
});
