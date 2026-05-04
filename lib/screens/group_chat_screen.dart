import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/group.dart';
import '../models/group_message.dart';
import '../services/group_service.dart';
import '../services/storage_service.dart';
import '../widgets/message_bubble.dart';
import 'group_info_screen.dart';

/// Group chat: calls 22–25 + file flow (24).
class GroupChatScreen extends StatefulWidget {
  final Group group;
  final String myRole;

  const GroupChatScreen({
    super.key,
    required this.group,
    required this.myRole,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  late final Stream<List<Map<String, dynamic>>> _stream;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  bool _sending = false;
  bool _uploading = false;
  double? _uploadProgress;
  int _lastCount = 0;

  String? _myUserId;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _myUserId = Supabase.instance.client.auth.currentUser?.id;
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final id = data.session?.user.id;
      if (!mounted || id == _myUserId) return;
      setState(() => _myUserId = id);
    });
    _stream = context.read<GroupService>().streamGroupMessages(widget.group.id);
    _sub = _stream.listen(
      (_) => _scrollToBottom(),
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Realtime error: $e')),
        );
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _sub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final t = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          t,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(t);
      }
    });
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await context.read<GroupService>().sendGroupTextMessage(
            groupId: widget.group.id,
            text: text,
          );
      if (!mounted) return;
      _controller.clear();
      _scrollToBottom(animated: true);
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _open(GroupMessage m) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? url = m.fileUrl;
      if (m.filePath != null && m.filePath!.isNotEmpty) {
        try {
          final storage = context.read<StorageService>();
          url = await storage.createChatFileSignedUrlForOpen(m.filePath!);
        } on StorageException {
          url = m.fileUrl;
        }
      }
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Cannot open file')),
        );
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on StorageException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _uploadSend({
    required String fileName,
    required Uint8List bytes,
    required String messageType,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0.2;
    });

    try {
      final storage = context.read<StorageService>();
      final groups = context.read<GroupService>();

      final path = await storage.uploadChatFile(
        currentUserId: uid,
        fileName: fileName,
        fileBytes: bytes,
      );
      setState(() => _uploadProgress = 0.55);
      final signed = await storage.createChatFileSignedUrl(path);
      setState(() => _uploadProgress = 0.9);

      try {
        await groups.sendGroupFileMessage(
          groupId: widget.group.id,
          fileName: fileName,
          signedUrl: signed,
          messageType: messageType,
          fileSizeInBytes: bytes.length,
          storagePath: path,
        );
      } on PostgrestException catch (e) {
        final m = e.message.toLowerCase();
        if (m.contains('file_path') || m.contains('column')) {
          await groups.sendGroupFileMessage(
            groupId: widget.group.id,
            fileName: fileName,
            signedUrl: signed,
            messageType: messageType,
            fileSizeInBytes: bytes.length,
          );
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      _scrollToBottom(animated: true);
    } on StorageException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed')),
      );
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _sheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Photo library'),
              onTap: () async {
                Navigator.pop(ctx);
                final x = await ImagePicker()
                    .pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (!mounted) return;
                if (x == null) return;
                await _uploadSend(
                  fileName: x.name,
                  bytes: await x.readAsBytes(),
                  messageType: 'image',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () async {
                Navigator.pop(ctx);
                final r = await FilePicker.platform.pickFiles(withData: true);
                if (!mounted) return;
                if (r == null || r.files.isEmpty) return;
                final f = r.files.first;
                if (f.bytes == null) return;
                await _uploadSend(
                  fileName: f.name,
                  bytes: f.bytes!,
                  messageType: 'file',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupInfoScreen(
                    group: widget.group,
                    myRole: widget.myRole,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_uploading && _uploadProgress != null)
            LinearProgressIndicator(value: _uploadProgress),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snapshot.data!.map(GroupMessage.fromJson).toList();
                if (msgs.length != _lastCount) {
                  _lastCount = msgs.length;
                  _scrollToBottom();
                }
                if (msgs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[i];
                      return GroupMessageBubble(
                        message: m,
                        isMine: m.isFromCurrentUser(_myUserId),
                        onOpenFile: m.messageType == 'file' || m.isImage
                            ? () => _open(m)
                            : null,
                        onOpenImage: m.isImage ? () => _open(m) : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _uploading ? null : _sheet,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendText,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
