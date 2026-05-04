import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/friend_service.dart';
import 'services/group_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService(client)),
        Provider<StorageService>(create: (_) => StorageService(client)),
        Provider<ChatService>(create: (_) => ChatService(client)),
        Provider<FriendService>(create: (_) => FriendService(client)),
        Provider<GroupService>(create: (_) => GroupService(client)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Supabase Chat',
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
