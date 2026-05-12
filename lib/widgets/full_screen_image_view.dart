import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_base_app/utils/download_helper.dart';

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  bool isDownloading = false;

  Future<void> download() async {
    try {
      setState(() {
        isDownloading = true;
      });

      await downloadImage(widget.imageUrl);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Download completed')));
      }
    } catch (e) {
      debugPrint(e.toString());

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Download failed')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isDownloading = false;
        });
      }
    }
  }

  Future<void> shareImage() async {
    try {
      await Share.share(widget.imageUrl, subject: 'Shared Image');
    } catch (e) {
      debugPrint(e.toString());

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Share failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),

        actions: [
          /// Share
          IconButton(onPressed: shareImage, icon: const Icon(Icons.share)),

          /// Download
          IconButton(
            onPressed: isDownloading ? null : download,
            icon: isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
          ),
        ],
      ),

      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(widget.imageUrl),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
