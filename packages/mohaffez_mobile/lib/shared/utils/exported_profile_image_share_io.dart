import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> shareExportedProfileImage(
  Uint8List bytes, {
  required String fileName,
  required String text,
}) {
  return Share.shareXFiles(
    [
      XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'image/png',
      ),
    ],
    text: text,
  );
}
