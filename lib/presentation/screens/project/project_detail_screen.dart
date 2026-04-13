import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/game_feed_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/services/trailers_service.dart';
import '../../../core/services/app_notifier.dart';
import '../../widgets/widgets.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ProjectDetailScreen({super.key, required this.data});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _project;
  bool _loading = false;

  String? _previewUrl;
  String? _downloadUrl;
  bool _trailerGenerating = false;
  String? _trailerStage;
  String? _trailerVideoUrl;
  String? _trailerId;
  int? _trailerEtaSec;
  Timer? _trailerEtaTicker;
  String _trailerStyle = 'energetic';
  String _trailerTarget = 'tiktok';

  late final AnimationController _heroGlow;
  late final AnimationController _neonCtrl;
  late final AnimationController _introAnim;

  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _heroGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _neonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _introAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _project = widget.data['project'] is Map
        ? Map<String, dynamic>.from(widget.data['project'] as Map)
        : null;
    _loadIfNeeded();
  }

  @override
  void dispose() {
    _trailerEtaTicker?.cancel();
    _heroGlow.dispose();
    _neonCtrl.dispose();
    _introAnim.dispose();
    super.dispose();
  }

  void _restartTrailerEtaTicker() {
    _trailerEtaTicker?.cancel();
    _trailerEtaTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_trailerGenerating) return;
      final cur = _trailerEtaSec;
      if (cur == null || cur <= 0) return;
      setState(() {
        _trailerEtaSec = cur - 1;
      });
    });
  }

  String _fmtEta(int? sec) {
    if (sec == null || sec <= 0) return 'soon';
    if (sec < 60) return '${sec}s';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  Future<void> _loadIfNeeded() async {
    final id = _projectId();
    if (id == null) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final res = await ProjectsService.getProject(token: token, projectId: id);
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final p = Map<String, dynamic>.from(res['data'] as Map);
        final status = (p['status']?.toString() ?? '').trim().toLowerCase();
        final buildTarget = (p['buildTarget']?.toString() ?? '')
            .trim()
            .toLowerCase();

        String? previewUrl;
        String? downloadUrl;
        if (status == 'ready') {
          try {
            final prRes = await ProjectsService.getProjectPreviewUrl(
              token: token,
              projectId: id,
            );
            if (prRes['success'] == true && prRes['data'] is Map) {
              previewUrl = (prRes['data'] as Map)['url']?.toString();
            }
          } catch (_) {}

          try {
            final dRes = await ProjectsService.getProjectDownloadUrl(
              token: token,
              projectId: id,
              target: buildTarget.isEmpty ? null : buildTarget,
            );
            if (dRes['success'] == true && dRes['data'] is Map) {
              downloadUrl = (dRes['data'] as Map)['url']?.toString();
            }
          } catch (_) {}
        }

        setState(() {
          _project = p;
          _previewUrl = (previewUrl?.trim().isNotEmpty == true)
              ? previewUrl!.trim()
              : _previewUrl;
          _downloadUrl = (downloadUrl?.trim().isNotEmpty == true)
              ? downloadUrl!.trim()
              : _downloadUrl;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _projectId() =>
      _project?['_id'] ?? widget.data['projectId']?.toString();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = _project ?? widget.data;
    final name = (p['name'] ?? p['title'] ?? 'Neural Build')
        .toString()
        .toUpperCase();
    final buildTarget = (p['buildTarget']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final status = (p['status']?.toString() ?? '').trim().toLowerCase();
    final isReady = status == 'ready';
    final pid = _projectId();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF05060A) : cs.surface,
      body: Stack(
        children: [
          // Cinematic Mesh Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _introAnim,
              builder: (context, _) => CustomPaint(
                painter: _NeuralMeshPainter(
                  color1: AppColors.primary.withOpacity(isDark ? 0.12 : 0.08),
                  color2: AppColors.accent.withOpacity(isDark ? 0.08 : 0.06),
                  progress: _introAnim.value,
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(
                name,
                cs,
                projectId: pid,
                isReady: isReady,
                project: p,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroCard(p, cs),
                      const SizedBox(height: 32),
                      _buildSectionTitle('SYSTEM STATUS'),
                      const SizedBox(height: 16),
                      _buildStatusGrid(p, cs),
                      const SizedBox(height: 32),
                      _buildSectionTitle('CORE ACTIONS'),
                      const SizedBox(height: 16),
                      _buildActionGrid(
                        context,
                        cs,
                        buildTarget: buildTarget,
                        isReady: isReady,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
    String name,
    ColorScheme cs, {
    required String? projectId,
    required bool isReady,
    required Map<String, dynamic> project,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : cs.onSurface,
          size: 20,
        ),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
            return;
          }
          context.go('/dashboard?tab=projects');
        },
      ),
      title: Text(
        name,
        style: AppTypography.labelLarge.copyWith(
          color: isDark ? Colors.white : cs.onSurface,
          letterSpacing: 2,
          fontWeight: FontWeight.w900,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.publish_rounded,
            color: isReady
                ? (isDark ? Colors.white : cs.primary)
                : (isDark
                      ? Colors.white.withOpacity(0.35)
                      : cs.onSurface.withOpacity(0.35)),
            size: 20,
          ),
          onPressed: (!isReady || (projectId ?? '').trim().isEmpty)
              ? null
              : () => _onPublishToFeed(projectId: projectId!, project: project),
        ),
        IconButton(
          icon: Icon(
            Icons.share_rounded,
            color: isDark ? Colors.white : cs.onSurface,
            size: 20,
          ),
          onPressed: _onShare,
        ),
      ],
    );
  }

  Future<void> _onPublishToFeed({
    required String projectId,
    required Map<String, dynamic> project,
  }) async {
    if (_loading) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.trim().isEmpty) {
      AppNotifier.showError('Session expired. Please sign in again.');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final title = (project['name'] ?? project['title'] ?? '')
          .toString()
          .trim();
      final desc = (project['description'] ?? '').toString().trim();
      final res = await GameFeedService.publish(
        token: token,
        projectId: projectId,
        title: title.isEmpty ? null : title,
        description: desc.isEmpty ? null : desc,
      );

      if (!mounted) return;
      if (res['success'] == true) {
        AppNotifier.showSuccess('Published to feed');
      } else {
        AppNotifier.showError(
          res['message']?.toString() ?? 'Failed to publish',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError('Failed to publish: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildHeroCard(Map<String, dynamic> p, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thumb = ApiService.normalizeImageUrl(
      (p['previewImageUrl'] ??
              p['thumbnailUrl'] ??
              p['iconUrl'] ??
              p['imageUrl'] ??
              p['previewImage'] ??
              p['image'] ??
              (p['media'] is Map
                  ? (p['media'] as Map)['previewImage']
                  : null) ??
              (p['media'] is Map ? (p['media'] as Map)['thumbnailUrl'] : null))
          ?.toString(),
    );

    final videoUrl = _resolvePreviewVideoUrl(p);
    return AnimatedCard(
      duration: const Duration(milliseconds: 1000),
      slideY: 40,
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : cs.outlineVariant.withOpacity(0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb.isNotEmpty)
                Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                    );
                  },
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              // Glass Overlay
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (isDark ? Colors.black : Colors.white).withOpacity(
                            isDark ? 0.8 : 0.9,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p['name'] ?? p['title'] ?? 'Project').toString(),
                      style: AppTypography.displaySmall.copyWith(
                        color: isDark ? Colors.white : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'STABLE NEURAL BUILD v1.0',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              if (videoUrl.trim().isNotEmpty)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _openVideoPreview(videoUrl),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Text(
      title,
      style: AppTypography.labelSmall.copyWith(
        color: isDark ? Colors.white38 : cs.onSurfaceVariant,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildStatusGrid(Map<String, dynamic> p, ColorScheme cs) {
    final status = (p['status'] ?? 'Active').toString().toUpperCase();
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            'DEPLOYMENT',
            status,
            Icons.check_circle_outline_rounded,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatusCard(
            'NEURAL LINK',
            'SYNCED',
            Icons.hub_rounded,
            AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : cs.surfaceContainerHighest).withOpacity(
          isDark ? 0.03 : 0.5,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : cs.outlineVariant.withOpacity(0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.1 : 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              color: isDark ? Colors.white : cs.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: isDark ? Colors.white24 : cs.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(
    BuildContext context,
    ColorScheme cs, {
    required String buildTarget,
    required bool isReady,
  }) {
    final hasProjectId = (_projectId() ?? '').trim().isNotEmpty;
    final isAndroidApk =
        buildTarget == 'android_apk' || buildTarget == 'android';
    final isWindows = buildTarget == 'windows' || buildTarget == 'win';
    final isMacos = buildTarget == 'macos' || buildTarget == 'osx';
    final isWebgl =
        buildTarget.isEmpty || buildTarget == 'webgl' || buildTarget == 'web';

    final secondary = <Widget>[];
    if (isWebgl) {
      secondary.add(
        _buildActionButton(
          'PLAY BUILD',
          'WebGL Preview',
          Icons.play_arrow_rounded,
          null,
          isReady ? _onPlayWebgl : _onOpenBuildProgress,
          isOutlined: true,
          enabled: isReady
              ? (_previewUrl != null && _previewUrl!.trim().isNotEmpty)
              : true,
        ),
      );
      secondary.add(
        _buildActionButton(
          'DOWNLOAD',
          'WebGL .zip',
          Icons.download_rounded,
          null,
          _onDownload,
          isOutlined: true,
          enabled: isReady,
        ),
      );
    } else if (isAndroidApk) {
      secondary.add(
        _buildActionButton(
          'DOWNLOAD',
          'Android APK',
          Icons.android_rounded,
          null,
          _onDownload,
          isOutlined: true,
          enabled: isReady,
        ),
      );
      secondary.add(
        _buildActionButton(
          'RESULTS',
          'Build status',
          Icons.insights_rounded,
          null,
          _onOpenBuildResults,
          isOutlined: true,
          enabled: true,
        ),
      );
    } else if (isWindows || isMacos) {
      secondary.add(
        _buildActionButton(
          'DOWNLOAD',
          isWindows ? 'Windows build' : 'macOS build',
          isWindows ? Icons.desktop_windows_rounded : Icons.laptop_mac_rounded,
          null,
          _onDownload,
          isOutlined: true,
          enabled: isReady,
        ),
      );
      secondary.add(
        _buildActionButton(
          'RESULTS',
          'Build status',
          Icons.insights_rounded,
          null,
          _onOpenBuildResults,
          isOutlined: true,
          enabled: true,
        ),
      );
    } else {
      secondary.add(
        _buildActionButton(
          'RESULTS',
          'Build status',
          Icons.insights_rounded,
          null,
          _onOpenBuildResults,
          isOutlined: true,
          enabled: true,
        ),
      );
    }

    final items = <Widget>[
      _buildActionButton(
        'EDIT PROJECT',
        'Modify speed, colors, params',
        Icons.tune_rounded,
        null,
        _onEditProject,
        isOutlined: true,
        enabled: true,
      ),
      _buildActionButton(
        'FORGE ENGINE',
        'Launch full AI configuration',
        Icons.auto_awesome_rounded,
        AppColors.primaryGradient,
        _onOpenForge,
        enabled: true,
      ),
      _buildActionButton(
        _trailerGenerating ? 'TRAILER…' : 'AI TRAILER',
        _trailerGenerating
            ? '${_trailerStage ?? 'Analyzing highlights…'} • ${_fmtEta(_trailerEtaSec)}'
            : ((_trailerVideoUrl ?? '').trim().isNotEmpty
                  ? 'Ready • Share + Publish Reel'
                  : '$_trailerStyle • $_trailerTarget • Auto highlights'),
        Icons.movie_filter_rounded,
        _trailerGenerating
            ? null
            : const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
        () => _onLaunchAiTrailerGameplayMode(),
        enabled: isReady && hasProjectId && !_trailerGenerating,
      ),
      ...secondary,
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 540 ? 2 : 1;
        if (crossAxisCount == 1) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        return Column(
          children: [
            items.first,
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: items[1]),
                const SizedBox(width: 16),
                if (items.length > 2) Expanded(child: items[2]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton(
    String label,
    String sub,
    IconData icon,
    Gradient? gradient,
    VoidCallback onTap, {
    bool isOutlined = false,
    bool enabled = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null
                ? (isOutlined
                      ? Colors.transparent
                      : (isDark ? Colors.white : cs.surfaceContainerHighest)
                            .withOpacity(isDark ? 0.05 : 0.5))
                : null,
            borderRadius: BorderRadius.circular(24),
            border: isOutlined
                ? Border.all(
                    color:
                        (enabled
                                ? AppColors.primary
                                : (isDark ? Colors.white30 : cs.outlineVariant))
                            .withOpacity(0.3),
                    width: 2,
                  )
                : null,
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : cs.primary).withOpacity(
                        enabled ? (isDark ? 0.10 : 0.15) : 0.05,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: enabled
                          ? (isDark ? Colors.white : cs.primary)
                          : (isDark
                                ? Colors.white38
                                : cs.onSurfaceVariant.withOpacity(0.38)),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: enabled
                                ? (isDark ? Colors.white : cs.onSurface)
                                : (isDark
                                      ? Colors.white38
                                      : cs.onSurfaceVariant.withOpacity(0.38)),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? Colors.white60
                                : cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: enabled
                        ? (isDark
                              ? Colors.white38
                              : cs.onSurfaceVariant.withOpacity(0.5))
                        : (isDark
                              ? Colors.white24
                              : cs.onSurfaceVariant.withOpacity(0.24)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolvePreviewVideoUrl(Map<String, dynamic> p) {
    final raw =
        (p['previewVideoUrl'] ??
                p['previewVideo'] ??
                (p['media'] is Map
                    ? (p['media'] as Map)['previewVideoUrl']
                    : null) ??
                (p['media'] is Map
                    ? (p['media'] as Map)['previewVideo']
                    : null))
            ?.toString();
    return ApiService.normalizeImageUrl(raw);
  }

  Future<void> _openVideoPreview(String url) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _VideoPreviewDialog(url: url),
    );
  }

  void _onEditProject() {
    final id = _projectId();
    if (id == null || id.trim().isEmpty) {
      AppNotifier.showError('Missing project id');
      return;
    }
    context.push(
      '/edit-project',
      extra: {'projectId': id, 'project': _project ?? widget.data},
    );
  }

  void _onOpenForge() {
    final id = _projectId();
    if (id == null || id.trim().isEmpty) {
      AppNotifier.showError('Missing project id');
      return;
    }
    context.go('/build-configuration', extra: {'projectId': id});
  }

  Future<void> _onGenerateTrailer() async {
    if (_trailerGenerating) return;
    final pid = (_projectId() ?? '').trim();
    if (pid.isEmpty) {
      AppNotifier.showError('Missing project id');
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) {
      AppNotifier.showError('Session expired. Please sign in again.');
      return;
    }

    final project = _project ?? widget.data;
    final source =
        (_resolvePreviewVideoUrl(project).trim().isNotEmpty
                ? _resolvePreviewVideoUrl(project)
                : (_previewUrl ?? ''))
            .trim();

    final opts = await _pickTrailerOptions();
    if (opts == null) return;
    final style = (opts['style'] ?? 'energetic').toString();
    final target = (opts['target'] ?? 'tiktok').toString();

    if (mounted) {
      setState(() {
        _trailerGenerating = true;
        _trailerStage = 'Submitting job…';
        _trailerEtaSec = null;
      });
    }

    try {
      final createRes = await TrailersService.createTrailer(
        token: token,
        projectId: pid,
        sourceVideoUrl: source.isEmpty ? null : source,
        style: style,
        target: target,
      );

      if (createRes['success'] != true || createRes['data'] is! Map) {
        throw Exception(
          createRes['message']?.toString() ?? 'Failed to create trailer job',
        );
      }

      final createData = Map<String, dynamic>.from(createRes['data'] as Map);
      final trailerId = (createData['trailerId'] ?? '').toString().trim();
      if (trailerId.isEmpty) throw Exception('Missing trailer id');
      final initialEta = (createData['etaSec'] is num)
          ? (createData['etaSec'] as num).toInt()
          : null;

      if (mounted) {
        setState(() {
          _trailerId = trailerId;
          _trailerEtaSec = initialEta;
          _trailerStyle = style;
          _trailerTarget = target;
        });
      }
      _restartTrailerEtaTicker();

      for (var i = 0; i < 35; i++) {
        await Future.delayed(const Duration(milliseconds: 1100));

        final stRes = await TrailersService.getTrailerStatus(
          token: token,
          trailerId: trailerId,
        );

        if (stRes['success'] != true || stRes['data'] is! Map) {
          continue;
        }

        final st = Map<String, dynamic>.from(stRes['data'] as Map);
        final status = (st['status'] ?? '').toString().trim().toLowerCase();
        final stage = (st['stage'] ?? '').toString().trim();
        final etaSec = (st['etaSec'] is num)
            ? (st['etaSec'] as num).toInt()
            : null;

        if (mounted) {
          setState(() {
            _trailerStage = stage.isEmpty ? 'Processing…' : stage;
            _trailerEtaSec = etaSec ?? _trailerEtaSec;
          });
        }

        if (status == 'failed') {
          _trailerEtaTicker?.cancel();
          throw Exception(
            st['error']?.toString() ?? 'Trailer generation failed',
          );
        }

        if (status == 'ready') {
          _trailerEtaTicker?.cancel();
          final resultRes = await TrailersService.getTrailerResult(
            token: token,
            trailerId: trailerId,
          );
          if (resultRes['success'] != true || resultRes['data'] is! Map) {
            throw Exception(
              resultRes['message']?.toString() ??
                  'Trailer ready but result fetch failed',
            );
          }

          final result = Map<String, dynamic>.from(resultRes['data'] as Map);
          final videoUrl = (result['videoUrl'] ?? '').toString().trim();
          if (videoUrl.isEmpty) {
            throw Exception('Trailer generated without video url');
          }

          if (mounted) {
            setState(() {
              _trailerGenerating = false;
              _trailerStage = 'Ready';
              _trailerVideoUrl = videoUrl;
              _trailerId = trailerId;
              _trailerEtaSec = 0;
              _trailerStyle = style;
              _trailerTarget = target;
            });
          }
          AppNotifier.showSuccess('Trailer ready 🎬');
          await _openTrailerReadySheet(videoUrl, trailerId: trailerId);
          return;
        }
      }

      throw Exception('Trailer generation timed out. Please retry.');
    } catch (e) {
      _trailerEtaTicker?.cancel();
      AppNotifier.showError(e.toString());
      if (mounted) {
        setState(() {
          _trailerGenerating = false;
          _trailerStage = _trailerStage ?? 'Failed';
        });
      }
      return;
    }
  }

  Future<void> _onCheckReel() async {
    final trailerId = (_trailerId ?? '').trim();
    if (trailerId.isEmpty) {
      await _onGenerateTrailer();
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) {
      AppNotifier.showError('Session expired. Please sign in again.');
      return;
    }

    try {
      final stRes = await TrailersService.getTrailerStatus(
        token: token,
        trailerId: trailerId,
      );

      if (stRes['success'] != true || stRes['data'] is! Map) {
        throw Exception(
          stRes['message']?.toString() ?? 'Failed to check reel status',
        );
      }

      final st = Map<String, dynamic>.from(stRes['data'] as Map);
      final status = (st['status'] ?? '').toString().trim().toLowerCase();
      final stage = (st['stage'] ?? '').toString().trim();
      final etaSec = (st['etaSec'] is num)
          ? (st['etaSec'] as num).toInt()
          : null;

      if (mounted) {
        setState(() {
          _trailerStage = stage.isEmpty ? _trailerStage : stage;
          _trailerEtaSec = etaSec ?? _trailerEtaSec;
          _trailerGenerating = status == 'queued' || status == 'processing';
        });
      }

      if (_trailerGenerating) {
        _restartTrailerEtaTicker();
      } else {
        _trailerEtaTicker?.cancel();
      }

      if (status == 'failed') {
        AppNotifier.showError(
          st['error']?.toString() ?? 'Reel generation failed',
        );
        return;
      }

      if (status == 'ready') {
        final resultRes = await TrailersService.getTrailerResult(
          token: token,
          trailerId: trailerId,
        );
        if (resultRes['success'] != true || resultRes['data'] is! Map) {
          throw Exception(
            resultRes['message']?.toString() ??
                'Reel is ready, but result fetch failed',
          );
        }
        final result = Map<String, dynamic>.from(resultRes['data'] as Map);
        final videoUrl = (result['videoUrl'] ?? '').toString().trim();
        if (videoUrl.isEmpty) {
          throw Exception('Reel is ready but video url is missing');
        }

        if (mounted) {
          setState(() {
            _trailerVideoUrl = videoUrl;
            _trailerStage = 'Ready';
            _trailerGenerating = false;
            _trailerEtaSec = 0;
          });
        }
        AppNotifier.showSuccess('Reel ready 🎬');
        await _openTrailerReadySheet(videoUrl, trailerId: trailerId);
        return;
      }

      AppNotifier.showSuccess(
        'Reel status: ${stage.isEmpty ? status : stage} • ETA ${_fmtEta(_trailerEtaSec)}',
      );
    } catch (e) {
      AppNotifier.showError(e.toString());
    }
  }

  Future<Map<String, String>?> _pickTrailerOptions() async {
    var style = _trailerStyle;
    var target = _trailerTarget;
    if (!mounted) return null;
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trailer Options',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Style',
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final s in const [
                          'energetic',
                          'cinematic',
                          'funny',
                        ])
                          ChoiceChip(
                            selected: style == s,
                            label: Text(s),
                            onSelected: (_) => setModal(() => style = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Target',
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final t in const ['tiktok', 'reels', 'short'])
                          ChoiceChip(
                            selected: target == t,
                            label: Text(t),
                            onSelected: (_) => setModal(() => target = t),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(
                              ctx,
                            ).pop({'style': style, 'target': target}),
                            child: const Text('Generate'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTrailerReadySheet(
    String videoUrl, {
    required String trailerId,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _TrailerPreviewSheet(
          videoUrl: videoUrl,
          trailerId: trailerId,
          onPublish: () async {
            final router = GoRouter.of(context);
            final token = context.read<AuthProvider>().token;
            try {
              await HapticFeedback.mediumImpact();
            } catch (_) {}
            if (token == null || token.trim().isEmpty) {
              AppNotifier.showError(
                'Session expired. Please sign in again.',
              );
              return;
            }
            final pub = await TrailersService.publishTrailerToFeed(
              token: token,
              trailerId: trailerId,
            );
            if (pub['success'] != true) {
              AppNotifier.showError(
                pub['message']?.toString() ?? 'Failed to publish reel',
              );
              return;
            }
            AppNotifier.showSuccess(
              'Reel published to Arcade 🚀 Opening feed...',
            );
            if (!ctx.mounted) return;
            Navigator.of(ctx).pop();
            router.go('/dashboard?tab=arcade');
          },
        );
      },
    );
  }

  void _onOpenBuildProgress() {
    final id = _projectId();
    if (id == null || id.trim().isEmpty) {
      AppNotifier.showError('Missing project id');
      return;
    }
    context.go('/build-progress', extra: {'projectId': id});
  }

  void _onOpenBuildResults() {
    final id = _projectId();
    if (id == null || id.trim().isEmpty) {
      AppNotifier.showError('Missing project id');
      return;
    }
    context.go('/build-results', extra: {'projectId': id});
  }

  void _onPlayWebgl({bool autoTrailerMode = false}) {
    final url = _previewUrl;
    if (url == null || url.trim().isEmpty) {
      AppNotifier.showError('Missing preview url');
      return;
    }
    final pid = (_projectId() ?? '').trim();
    final raw = url.trim();
    String out = raw;
    if (pid.isNotEmpty) {
      try {
        final u = Uri.parse(raw);
        final qp = Map<String, String>.from(u.queryParameters);
        qp['projectId'] = pid;
        if (autoTrailerMode) {
          qp['gfAutoTrailer'] = '1';
        }
        out = u.replace(queryParameters: qp).toString();
      } catch (_) {}
    }
    context.push('/play-webgl', extra: {'url': out, 'projectId': pid});
  }

  void _onLaunchAiTrailerGameplayMode() {
    _onPlayWebgl(autoTrailerMode: true);
    AppNotifier.showSuccess(
      '🎬 AI Trailer mode: play now, we record best moments automatically',
    );
  }

  Future<void> _onDownload() async {
    final url = _downloadUrl;
    if (url == null || url.trim().isEmpty) {
      AppNotifier.showError('Missing download url');
      return;
    }
    try {
      final uri = Uri.parse(url.trim());
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) AppNotifier.showError('Could not open download link');
    } catch (e) {
      AppNotifier.showError(e.toString());
    }
  }

  Future<void> _onShare() async {
    if (!mounted) return;
    await _openShareSheet();
  }

  Rect _shareOriginRect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return const Rect.fromLTWH(0, 0, 1, 1);
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    return pos & Size(math.max(1, size.width), math.max(1, size.height));
  }

  String _shareMessage(Map<String, dynamic> p) {
    final title = (p['name'] ?? p['title'] ?? 'Project').toString();
    final b = (p['buildTarget']?.toString() ?? '').trim();
    final url = (_previewUrl ?? _downloadUrl ?? '').trim();
    return url.isNotEmpty ? '$title\n$b\n$url' : '$title\n$b';
  }

  Future<void> _openShareSheet() async {
    final p = _project ?? widget.data;
    final title = (p['name'] ?? p['title'] ?? 'Project').toString();
    final buildTarget = (p['buildTarget']?.toString() ?? '').trim();
    final url = (_previewUrl ?? _downloadUrl ?? '').trim();

    final thumb = ApiService.normalizeImageUrl(
      (p['previewImageUrl'] ??
              p['thumbnailUrl'] ??
              p['iconUrl'] ??
              p['imageUrl'] ??
              p['previewImage'] ??
              p['image'] ??
              (p['media'] is Map
                  ? (p['media'] as Map)['previewImage']
                  : null) ??
              (p['media'] is Map ? (p['media'] as Map)['thumbnailUrl'] : null))
          ?.toString(),
    );

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0A0C14),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Share build',
                                style: AppTypography.titleLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => Navigator.of(ctx).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        RepaintBoundary(
                          key: _shareCardKey,
                          child: _ShareBuildCard(
                            title: title,
                            buildTarget: buildTarget,
                            imageUrl: thumb,
                            shareUrl: url,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (url.isNotEmpty) ...[
                          Text(
                            (buildTarget.isEmpty ||
                                    buildTarget.toLowerCase().contains('web'))
                                ? 'WebGL'
                                : buildTarget.toUpperCase(),
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Playable link',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  url,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body2.copyWith(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _miniActionButton(
                                      label: 'Copy',
                                      icon: Icons.copy_rounded,
                                      onTap: () {
                                        Clipboard.setData(
                                          ClipboardData(text: url),
                                        );
                                        AppNotifier.showSuccess('Link copied');
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    _miniActionButton(
                                      label: 'Open',
                                      icon: Icons.open_in_new_rounded,
                                      onTap: () => launchUrl(
                                        Uri.parse(url),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'QR code',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: QrImageView(
                                    data: url,
                                    size: 180,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _miniActionButton(
                                  label: 'Copy link for QR',
                                  icon: Icons.copy_rounded,
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: url));
                                    AppNotifier.showSuccess('Link copied');
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _shareSheetButton(
                          label: 'Share Now',
                          icon: Icons.ios_share_rounded,
                          filled: true,
                          onTap: url.trim().isEmpty
                              ? null
                              : () async {
                                  try {
                                    await Share.share(
                                      _shareMessage(p),
                                      sharePositionOrigin: _shareOriginRect(),
                                    );
                                  } catch (e) {
                                    AppNotifier.showError(e.toString());
                                  }
                                },
                        ),
                        const SizedBox(height: 10),
                        _shareSheetButton(
                          label: 'Save Share Card',
                          icon: Icons.download_rounded,
                          onTap: () async {
                            try {
                              await _saveShareCardToPhotos();
                              if (mounted)
                                AppNotifier.showSuccess('Saved to Photos');
                            } catch (e) {
                              AppNotifier.showError(e.toString());
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        _shareSheetButton(
                          label: 'Save QR to Photos',
                          icon: Icons.qr_code_rounded,
                          onTap: url.trim().isEmpty
                              ? null
                              : () async {
                                  try {
                                    await _saveQrToPhotos(url.trim());
                                    if (mounted)
                                      AppNotifier.showSuccess(
                                        'Saved to Photos',
                                      );
                                  } catch (e) {
                                    AppNotifier.showError(e.toString());
                                  }
                                },
                        ),
                        const SizedBox(height: 8),
                        if (url.trim().isEmpty)
                          Text(
                            'No share link available yet.',
                            style: AppTypography.body2.copyWith(
                              color: Colors.white38,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _shareSheetButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.45 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: filled ? AppColors.primaryGradient : null,
            color: filled ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: filled
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.16),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _captureShareCardBytes() async {
    final boundary =
        _shareCardKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Share card is not ready');
    }
    final img = await boundary.toImage(pixelRatio: 3);
    final byteData = await img.toByteData(format: ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null) throw Exception('Failed to render image');
    return bytes;
  }

  Future<void> _requestPhotoSavePermission() async {
    final permission = Platform.isIOS ? Permission.photos : Permission.storage;
    final status = await permission.request();
    if (!status.isGranted && !status.isLimited) {
      throw Exception('Photos permission denied');
    }
  }

  Future<void> _saveShareCardToPhotos() async {
    await _requestPhotoSavePermission();
    final bytes = await _captureShareCardBytes();
    await ImageGallerySaver.saveImage(bytes);
  }

  Future<void> _saveQrToPhotos(String url) async {
    await _requestPhotoSavePermission();

    final painter = QrPainter(
      data: url,
      version: QrVersions.auto,
      gapless: true,
      color: Colors.black,
      emptyColor: Colors.white,
    );
    final data = await painter.toImageData(768, format: ImageByteFormat.png);
    final bytes = data?.buffer.asUint8List();
    if (bytes == null) throw Exception('Failed to render QR');
    await ImageGallerySaver.saveImage(bytes);
  }
}

class _TrailerPreviewSheet extends StatefulWidget {
  final String videoUrl;
  final String trailerId;
  final Future<void> Function() onPublish;

  const _TrailerPreviewSheet({
    required this.videoUrl,
    required this.trailerId,
    required this.onPublish,
  });

  @override
  State<_TrailerPreviewSheet> createState() => _TrailerPreviewSheetState();
}

class _TrailerPreviewSheetState extends State<_TrailerPreviewSheet> {
  VideoPlayerController? _ctrl;
  bool _init = false;
  bool _failed = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _ctrl = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) return;
      setState(() => _init = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _init = true;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.88;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxWidth: 620, maxHeight: maxH),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.8), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.12),
                  blurRadius: 34,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                color: (isDark ? const Color(0xFF05060A) : cs.surface).withOpacity(0.96),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                      child: Row(
                        children: [
                          Text(
                            'Preview Reel',
                            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, color: isDark ? Colors.white : cs.onSurface),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Container(
                        color: Colors.black,
                        child: !_init
                            ? Center(child: CircularProgressIndicator(color: cs.primary))
                            : _failed
                                ? Center(
                                    child: Icon(Icons.video_library_rounded, size: 56, color: isDark ? Colors.white24 : cs.onSurfaceVariant.withOpacity(0.4)),
                                  )
                                : GestureDetector(
                                    onTap: () {
                                      final c = _ctrl;
                                      if (c == null) return;
                                      if (c.value.isPlaying) {
                                        c.pause();
                                      } else {
                                        c.play();
                                      }
                                      setState(() {});
                                    },
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _ctrl!.value.size.width,
                                        height: _ctrl!.value.size.height,
                                        child: VideoPlayer(_ctrl!),
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _publishing
                                      ? null
                                      : () {
                                          Navigator.of(context).pop();
                                        },
                                  icon: const Icon(Icons.schedule_rounded),
                                  label: const Text('Not now'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (_publishing || _failed)
                                      ? null
                                      : () async {
                                          if (_publishing) return;
                                          setState(() => _publishing = true);
                                          try {
                                            await widget.onPublish();
                                          } finally {
                                            if (mounted) setState(() => _publishing = false);
                                          }
                                        },
                                  icon: _publishing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.rocket_launch_rounded),
                                  label: const Text('Publish'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: widget.videoUrl));
                                    if (!mounted) return;
                                    AppNotifier.showSuccess('Trailer link copied');
                                  },
                                  icon: const Icon(Icons.copy_rounded),
                                  label: const Text('Copy'),
                                ),
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await Share.share(widget.videoUrl);
                                  },
                                  icon: const Icon(Icons.ios_share_rounded),
                                  label: const Text('Share'),
                                ),
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final ok = await launchUrl(
                                      Uri.parse(widget.videoUrl),
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!ok) AppNotifier.showError('Could not open trailer link');
                                  },
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: const Text('Open'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareBuildCard extends StatelessWidget {
  final String title;
  final String buildTarget;
  final String imageUrl;
  final String shareUrl;

  const _ShareBuildCard({
    required this.title,
    required this.buildTarget,
    required this.imageUrl,
    required this.shareUrl,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = shareUrl.trim();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.55),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            SizedBox(
              height: 230,
              width: double.infinity,
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                          ),
                        );
                      },
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.10),
                      Colors.black.withOpacity(0.82),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: Text(
                  (buildTarget.isEmpty ? 'ARCADE' : buildTarget.toUpperCase()),
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.displaySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Built with GameForge',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body2.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 82,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (qrData.isNotEmpty)
                          QrImageView(
                            data: qrData,
                            size: 52,
                            backgroundColor: Colors.white,
                          )
                        else
                          const SizedBox(height: 52, width: 52),
                        const SizedBox(height: 6),
                        Text(
                          'Scan',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreviewDialog extends StatefulWidget {
  final String url;
  const _VideoPreviewDialog({required this.url});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
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
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: FutureBuilder<void>(
            future: _init,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return Stack(
                children: [
                  Positioned.fill(child: VideoPlayer(_controller)),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NeuralMeshPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double progress;

  _NeuralMeshPainter({
    required this.color1,
    required this.color2,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    paint.color = color1;
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * (0.2 + 0.1 * progress)),
      size.width * 0.8 * progress,
      paint,
    );
    paint.color = color2;
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * (0.8 - 0.1 * progress)),
      size.width * 0.6 * progress,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NeuralMeshPainter oldDelegate) => true;
}
