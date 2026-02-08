import 'dart:io';

import 'api_service.dart';

class ProjectsService {
  static Future<Map<String, dynamic>> listProjects({
    required String token,
  }) async {
    return ApiService.get('/projects', token: token);
  }

  static Future<Map<String, dynamic>> updateProject({
    required String token,
    required String projectId,
    String? name,
    String? description,
  }) async {
    return ApiService.put(
      '/projects/$projectId',
      token: token,
      data: {
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> createFromTemplate({
    required String token,
    required String templateId,
    required String name,
    String? description,
    String? assetsCollectionId,
  }) async {
    return ApiService.post(
      '/projects/from-template',
      token: token,
      data: {
        'templateId': templateId,
        'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (assetsCollectionId != null) 'assetsCollectionId': assetsCollectionId,
      },
    );
  }

  static Future<Map<String, dynamic>> getProject({
    required String token,
    required String projectId,
  }) async {
    return ApiService.get('/projects/$projectId', token: token);
  }

  static Future<Map<String, dynamic>> getProjectDownloadUrl({
    required String token,
    required String projectId,
  }) async {
    return ApiService.get('/projects/$projectId/download-url', token: token);
  }

  static Future<Map<String, dynamic>> uploadProjectMedia({
    required String token,
    required String projectId,
    File? previewImage,
    List<File>? screenshots,
    File? previewVideo,
  }) async {
    final files = <String, File>{
      if (previewImage != null) 'previewImage': previewImage,
      if (previewVideo != null) 'previewVideo': previewVideo,
    };

    return ApiService.multipartFields(
      '/projects/$projectId/media',
      method: 'POST',
      token: token,
      files: files.isEmpty ? null : files,
      fileLists: {
        if (screenshots != null && screenshots.isNotEmpty) 'screenshots': screenshots,
      },
    );
  }
}
