import 'dart:io';

import 'api_service.dart';

class ProjectsService {
  static String? _normHex(String? v) {
    if (v == null) return null;
    var s = v.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('#') && s.length == 6) s = '#$s';
    return s;
  }

  static Future<Map<String, dynamic>> createFromModulesAi({
    required String token,
    required String prompt,
  }) async {
    return ApiService.post(
      '/ai/generate-template-from-modules',
      token: token,
      data: {
        'prompt': prompt.trim(),
      },
      timeout: const Duration(seconds: 120),
    );
  }

  static Future<Map<String, dynamic>> listProjects({
    required String token,
  }) async {
    return ApiService.get('/projects', token: token);
  }

  static Future<Map<String, dynamic>> updateProject({
    required String token,
    required String projectId,
    String? buildTarget,
    String? name,
    String? description,
    double? timeScale,
    double? difficulty,
    String? theme,
    String? notes,
    double? speed,
    String? genre,
    String? assetsType,
    List<String>? mechanics,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? playerColor,
    bool? fogEnabled,
    double? fogDensity,
    double? cameraZoom,
    double? gravityY,
    double? jumpForce,
  }) async {
    return ApiService.put(
      '/projects/$projectId',
      token: token,
      data: {
        if (buildTarget != null) 'buildTarget': buildTarget.trim(),
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (timeScale != null) 'timeScale': timeScale,
        if (difficulty != null) 'difficulty': difficulty,
        if (theme != null) 'theme': theme.trim(),
        if (notes != null) 'notes': notes.trim(),
        if (speed != null) 'speed': speed,
        if (genre != null) 'genre': genre.trim(),
        if (assetsType != null) 'assetsType': assetsType.trim(),
        if (mechanics != null) 'mechanics': mechanics,
        if (_normHex(primaryColor) != null) 'primaryColor': _normHex(primaryColor),
        if (_normHex(secondaryColor) != null) 'secondaryColor': _normHex(secondaryColor),
        if (_normHex(accentColor) != null) 'accentColor': _normHex(accentColor),
        if (_normHex(playerColor) != null) 'playerColor': _normHex(playerColor),
        if (fogEnabled != null) 'fogEnabled': fogEnabled,
        if (fogDensity != null) 'fogDensity': fogDensity,
        if (cameraZoom != null) 'cameraZoom': cameraZoom,
        if (gravityY != null) 'gravityY': gravityY,
        if (jumpForce != null) 'jumpForce': jumpForce,
      },
    );
  }

  static Future<Map<String, dynamic>> createFromAi({
    required String token,
    required String prompt,
    String? buildTarget,
    String? templateId,
    double? timeScale,
    double? difficulty,
    String? theme,
    String? notes,
    double? speed,
    String? genre,
    String? assetsType,
    List<String>? mechanics,
    String? primaryColor,
    String? secondaryColor,
    String? accentColor,
    String? playerColor,
    bool? fogEnabled,
    double? fogDensity,
    double? cameraZoom,
    double? gravityY,
    double? jumpForce,
  }) async {
    final runtimeConfig = <String, dynamic>{
      if (timeScale != null) 'timeScale': timeScale,
      if (difficulty != null) 'difficulty': difficulty,
      if (speed != null) 'speed': speed,
      if (_normHex(primaryColor) != null) 'primaryColor': _normHex(primaryColor),
      if (_normHex(secondaryColor) != null) 'secondaryColor': _normHex(secondaryColor),
      if (_normHex(accentColor) != null) 'accentColor': _normHex(accentColor),
      if (_normHex(playerColor) != null) 'playerColor': _normHex(playerColor),
      if (fogEnabled != null) 'fogEnabled': fogEnabled,
      if (fogDensity != null) 'fogDensity': fogDensity,
      if (cameraZoom != null) 'cameraZoom': cameraZoom,
      if (gravityY != null) 'gravityY': gravityY,
      if (jumpForce != null) 'jumpForce': jumpForce,
    };

    return ApiService.post(
      '/projects/ai/create',
      token: token,
      data: {
        'prompt': prompt.trim(),
        if (buildTarget != null) 'buildTarget': buildTarget.trim(),
        if (templateId != null) 'templateId': templateId,
        if (runtimeConfig.isNotEmpty) 'runtimeConfig': runtimeConfig,
        if (timeScale != null) 'timeScale': timeScale,
        if (difficulty != null) 'difficulty': difficulty,
        if (theme != null) 'theme': theme.trim(),
        if (notes != null) 'notes': notes.trim(),
        if (speed != null) 'speed': speed,
        if (genre != null) 'genre': genre.trim(),
        if (assetsType != null) 'assetsType': assetsType.trim(),
        if (mechanics != null) 'mechanics': mechanics,
        if (_normHex(primaryColor) != null) 'primaryColor': _normHex(primaryColor),
        if (_normHex(secondaryColor) != null) 'secondaryColor': _normHex(secondaryColor),
        if (_normHex(accentColor) != null) 'accentColor': _normHex(accentColor),
        if (_normHex(playerColor) != null) 'playerColor': _normHex(playerColor),
        if (fogEnabled != null) 'fogEnabled': fogEnabled,
        if (fogDensity != null) 'fogDensity': fogDensity,
        if (cameraZoom != null) 'cameraZoom': cameraZoom,
        if (gravityY != null) 'gravityY': gravityY,
        if (jumpForce != null) 'jumpForce': jumpForce,
      },
      timeout: const Duration(seconds: 120),
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
    String? target,
  }) async {
    final t = (target ?? '').trim();
    final suffix = t.isEmpty ? '' : '?target=${Uri.encodeComponent(t)}';
    return ApiService.get('/projects/$projectId/download-url$suffix', token: token);
  }

  static Future<Map<String, dynamic>> getProjectPreviewUrl({
    required String token,
    required String projectId,
  }) async {
    return ApiService.get('/projects/$projectId/preview-url', token: token);
  }

  static Future<Map<String, dynamic>> rebuildProject({
    required String token,
    required String projectId,
  }) async {
    return ApiService.post('/projects/$projectId/rebuild', token: token);
  }

  static Future<Map<String, dynamic>> cancelBuild({
    required String token,
    required String projectId,
  }) async {
    return ApiService.post('/projects/$projectId/cancel', token: token);
  }

  static Future<Map<String, dynamic>> getProjectRuntimeConfig({
    required String token,
    required String projectId,
  }) async {
    final t = Uri.encodeComponent(token);
    return ApiService.get('/projects/$projectId/runtime-config?token=$t');
  }

  static Future<Map<String, dynamic>> generateProjectAiMetadata({
    required String token,
    required String projectId,
    String? notes,
    bool? overwrite,
  }) async {
    return ApiService.post(
      '/projects/$projectId/ai/generate',
      token: token,
      data: {
        if (notes != null) 'notes': notes,
        if (overwrite != null) 'overwrite': overwrite,
      },
    );
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
