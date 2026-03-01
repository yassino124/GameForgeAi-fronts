import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/ai_service.dart';
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
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priceController = TextEditingController(text: '0');

  final _aiNotesController = TextEditingController();
  bool _generatingAi = false;
  bool _generatingCover = false;

  bool _uploading = false;
  String? _error;

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: AppTypography.subtitle2)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _mediaThumb({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(color: Colors.black.withOpacity(0.08), child: child),
      ),
    );
  }

  @override
  void dispose() {
    _zipUrlController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    _aiNotesController.dispose();
    super.dispose();
  }

  Future<void> _generateCoverImage() async {
    if (_generatingCover) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }
    if (!auth.isAdmin && !auth.isDevl) {
      setState(() => _error = 'Forbidden: dev/admin role required');
      return;
    }

    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'Please write a description first');
      return;
    }

    final prompt =
        'Create a high quality game template cover image. Style: modern, clean, colorful. No text. ' +
        'Based on this description: ${desc}';

    setState(() {
      _generatingCover = true;
      _error = null;
    });

    try {
      final res = await AiService.generateImage(
        token: token,
        prompt: prompt,
        timeout: const Duration(seconds: 180),
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final b64 = data['base64']?.toString();
        final mime = data['mimeType']?.toString() ?? 'image/png';
        if (b64 == null || b64.isEmpty) throw Exception('Missing base64');

        final bytes = base64Decode(b64);
        final ext = mime.contains('jpeg') ? 'jpg' : 'png';
        final f = File('${Directory.systemTemp.path}/ai_cover_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await f.writeAsBytes(bytes, flush: true);

        if (!mounted) return;
        setState(() {
          _previewImage = f;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover image generated')),
        );
      } else {
        final msg = res['message']?.toString() ?? 'Failed to generate image';
        setState(() => _error = msg);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } on TimeoutException {
      if (!mounted) return;
      const msg = 'Image generation is taking too long. Please try again in a minute.';
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final lower = raw.toLowerCase();
      final msg = lower.contains('quota') || lower.contains('resource_exhausted')
          ? 'Gemini quota exceeded. Please change API key/billing or try later.'
          : 'Failed to generate image: $raw';
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (!mounted) return;
      setState(() {
        _generatingCover = false;
      });
    }
  }

  Future<void> _generateWithAi() async {
    if (_generatingAi) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }
    if (!auth.isAdmin && !auth.isDevl) {
      setState(() => _error = 'Forbidden: dev/admin role required');
      return;
    }

    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'Please write a description first');
      return;
    }

    setState(() {
      _generatingAi = true;
      _error = null;
    });

    try {
      final notes = _aiNotesController.text.trim();
      final res = await AiService.generateTemplateDraft(
        token: token,
        description: desc,
        notes: notes.isEmpty ? null : notes,
      );

      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        setState(() {
          final name = data['name']?.toString();
          final description = data['description']?.toString();
          final category = data['category']?.toString();

          if (name != null && name.trim().isNotEmpty) _nameController.text = name;
          if (description != null && description.trim().isNotEmpty) _descriptionController.text = description;
          if (category != null && category.trim().isNotEmpty) _categoryController.text = category;

          final tags = (data['tags'] is List)
              ? (data['tags'] as List)
                  .map((e) => e?.toString() ?? '')
                  .where((e) => e.trim().isNotEmpty)
                  .toList()
              : <String>[];
          if (tags.isNotEmpty) {
            _tagsController.text = tags.join(', ');
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI draft generated')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to generate draft')),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _generatingAi = false;
      });
    }
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

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final category = _categoryController.text.trim();
      final tags = _tagsController.text.trim();

      final res = await TemplatesService.uploadTemplate(
        token: auth.token!,
        file: _zipFile!,
        previewImage: _previewImage,
        screenshots: _screenshots.isEmpty ? null : _screenshots,
        previewVideo: _previewVideo,
        name: name.isEmpty ? null : name,
        description: description.isEmpty ? null : description,
        category: category.isEmpty ? null : category,
        tagsCsv: tags.isEmpty ? null : tags,
        price: double.tryParse(_priceController.text.trim()),
      ).timeout(const Duration(minutes: 2));

      if (res['success'] == true) {
        if (!mounted) return;
        TemplatesService.notifyTemplatesChanged();
        context.pop(true);
        return;
      }

      setState(() {
        _error = res['message']?.toString() ?? 'Upload failed';
      });
    } on TimeoutException {
      setState(() {
        _error = 'Upload timed out. Please try again or use a smaller ZIP.';
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
    final auth = context.read<AuthProvider>();

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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: CustomButton(
            text: _uploading ? 'Uploading…' : 'Upload template',
            onPressed: _uploading ? null : _upload,
            isFullWidth: true,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLarge,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary.withOpacity(0.22), cs.surface.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Publish a Unity template', style: AppTypography.subtitle1),
                    const SizedBox(height: 6),
                    Text(
                      'ZIP is required. Media & metadata are optional and can be generated automatically.',
                      style: AppTypography.body2.copyWith(color: cs.onSurface.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

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

              _sectionCard(
                context: context,
                title: 'Get ZIP',
                icon: Icons.link,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _zipUrlController,
                            decoration: const InputDecoration(hintText: 'https://.../template.zip'),
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
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _zipFile?.path.split('/').last ?? 'No ZIP selected yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface.withOpacity(0.85)),
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
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              _sectionCard(
                context: context,
                title: 'Preview media (optional)',
                icon: Icons.perm_media,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_previewImage != null) ...[
                      _mediaThumb(
                        child: Image.file(_previewImage!, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _previewImage?.path.split('/').last ?? 'No preview image',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface.withOpacity(0.85)),
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
                    const SizedBox(height: AppSpacing.md),
                    if (_screenshots.isNotEmpty) ...[
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _screenshots.length,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                          itemBuilder: (context, i) {
                            final f = _screenshots[i];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.file(f, fit: BoxFit.cover),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _screenshots.isEmpty ? 'No screenshots' : '${_screenshots.length} screenshot(s)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface.withOpacity(0.85)),
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
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _previewVideo?.path.split('/').last ?? 'No preview video',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface.withOpacity(0.85)),
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

              const SizedBox(height: AppSpacing.lg),

              _sectionCard(
                context: context,
                title: 'Details (optional)',
                icon: Icons.edit,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name (optional)'),
                      validator: (_) => null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(labelText: 'Category (optional)'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(labelText: 'Tags (comma separated, optional)'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),

              if (auth.isAdmin || auth.isDevl) ...[
                const SizedBox(height: AppSpacing.lg),
                _sectionCard(
                  context: context,
                  title: 'AI helpers',
                  icon: Icons.auto_awesome,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _aiNotesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Notes (optional)'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CustomButton(
                        text: _generatingAi ? 'Generating…' : 'Generate with Gemini',
                        onPressed: _generatingAi ? null : _generateWithAi,
                        isFullWidth: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CustomButton(
                        text: _generatingCover ? 'Generating image…' : 'Generate cover image',
                        onPressed: (_generatingAi || _generatingCover) ? null : _generateCoverImage,
                        isFullWidth: true,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }
}
