import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/chat/group_chat_screen.dart';
import '../../screens/friends/friend_requests_screen.dart';
import '../../screens/friends/friends_list_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/app_providers.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.watch(authRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final isSplash = loc == '/splash';
      final isAuth = loc == '/login' || loc == '/signup';

      if (isSplash) return null;
      if (!loggedIn && !isAuth) return '/login';
      if (loggedIn && isAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? 'Chat';
          final online = state.uri.queryParameters['online'] == '1';
          final avatar = state.uri.queryParameters['avatar'];
          return ChatScreen(
            chatId: id,
            title: name,
            isOnline: online,
            avatarUrl: avatar,
          );
        },
      ),
      GoRoute(
        path: '/group/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? 'Group';
          return GroupChatScreen(
            groupId: id,
            title: name,
          );
        },
      ),
      GoRoute(
        path: '/friends',
        builder: (context, state) => const FriendsListScreen(),
      ),
      GoRoute(
        path: '/friend-requests',
        builder: (context, state) => const FriendRequestsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
    ],
  );
});
