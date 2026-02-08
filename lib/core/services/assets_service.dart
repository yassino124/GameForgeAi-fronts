import 'dart:io';

import 'api_service.dart';

class AssetsService {
  static Future<Map<String, dynamic>> listAssets({
    required String token,
    String? collectionId,
    String? type,
    String? q,
    int page = 1,
    int limit = 20,
  }) async {
    final qp = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (collectionId != null && collectionId.isNotEmpty) qp['collectionId'] = collectionId;
    if (type != null && type.isNotEmpty) qp['type'] = type;
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();

    final uri = Uri(path: '/assets', queryParameters: qp);
    return ApiService.get(uri.toString(), token: token);
  }

  static Future<Map<String, dynamic>> uploadAssetByUrl({
    required String token,
    required String url,
    required String type,
    String? name,
    String? tagsCsv,
    String? collectionId,
    String? unityPath,
  }) async {
    return ApiService.post(
      '/assets/upload-url',
      token: token,
      data: {
        'url': url.trim(),
        'type': type,
        if (name != null) 'name': name.trim(),
        if (tagsCsv != null) 'tags': tagsCsv.trim(),
        if (collectionId != null) 'collectionId': collectionId,
        if (unityPath != null) 'unityPath': unityPath,
      },
    );
  }

  static Future<Map<String, dynamic>> createCollection({
    required String token,
    required String name,
    String? description,
  }) async {
    return ApiService.post(
      '/assets/collections',
      token: token,
      data: {
        'name': name.trim(),
        if (description != null) 'description': description.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> listCollections({
    required String token,
  }) async {
    return ApiService.get('/assets/collections/list', token: token);
  }

  static Future<Map<String, dynamic>> uploadAsset({
    required String token,
    required File file,
    required String type,
    String? name,
    String? tagsCsv,
    String? collectionId,
    String? unityPath,
  }) async {
    return ApiService.multipart(
      '/assets/upload',
      method: 'POST',
      token: token,
      file: file,
      fileField: 'file',
      fields: {
        'type': type,
        if (name != null) 'name': name,
        if (tagsCsv != null) 'tags': tagsCsv,
        if (collectionId != null) 'collectionId': collectionId,
        if (unityPath != null) 'unityPath': unityPath,
      },
    );
  }

  static Future<Map<String, dynamic>> getDownloadUrl({
    required String token,
    required String assetId,
  }) async {
    return ApiService.get('/assets/$assetId/download-url', token: token);
  }

  static Future<Map<String, dynamic>> getAsset({
    required String token,
    required String assetId,
  }) async {
    return ApiService.get('/assets/$assetId', token: token);
  }

  static Future<Map<String, dynamic>> deleteAsset({
    required String token,
    required String assetId,
  }) async {
    return ApiService.delete('/assets/$assetId', token: token);
  }

  static Future<Map<String, dynamic>> createExport({
    required String token,
    required String collectionId,
    String format = 'zip',
  }) async {
    return ApiService.post(
      '/assets/exports',
      token: token,
      data: {
        'collectionId': collectionId,
        'format': format,
      },
    );
  }

  static Future<Map<String, dynamic>> getExport({
    required String token,
    required String exportId,
  }) async {
    return ApiService.get('/assets/exports/$exportId', token: token);
  }

  static Future<Map<String, dynamic>> getExportDownloadUrl({
    required String token,
    required String exportId,
  }) async {
    return ApiService.get('/assets/exports/$exportId/download-url', token: token);
  }
}
