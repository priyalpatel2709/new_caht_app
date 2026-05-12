import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../utils/file_helper.dart';

/// File row: icon, name, optional size, tap main area to open; share & download.
class FileMessageWidget extends StatefulWidget {
  final String fileName;
  final int? fileSizeBytes;
  final VoidCallback? onOpen;
  /// Signed or public URL for cache/download/share. Return null if unavailable.
  final Future<String?> Function()? resolveFileUrl;

  const FileMessageWidget({
    super.key,
    required this.fileName,
    this.fileSizeBytes,
    this.onOpen,
    this.resolveFileUrl,
  });

  String get _sizeLabel {
    final b = fileSizeBytes;
    if (b == null) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  State<FileMessageWidget> createState() => _FileMessageWidgetState();
}

class _FileMessageWidgetState extends State<FileMessageWidget> {
  CancelToken? _cancelToken;
  bool _downloading = false;
  double? _progress;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<String?> _resolvedUrl() async {
    final resolver = widget.resolveFileUrl;
    if (resolver == null) return null;
    return resolver();
  }

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    final url = await _resolvedUrl();
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cannot share file')),
      );
      return;
    }
    try {
      await FileHelper.shareFile(url);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Share failed')),
      );
    }
  }

  Future<void> _startDownload() async {
    final messenger = ScaffoldMessenger.of(context);
    final url = await _resolvedUrl();
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cannot download file')),
      );
      return;
    }

    _cancelToken?.cancel();
    final token = CancelToken();
    setState(() {
      _cancelToken = token;
      _downloading = true;
      _progress = null;
    });

    final file = await FileHelper.downloadFileToTemp(
      url,
      fileName: widget.fileName,
      cancelToken: token,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() {
          _progress = total > 0 ? received / total : null;
        });
      },
    );

    if (!mounted) return;

    setState(() {
      _downloading = false;
      _cancelToken = null;
      _progress = null;
    });

    if (file == null) {
      if (token.isCancelled) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Download cancelled')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Download failed')),
        );
      }
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('Saved: ${file.path}')),
    );
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _cancelToken = null;
      _progress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = IconTheme.of(context).color;
    final canResolve = widget.resolveFileUrl != null;

    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: InkWell(
              onTap: widget.onOpen,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 28,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (_downloading) ...[
                            const SizedBox(height: 6),
                            if (_progress != null)
                              LinearProgressIndicator(
                                value: _progress!.clamp(0.0, 1.0),
                                minHeight: 4,
                              )
                            else
                              const LinearProgressIndicator(minHeight: 4),
                          ] else if (widget._sizeLabel.isNotEmpty)
                            Text(
                              widget._sizeLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (canResolve) ...[
            IconButton(
              onPressed: _share,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              onPressed: _downloading ? _cancelDownload : _startDownload,
              icon: Icon(
                _downloading ? Icons.close : Icons.download_outlined,
              ),
              tooltip: _downloading ? 'Cancel download' : 'Download',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ],
      ),
    );
  }
}
