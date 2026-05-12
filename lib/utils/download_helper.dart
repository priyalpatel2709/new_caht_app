import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> downloadImage(String url) async {
  if (Platform.isAndroid) {
    await Permission.photos.request();
    await Permission.storage.request();
  }

  final tempDir = await getTemporaryDirectory();

  final filePath =
      '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

  await Dio().download(url, filePath);

  await ImageGallerySaver.saveFile(filePath);
}
