import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/friend_service.dart';
import '../../services/group_service.dart';
import '../../services/storage_service.dart';

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(supabaseProvider)),
);

final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService(ref.watch(supabaseProvider)),
);

final friendServiceProvider = Provider<FriendService>(
  (ref) => FriendService(ref.watch(supabaseProvider)),
);

final groupServiceProvider = Provider<GroupService>(
  (ref) => GroupService(ref.watch(supabaseProvider)),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(supabaseProvider)),
);
