import 'dart:convert';
import 'dart:html' as html;

void downloadCsvWeb(String csv) {
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = 'users_export.csv';
  anchor.click();
  html.Url.revokeObjectUrl(url);
}
