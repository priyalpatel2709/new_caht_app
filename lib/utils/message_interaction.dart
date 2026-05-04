import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens URLs, mailto:, and tel: from [LinkableElement]s (used with linkify).
Future<void> openLinkableElement(
  BuildContext context,
  LinkableElement link,
) async {
  var uri = Uri.tryParse(link.url);
  if (uri == null || uri.scheme.isEmpty) {
    _briefSnack(context, 'Invalid link');
    return;
  }

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _briefSnack(context, 'Could not open link');
    }
  } catch (_) {
    if (context.mounted) {
      _briefSnack(context, 'Could not open link');
    }
  }
}

void _briefSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

Future<void> copyMessageToClipboard(BuildContext context, String text) async {
  final t = text.trim();
  if (t.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: t));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(
      content: Text('Copied to clipboard'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
