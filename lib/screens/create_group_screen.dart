import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend_request.dart';
import '../models/group.dart';
import '../services/friend_service.dart';
import '../services/group_service.dart';
import '../services/storage_service.dart';
import 'group_chat_screen.dart';

/// Calls 17–19: create group, optional avatar, add members, open chat.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  List<FriendEdge> _friends = [];
  final Set<String> _selectedFriendIds = {};

  Uint8List? _avatarBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<FriendService>().fetchFriendsList();
      if (!mounted) return;
      setState(() => _friends = list);
    } on PostgrestException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load friends')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final groupService = context.read<GroupService>();
      final storage = context.read<StorageService>();

      final Group group = await groupService.createGroup(
        groupName: name,
        description: _descController.text.trim(),
      );

      var avatarUrl = group.avatarUrl;

      if (_avatarBytes != null) {
        try {
          final path = await storage.uploadGroupAvatarJpeg(
            groupId: group.id,
            imageBytes: _avatarBytes!,
          );
          final url = storage.getGroupAvatarPublicUrl(path);
          await groupService.updateGroupAvatarUrl(
            groupId: group.id,
            avatarUrl: url,
          );
          avatarUrl = url;
        } on StorageException {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group created, but avatar upload failed'),
            ),
          );
        }
      }

      try {
        await groupService.addMembersToGroup(
          groupId: group.id,
          friendUserIds: _selectedFriendIds.toList(),
        );
      } on PostgrestException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add members')),
        );
        return;
      }

      if (!mounted) return;

      final updated = Group(
        id: group.id,
        name: group.name,
        description: group.description,
        avatarUrl: avatarUrl,
        createdBy: group.createdBy,
        createdAt: group.createdAt,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(group: updated, myRole: 'admin'),
        ),
      );
    } on PostgrestException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create group')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: _loading && _friends.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: CircleAvatar(
                    child: _avatarBytes != null
                        ? ClipOval(
                            child: Image.memory(
                              _avatarBytes!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.add_a_photo),
                  ),
                  title: const Text('Group photo (optional)'),
                  onTap: _loading ? null : _pickAvatar,
                ),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add friends',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_friends.isEmpty)
                  const Text('Add friends from the Friends tab first.')
                else
                  ..._friends.map((f) {
                    final id = f.friendId;
                    final sel = _selectedFriendIds.contains(id);
                    return CheckboxListTile(
                      value: sel,
                      onChanged: _loading
                          ? null
                          : (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedFriendIds.add(id);
                                } else {
                                  _selectedFriendIds.remove(id);
                                }
                              });
                            },
                      title: Text(f.friendProfile.username),
                    );
                  }),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create group'),
                ),
              ],
            ),
    );
  }
}
