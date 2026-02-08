import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/projects_service.dart';
import '../../widgets/widgets.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ProjectDetailScreen({
    super.key,
    required this.data,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Map<String, dynamic>? _project;
  bool _loading = false;
  String? _error;

  bool _savingEdits = false;

  File? _newPreviewImage;
  List<File> _newScreenshots = [];
  File? _newPreviewVideo;
  bool _uploadingMedia = false;

  @override
  void initState() {
    super.initState();
    _project = widget.data['project'] is Map
        ? Map<String, dynamic>.from(widget.data['project'] as Map)
        : null;
    _loadIfNeeded();
  }

  Future<void> _openEditProjectDialog() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    final id = _projectId();
    if (id == null || id.isEmpty) {
      setState(() => _error = 'Missing project id');
      return;
    }

    final p = _project ?? <String, dynamic>{};
    final name = (p['name'] ?? widget.data['name'] ?? '').toString();
    final description = (p['description'] ?? widget.data['description'] ?? '').toString();

    final nameCtrl = TextEditingController(text: name);
    final descCtrl = TextEditingController(text: description);

    try {
      final res = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: cs.surface,
            title: Text('Edit Project', style: AppTypography.subtitle1),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: descCtrl,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _savingEdits ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: _savingEdits
                    ? null
                    : () async {
                        final newName = nameCtrl.text.trim();
                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Name is required'),
                              backgroundColor: cs.error,
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (res != true) return;
      if (!mounted) return;
      setState(() {
        _savingEdits = true;
        _error = null;
      });

      final updateRes = await ProjectsService.updateProject(
        token: token,
        projectId: id,
        name: nameCtrl.text,
        description: descCtrl.text,
      );
      if (!mounted) return;
      final data = updateRes['data'];
      if (updateRes['success'] == true && data is Map) {
        setState(() {
          _project = Map<String, dynamic>.from(data);
        });
      } else {
        setState(() {
          _error = updateRes['message']?.toString() ?? 'Update failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      nameCtrl.dispose();
      descCtrl.dispose();
      if (!mounted) return;
      setState(() {
        _savingEdits = false;
      });
    }
  }

  Future<void> _openVideoPlayer(String url) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _VideoPlayerDialog(url: url),
    );
  }

  String? _projectId() {
    final fromRoute = widget.data['projectId']?.toString();
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final p = _project;
    final id = p?['_id']?.toString() ?? p?['id']?.toString();
    return (id != null && id.isNotEmpty) ? id : null;
  }

  Future<void> _pickNewPreviewImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: false);
    if (result == null || result.files.isEmpty) return;
    final p = result.files.single.path;
    if (p == null || p.isEmpty) return;
    setState(() {
      _newPreviewImage = File(p);
    });
  }

  Future<void> _pickNewScreenshots() async {
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
      _newScreenshots = files;
    });
  }

  Future<void> _pickNewPreviewVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: false);
    if (result == null || result.files.isEmpty) return;
    final p = result.files.single.path;
    if (p == null || p.isEmpty) return;
    setState(() {
      _newPreviewVideo = File(p);
    });
  }

  Future<void> _uploadMedia() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    final id = _projectId();
    if (id == null || id.isEmpty) {
      setState(() => _error = 'Missing project id');
      return;
    }

    if (_newPreviewImage == null && _newPreviewVideo == null && _newScreenshots.isEmpty) {
      setState(() => _error = 'Please select at least one media file');
      return;
    }

    setState(() {
      _uploadingMedia = true;
      _error = null;
    });

    try {
      final res = await ProjectsService.uploadProjectMedia(
        token: token,
        projectId: id,
        previewImage: _newPreviewImage,
        screenshots: _newScreenshots,
        previewVideo: _newPreviewVideo,
      );
      final data = res['data'];
      if (!mounted) return;
      if (res['success'] == true && data is Map) {
        setState(() {
          _project = Map<String, dynamic>.from(data);
          _newPreviewImage = null;
          _newScreenshots = [];
          _newPreviewVideo = null;
        });
      } else {
        setState(() {
          _error = res['message']?.toString() ?? 'Upload failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _uploadingMedia = false;
      });
    }
  }

  Future<void> _loadIfNeeded() async {
    final projectId = widget.data['projectId']?.toString();
    if (projectId == null || projectId.isEmpty) return;
    if (_project != null && (_project?['_id']?.toString() == projectId || _project?['id']?.toString() == projectId)) {
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ProjectsService.getProject(token: token, projectId: projectId);
      final data = res['data'];
      if (!mounted) return;
      setState(() {
        _project = data is Map ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();

    final p = _project ?? <String, dynamic>{};
    final name = (p['name'] ?? widget.data['name'] ?? 'Project').toString();
    final description = (p['description'] ?? widget.data['description'] ?? '').toString();
    final statusRaw = p['status']?.toString().toLowerCase();
    final statusText = statusRaw == null || statusRaw.isEmpty
        ? 'Unknown'
        : (statusRaw == 'ready'
            ? 'Completed'
            : (statusRaw == 'running' || statusRaw == 'queued')
                ? 'In Progress'
                : statusRaw == 'failed'
                    ? 'Failed'
                    : statusRaw);
    final statusColor = statusRaw == 'ready'
        ? AppColors.success
        : statusRaw == 'failed'
            ? AppColors.error
            : (statusRaw == 'running' || statusRaw == 'queued')
                ? AppColors.warning
                : cs.onSurfaceVariant;

    final previewImageUrl = p['previewImageUrl']?.toString();
    final screenshotUrlsRaw = p['screenshotUrls'];
    final screenshotUrls = (screenshotUrlsRaw is List)
        ? screenshotUrlsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final previewVideoUrl = p['previewVideoUrl']?.toString();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          name,
          style: AppTypography.subtitle1,
        ),
        leading: IconButton(
          onPressed: () => context.go('/dashboard'),
          icon: Icon(
            Icons.arrow_back,
            color: cs.onSurface,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _openEditProjectDialog();
            },
            icon: Icon(
              Icons.edit,
              color: cs.onSurface,
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Share project
              final id = _projectId();
              final p = _project ?? <String, dynamic>{};
              final name = (p['name'] ?? widget.data['name'] ?? 'Project').toString();
              final description = (p['description'] ?? widget.data['description'] ?? '').toString();
              final text = [
                name,
                if (description.trim().isNotEmpty) description.trim(),
                if (id != null && id.isNotEmpty) 'Project ID: $id',
              ].join('\n\n');
              Share.share(text);
            },
            icon: Icon(
              Icons.share,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: AppSpacing.lg),
            ],
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
            // Hero image/preview
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                gradient: AppColors.primaryGradient,
                boxShadow: AppShadows.boxShadowLarge,
              ),
              child: Stack(
                children: [
                  if (previewImageUrl != null && previewImageUrl.trim().isNotEmpty)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        child: Image.network(
                          previewImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.onPrimary.withOpacity(0.12),
                                ),
                                child: Icon(
                                  Icons.games,
                                  size: 50,
                                  color: cs.onPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.onPrimary.withOpacity(0.12),
                        ),
                        child: Icon(
                          Icons.games,
                          size: 50,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  
                  // Play button overlay
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: CustomButton(
                      text: 'Play',
                      onPressed: (previewVideoUrl == null || previewVideoUrl.trim().isEmpty)
                          ? null
                          : () async {
                              await _openVideoPlayer(previewVideoUrl);
                            },
                      type: ButtonType.primary,
                      size: ButtonSize.small,
                      icon: const Icon(Icons.play_arrow),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),

            if (statusRaw == 'ready') ...[
              Text('Media', style: AppTypography.subtitle1),
              const SizedBox(height: AppSpacing.lg),
              Container(
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
                        Expanded(
                          child: Text(
                            _newPreviewImage?.path.split('/').last ?? 'No new preview image',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CustomButton(
                          text: 'Image',
                          onPressed: _uploadingMedia ? null : _pickNewPreviewImage,
                          isFullWidth: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _newScreenshots.isEmpty ? 'No new screenshots' : '${_newScreenshots.length} new screenshot(s)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CustomButton(
                          text: 'Shots',
                          onPressed: _uploadingMedia ? null : _pickNewScreenshots,
                          isFullWidth: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _newPreviewVideo?.path.split('/').last ?? 'No new preview video',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body2.copyWith(color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CustomButton(
                          text: 'Video',
                          onPressed: _uploadingMedia ? null : _pickNewPreviewVideo,
                          isFullWidth: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CustomButton(
                      text: _uploadingMedia ? 'Uploading…' : 'Upload Media',
                      onPressed: _uploadingMedia ? null : _uploadMedia,
                      isFullWidth: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
            
            // Project info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.h2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        description.isEmpty ? '—' : description,
                        style: AppTypography.body1.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  ),
                  child: Text(
                    statusText,
                    style: AppTypography.caption.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Downloads',
                    '1,234',
                    Icons.download,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Rating',
                    '4.8',
                    Icons.star,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Plays',
                    '5.6K',
                    Icons.play_arrow,
                    AppColors.success,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Description
            Text(
              'Description',
              style: AppTypography.subtitle1,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              description.isEmpty ? 'No description' : description,
              style: AppTypography.body1.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Features
            Text(
              'Features',
              style: AppTypography.subtitle1,
            ),
            const SizedBox(height: AppSpacing.lg),
            Column(
              children: [
                _buildFeatureItem('🚀 Multiple spacecraft to choose from'),
                _buildFeatureItem('🌍 Explore procedurally generated planets'),
                _buildFeatureItem('👽 Meet alien species and trade resources'),
                _buildFeatureItem('⚔️ Engage in space combat'),
                _buildFeatureItem('🏗️ Build your own space station'),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Screenshots
            Text(
              'Screenshots',
              style: AppTypography.subtitle1,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (screenshotUrls.isEmpty)
              Text(
                'No screenshots',
                style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: screenshotUrls.length,
                  itemBuilder: (context, index) {
                    final url = screenshotUrls[index];
                    return Container(
                      width: 300,
                      margin: const EdgeInsets.only(right: AppSpacing.lg),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        color: cs.surface,
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(Icons.image, size: 48, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: AppSpacing.xxl),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Edit Project',
                    onPressed: () {
                      _openEditProjectDialog();
                    },
                    type: ButtonType.secondary,
                    icon: const Icon(Icons.edit),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: CustomButton(
                    text: 'Build Game',
                    onPressed: () {
                      context.go('/build-configuration');
                    },
                    type: ButtonType.primary,
                    icon: const Icon(Icons.build),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.subtitle1.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body2,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String url;

  const _VideoPlayerDialog({
    required this.url,
  });

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _init = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: SafeArea(
        child: FutureBuilder<void>(
          future: _init,
          builder: (context, snapshot) {
            final ready = snapshot.connectionState == ConnectionState.done && _controller.value.isInitialized;
            return Stack(
              children: [
                Positioned.fill(
                  child: ready
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio == 0
                                ? 16 / 9
                                : _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                if (ready)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: cs.primary,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                });
                              },
                              icon: Icon(
                                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(_controller.value.position.inSeconds).toString()}s',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
