import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/templates_service.dart';
import '../../widgets/widgets.dart';

class TemplateUploadScreen extends StatefulWidget {
  const TemplateUploadScreen({super.key});

  @override
  State<TemplateUploadScreen> createState() => _TemplateUploadScreenState();
}

class _TemplateUploadScreenState extends State<TemplateUploadScreen> {
  final _formKey = GlobalKey<FormState>();

  File? _zipFile;
  File? _previewImage;
  List<File> _screenshots = [];
  File? _previewVideo;

  final _zipUrlController = TextEditingController();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Action');
  final _tagsController = TextEditingController();
  final _priceController = TextEditingController(text: '0');

  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _zipUrlController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickPreviewImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final p = result.files.single.path;
    if (p == null || p.isEmpty) return;
    setState(() {
      _previewImage = File(p);
    });
  }

  Future<void> _pickScreenshots() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final files = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .map((p) => File(p))
        .toList();
    if (files.isEmpty) return;
    setState(() {
      _screenshots = files;
    });
  }

  Future<void> _pickPreviewVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final p = result.files.single.path;
    if (p == null || p.isEmpty) return;
    setState(() {
      _previewVideo = File(p);
    });
  }

  Future<void> _pickZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null || path.isEmpty) return;

    setState(() {
      _zipFile = File(path);
    });
  }

  Future<void> _upload() async {
    final auth = context.read<AuthProvider>();

    if (!auth.isAuthenticated || auth.token == null) {
      setState(() => _error = 'You must be signed in');
      return;
    }

    if (!auth.isAdmin && !auth.isDevl) {
      setState(() => _error = 'Forbidden: dev/admin role required');
      return;
    }

    if (_zipFile == null) {
      setState(() => _error = 'Please select a .zip file');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final price = double.tryParse(_priceController.text.trim()) ?? 0;

      final res = await TemplatesService.uploadTemplate(
        token: auth.token!,
        file: _zipFile!,
        previewImage: _previewImage,
        screenshots: _screenshots,
        previewVideo: _previewVideo,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        tagsCsv: _tagsController.text.trim(),
        price: price,
      );

      if (res['success'] == true) {
        if (!mounted) return;
        context.pop(true);
        return;
      }

      setState(() {
        _error = res['message']?.toString() ?? 'Upload failed';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _downloadFromUrl() async {
    final raw = _zipUrlController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Please paste a ZIP URL');
      return;
    }

    Uri? uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      uri = null;
    }

    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      setState(() => _error = 'Invalid URL');
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final res = await http.get(uri);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() => _error = 'Download failed (HTTP ${res.statusCode})');
        return;
      }

      final contentType = (res.headers['content-type'] ?? '').toLowerCase();
      if (contentType.contains('text/html')) {
        setState(() => _error = 'URL did not return a ZIP file (received HTML). Use a direct download link.');
        return;
      }

      final bytes = res.bodyBytes;
      if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
        setState(() => _error = 'URL did not return a valid ZIP (missing PK header). Use a direct download link.');
        return;
      }

      final file = File(
        '${Directory.systemTemp.path}/template_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      await file.writeAsBytes(bytes, flush: true);

      setState(() {
        _zipFile = file;
      });
    } catch (e) {
      setState(() {
        _error = 'Download failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('Upload Template', style: AppTypography.subtitle1),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard?tab=templates');
            }
          },
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
        ),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLarge,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: AppColors.error.withOpacity(0.35)),
                  ),
                  child: Text(
                    _error!,
                    style: AppTypography.body2.copyWith(color: cs.onSurface),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text('ZIP URL (optional)', style: AppTypography.subtitle2),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _zipUrlController,
                      decoration: const InputDecoration(
                        hintText: 'https://.../template.zip',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  CustomButton(
                    text: 'Download',
                    onPressed: _uploading ? null : _downloadFromUrl,
                    isFullWidth: false,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Template ZIP', style: AppTypography.subtitle2),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _zipFile?.path.split('/').last ?? 'No file selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body2.copyWith(color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    CustomButton(
                      text: 'Choose',
                      onPressed: _uploading ? null : _pickZip,
                      isFullWidth: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              Text('Preview media (optional)', style: AppTypography.subtitle2),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _previewImage?.path.split('/').last ?? 'No preview image',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CustomButton(
                          text: 'Image',
                          onPressed: _uploading ? null : _pickPreviewImage,
                          isFullWidth: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _screenshots.isEmpty ? 'No screenshots' : '${_screenshots.length} screenshot(s)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CustomButton(
                          text: 'Shots',
                          onPressed: _uploading ? null : _pickScreenshots,
                          isFullWidth: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _previewVideo?.path.split('/').last ?? 'No preview video',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CustomButton(
                          text: 'Video',
                          onPressed: _uploading ? null : _pickPreviewVideo,
                          isFullWidth: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.xxl),
              CustomButton(
                text: _uploading ? 'Uploading...' : 'Upload',
                onPressed: _uploading ? null : _upload,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
