import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message.dart';
import '../models/room.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../widgets/message_bubble.dart';

/// DM chat: text + images/files (calls 12–16), realtime stream, auto-scroll.
class ChatScreen extends StatefulWidget {
  final Room room;
  final String? titleOverride;

  const ChatScreen({
    super.key,
    required this.room,
    this.titleOverride,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  late final Stream<List<Map<String, dynamic>>> _messageStream;
  StreamSubscription<List<Map<String, dynamic>>>? _streamSubscription;

  bool _isSending = false;
  bool _uploading = false;
  double? _uploadProgress;
  int _lastMessageCount = 0;

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
    _messageStream =
        context.read<ChatService>().streamMessagesForRoom(widget.room.id);

    _streamSubscription = _messageStream.listen(
      (_) => _scrollToBottom(),
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Realtime error: $error')),
        );
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _streamSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openAttachment(Message m) async {
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
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Cannot open file')),
        );
      }
    } on StorageException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await context.read<ChatService>().sendMessage(
            roomId: widget.room.id,
            text: text,
          );

      if (!mounted) return;
      _messageController.clear();
      _scrollToBottom(animated: true);
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;

    await _uploadAndSend(
      fileName: x.name,
      bytes: await x.readAsBytes(),
      messageType: 'image',
    );
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file data')),
      );
      return;
    }
    final name = f.name;
    await _uploadAndSend(
      fileName: name,
      bytes: bytes,
      messageType: 'file',
    );
  }

  Future<void> _uploadAndSend({
    required String fileName,
    required Uint8List bytes,
    required String messageType,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final storage = context.read<StorageService>();
      final chat = context.read<ChatService>();

      setState(() => _uploadProgress = 0.25);
      final path = await storage.uploadChatFile(
        currentUserId: uid,
        fileName: fileName,
        fileBytes: bytes,
      );

      setState(() => _uploadProgress = 0.6);
      final signedUrl = await storage.createChatFileSignedUrl(path);

      setState(() => _uploadProgress = 0.9);
      try {
        await chat.sendFileMessage(
          roomId: widget.room.id,
          fileName: fileName,
          signedUrl: signedUrl,
          messageType: messageType,
          fileSizeInBytes: bytes.length,
          storagePath: path,
        );
      } on PostgrestException catch (e) {
        final m = e.message.toLowerCase();
        if (m.contains('file_path') || m.contains('column')) {
          await chat.sendFileMessage(
            roomId: widget.room.id,
            fileName: fileName,
            signedUrl: signedUrl,
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed')),
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
        setState(() {
          _uploading = false;
          _uploadProgress = null;
        });
      }
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _showAttachmentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Photo library'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('File'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.titleOverride ??
        (widget.room.name.startsWith('dm|') ? 'Chat' : widget.room.name);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (_uploading && _uploadProgress != null)
            LinearProgressIndicator(value: _uploadProgress),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messageStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load messages: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!
                    .map(Message.fromJson)
                    .toList(growable: false);

                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                }

                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(
                      message: message,
                      isMine: message.isFromCurrentUser(_myUserId),
                      onOpenFile: message.isFile || message.isImage
                          ? () => _openAttachment(message)
                          : null,
                      onOpenImage: message.isImage
                          ? () => _openAttachment(message)
                          : null,
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
                    onPressed: _uploading ? null : _showAttachmentSheet,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendText,
                    icon: _isSending
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
