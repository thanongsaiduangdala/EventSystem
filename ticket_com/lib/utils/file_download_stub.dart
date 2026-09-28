import 'dart:typed_data';

void downloadBytes({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) {
  throw UnsupportedError('Browser download is only supported on the web.');
}