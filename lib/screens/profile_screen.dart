import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  /// When `true`, no [Scaffold] — for embedding inside [HomeScreen] tab.
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();

  Profile? _profile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final profile = await context.read<ChatService>().fetchUserProfile(userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _usernameController.text = profile.username;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<ChatService>().updateUsername(newUsername);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      await _loadProfile();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final lower = e.message.toLowerCase();
      final message = lower.contains('duplicate') || lower.contains('unique')
          ? 'Username already taken'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (x == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final bytes = await x.readAsBytes();
      if (!mounted) return;
      final storage = context.read<StorageService>();
      final path = await storage.uploadUserAvatar(userId: uid, imageBytes: bytes);
      final publicUrl = storage.getUserAvatarPublicUrl(path);

      await Supabase.instance.client.from('profiles').update({
        'avatar_url': publicUrl,
      }).eq('id', uid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated')),
      );
      await _loadProfile();
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AuthService>().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _profile?.avatarUrl;

    final body = _isLoading && _profile == null
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? const Icon(Icons.person_outline, size: 48)
                            : null,
                      ),
                      IconButton.filled(
                        onPressed: _isLoading ? null : _pickAvatar,
                        icon: const Icon(Icons.camera_alt, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _profile?.username ?? 'Unknown user',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateUsername,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Username'),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: body,
    );
  }
}
