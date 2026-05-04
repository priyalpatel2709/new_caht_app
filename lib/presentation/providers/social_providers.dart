import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/friend_request.dart' show FriendEdge, FriendRequest;
import '../../models/outgoing_friend_request.dart';
import '../../models/profile.dart';
import 'service_providers.dart';

final currentUserProfileProvider =
    FutureProvider.autoDispose<Profile>((ref) async {
  final uid = ref.watch(supabaseProvider).auth.currentUser?.id;
  if (uid == null) {
    throw StateError('Unauthenticated');
  }
  return ref.watch(chatServiceProvider).fetchUserProfile(uid);
});

final friendsListProvider = FutureProvider.autoDispose<List<FriendEdge>>((ref) {
  return ref.watch(friendServiceProvider).fetchFriendsList();
});

final incomingFriendRequestsProvider =
    StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  return ref.watch(friendServiceProvider).streamIncomingPendingRequests();
});

final outgoingFriendRequestsProvider =
    FutureProvider.autoDispose<List<OutgoingFriendRequest>>((ref) {
  return ref.watch(friendServiceProvider).fetchOutgoingPendingRequests();
});

final incomingFriendRequestCountProvider =
    StreamProvider.autoDispose<int>((ref) {
  return ref.watch(friendServiceProvider).watchIncomingPendingCount();
});
