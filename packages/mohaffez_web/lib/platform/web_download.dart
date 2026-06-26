import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a client-side file download in the browser.
///
/// A UTF-8 BOM is prepended so Excel opens Arabic CSV content correctly.
void downloadCsv(String filename, String csvContent) {
  final bytes = Uint8List.fromList(utf8.encode('﻿$csvContent'));
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// Opens an external URL in a new browser tab/window.
void openExternalUrl(String url) {
  web.window.open(url, '_blank');
}

/// Asks the browser to download an external file.
///
/// Some browsers ignore the download hint for cross-origin URLs and open the
/// file in a new tab instead, which is still better than a silent no-op.
void downloadExternalUrl(String url, {String? filename}) {
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..target = '_blank'
    ..download = filename ?? ''
    ..style.display = 'none';
  anchor.setAttribute('rel', 'noopener');
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

/// Escapes a single CSV cell (quotes, commas, newlines).
String csvCell(Object? value) {
  final s = value?.toString() ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Builds a CSV document from a header row + data rows.
String buildCsv(List<String> header, List<List<Object?>> rows) {
  final buffer = StringBuffer();
  buffer.writeln(header.map(csvCell).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(csvCell).join(','));
  }
  return buffer.toString();
}
