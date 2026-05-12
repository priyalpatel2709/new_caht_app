import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileHelper {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 5),

      // Important
      responseType: ResponseType.stream,

      headers: {
        HttpHeaders.acceptEncodingHeader: '*',
        HttpHeaders.connectionHeader: 'keep-alive',
      },
    ),
  );

  /// Saves [url] into a temp file. Pass a dedicated [cancelToken] per download
  /// so the UI can cancel without affecting other transfers.
  static Future<File?> downloadFileToTemp(
    String url, {
    required String fileName,
    required CancelToken cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName = _safeFileName(fileName);
      final path = '${dir.path}/$safeName';
      final file = File(path);

      await _dio.download(
        url,
        path,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: onProgress,
      );

      return file;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        debugPrint('Download cancelled');
      } else {
        debugPrint(e.toString());
      }
      return null;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static String _safeFileName(String name) {
    final trimmed = name.trim();
    final base = trimmed.isEmpty
        ? 'download'
        : trimmed.replaceAll(RegExp(r'[/\\]'), '_');
    return base.length > 200 ? base.substring(0, 200) : base;
  }

  static Future<File?> downloadFileV2(
    String url, {
    String? fileName,
    Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();

      final name = fileName ?? url.split('/').last.split('?').first;

      final path = '${dir.path}/$name';

      final file = File(path);

      /// Already downloaded
      if (await file.exists()) {
        return file;
      }

      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream),
      );

      final raf = file.openSync(mode: FileMode.write);

      int received = 0;

      final total =
          int.tryParse(
            response.headers.value(Headers.contentLengthHeader) ?? '0',
          ) ??
          0;

      await response.data!.stream
          .listen(
            (chunk) {
              received += chunk.length;

              raf.writeFromSync(chunk);

              onProgress?.call(received, total);
            },
            onDone: () async {
              await raf.close();
            },
          )
          .asFuture();

      return file;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<void> openFile(String url) async {
    final file = await DefaultCacheManager().getSingleFile(url);

    await OpenFilex.open(file.path);
  }

  static Future<void> shareFile(String url) async {
    final file = await DefaultCacheManager().getSingleFile(url);

    final params = ShareParams(files: [XFile(file.path)]);

    final result = await SharePlus.instance.share(params);
    if (result.status == ShareResultStatus.success) {
      print('Thank you for sharing the picture!');
    }
  }
}
