import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

class TemplatesService {
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  static void notifyTemplatesChanged() {
    refreshNotifier.value = refreshNotifier.value + 1;
  }

  static Future<Map<String, dynamic>> listPublicTemplates({
    String? q,
    String? category,
  }) async {
    final qp = <String, String>{};
    if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
    if (category != null && category.trim().isNotEmpty && category != 'All') {
      qp['category'] = category.trim();
    }
    final uri = Uri(path: '/templates', queryParameters: qp);
    return ApiService.get(uri.toString());
  }

  static Future<Map<String, dynamic>> updateTemplateMedia({
    required String token,
    required String templateId,
    File? previewImage,
    List<File>? screenshots,
    File? previewVideo,
  }) async {
    final files = <String, File>{
      if (previewImage != null) 'previewImage': previewImage,
      if (previewVideo != null) 'previewVideo': previewVideo,
    };

    return ApiService.multipartFields(
      '/templates/$templateId/media',
      method: 'POST',
      token: token,
      files: files.isEmpty ? null : files,
      fileLists: {
        if (screenshots != null && screenshots.isNotEmpty) 'screenshots': screenshots,
      },
    );
  }

  static Future<Map<String, dynamic>> getTemplate(String id) async {
    return ApiService.get('/templates/$id');
  }

  static Future<Map<String, dynamic>> getTemplateDownloadUrl({
    required String token,
    required String id,
  }) async {
    return ApiService.get('/templates/$id/download-url', token: token);
  }

  static Future<Map<String, dynamic>> getTemplateAccess({
    required String token,
    required String templateId,
  }) async {
    return ApiService.get('/templates/$templateId/access', token: token);
  }

  static Future<Map<String, dynamic>> generateTemplateAiMetadata({
    required String token,
    required String templateId,
    String? notes,
    bool? overwrite,
  }) async {
    return ApiService.post(
      '/templates/$templateId/ai/generate',
      token: token,
      data: {
        if (notes != null) 'notes': notes,
        if (overwrite != null) 'overwrite': overwrite,
      },
    );
  }

  static Future<Map<String, dynamic>> createTemplatePurchasePaymentSheet({
    required String token,
    required String templateId,
  }) async {
    return ApiService.post(
      '/templates/$templateId/purchase/payment-sheet',
      token: token,
    );
  }

  static Future<Map<String, dynamic>> confirmTemplatePurchase({
    required String token,
    required String templateId,
    required String paymentIntentId,
  }) async {
    return ApiService.post(
      '/templates/$templateId/purchase/confirm',
      token: token,
      data: {
        'paymentIntentId': paymentIntentId,
      },
    );
  }

  static Future<Map<String, dynamic>> listTemplateReviews(String templateId) async {
    return ApiService.get('/templates/$templateId/reviews');
  }

  static Future<Map<String, dynamic>> listPendingTemplateReviews({
    required String token,
    required String templateId,
  }) async {
    return ApiService.get('/templates/$templateId/reviews/pending', token: token);
  }

  static Future<Map<String, dynamic>> approveTemplateReview({
    required String token,
    required String templateId,
    required String userId,
  }) async {
    return ApiService.post('/templates/$templateId/reviews/$userId/approve', token: token);
  }

  static Future<Map<String, dynamic>> submitTemplateReview({
    required String token,
    required String templateId,
    required int rating,
    required String comment,
  }) async {
    return ApiService.post(
      '/templates/$templateId/reviews',
      token: token,
      data: {
        'rating': rating,
        'comment': comment,
      },
    );
  }

  static Future<Map<String, dynamic>> uploadTemplate({
    required String token,
    required File file,
    File? previewImage,
    List<File>? screenshots,
    File? previewVideo,
    String? name,
    String? description,
    String? category,
    String? tagsCsv,
    double? price,
  }) async {
    final files = <String, File>{
      'file': file,
      if (previewImage != null) 'previewImage': previewImage,
      if (previewVideo != null) 'previewVideo': previewVideo,
    };

    return ApiService.multipartFields(
      '/templates/upload',
      method: 'POST',
      token: token,
      files: files,
      fileLists: {
        if (screenshots != null && screenshots.isNotEmpty) 'screenshots': screenshots,
      },
      timeout: const Duration(minutes: 15),
      fields: {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
        if (tagsCsv != null && tagsCsv.trim().isNotEmpty) 'tags': tagsCsv.trim(),
        if (price != null) 'price': price.toString(),
      },
    );
  }
}
