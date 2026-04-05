import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/projects_service.dart';
import '../../widgets/widgets.dart';

class BuildResultsScreen extends StatefulWidget {
  const BuildResultsScreen({super.key});

  @override
  State<BuildResultsScreen> createState() => _BuildResultsScreenState();
}

class _BuildResultsScreenState extends State<BuildResultsScreen> {
  bool _isLoading = true;
  String? _error;

  String? _projectId;
  Map<String, dynamic>? _project;
  String? _downloadUrlWebgl;
  String? _downloadUrlApk;
  String? _downloadUrlWindows;
  String? _downloadUrlMacos;
  String? _previewUrl;

  Future<void> _copyDownloadLink(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: u));
    AppNotifier.showSuccess('Link copied');
  }

  Widget _buildDesktopPlatformResult(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isReady,
    required bool isFailed,
    required String? downloadUrl,
    required String buildTime,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasDownload = downloadUrl != null && downloadUrl.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.success, size: 24),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.subtitle2.copyWith(color: cs.onSurface)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      buildTime.isNotEmpty ? buildTime : '—',
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                text: isReady ? 'Ready' : (isFailed ? 'Failed' : 'Pending'),
                color: isReady
                    ? AppColors.success
                    : (isFailed ? AppColors.error : cs.onSurfaceVariant),
                icon: isReady
                    ? Icons.check_circle
                    : (isFailed ? Icons.error : Icons.hourglass_bottom),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Download',
                  onPressed: (!isReady || !hasDownload)
                      ? null
                      : () {
                          _launchDownload(context, downloadUrl!);
                        },
                  type: ButtonType.primary,
                  icon: const Icon(Icons.download),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: CustomButton(
                  text: 'Copy link',
                  onPressed: (!isReady || !hasDownload)
                      ? null
                      : () {
                          _copyDownloadLink(downloadUrl!);
                        },
                  type: ButtonType.secondary,
                  icon: const Icon(Icons.link),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    final state = GoRouterState.of(context);
    final id = ((extra is Map) ? extra['projectId']?.toString() : null) ?? state.uri.queryParameters['projectId'];
    if (_projectId == null) {
      _projectId = id;
      _load();
    }
  }

  Widget _buildAndroidPlatformResult(
    BuildContext context, {
    required bool isReady,
    required String? downloadUrl,
    required String buildTime,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasDownload = downloadUrl != null && downloadUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.android,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Android (APK)',
                      style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      buildTime.isNotEmpty ? buildTime : '—',
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                text: isReady ? 'Ready' : 'Pending',
                color: isReady ? AppColors.success : cs.onSurfaceVariant,
                icon: isReady ? Icons.check_circle : Icons.hourglass_bottom,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasDownload) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Column(
                children: [
                  Text(
                    'Scan to Download',
                    style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    color: Colors.white,
                    child: QrImageView(
                      data: downloadUrl!,
                      version: QrVersions.auto,
                      size: 120.0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          CustomButton(
            text: 'Download APK',
            onPressed: (!isReady || !hasDownload)
                ? null
                : () {
                    _launchDownload(context, downloadUrl!);
                  },
            type: ButtonType.primary,
            icon: const Icon(Icons.download),
            isFullWidth: true,
          ),
          const SizedBox(height: AppSpacing.md),
          CustomButton(
            text: 'Copy link',
            onPressed: (!isReady || !hasDownload)
                ? null
                : () {
                    _copyDownloadLink(downloadUrl!);
                  },
            type: ButtonType.secondary,
            icon: const Icon(Icons.link),
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWebPlatformResult(
    BuildContext context, {
    required bool isReady,
    required String? downloadUrl,
    required String? previewUrl,
    required String buildTime,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasDownload = downloadUrl != null && downloadUrl.trim().isNotEmpty;
    final hasPreview = previewUrl != null && previewUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.language,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Web',
                      style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      buildTime.isNotEmpty ? buildTime : '—',
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                text: isReady ? 'Ready' : 'Pending',
                color: isReady ? AppColors.success : cs.onSurfaceVariant,
                icon: isReady ? Icons.check_circle : Icons.hourglass_bottom,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasDownload) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Column(
                children: [
                  Text(
                    'Scan to Download',
                    style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    color: Colors.white,
                    child: QrImageView(
                      data: downloadUrl!,
                      version: QrVersions.auto,
                      size: 120.0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Download',
                  onPressed: (!isReady || !hasDownload)
                      ? null
                      : () {
                          _launchDownload(context, downloadUrl!);
                        },
                  type: ButtonType.secondary,
                  icon: const Icon(Icons.download),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: CustomButton(
                  text: 'Play Now',
                  onPressed: (!isReady || !hasPreview)
                      ? null
                      : () {
                          final pid = (_projectId ?? '').trim();
                          final raw = (previewUrl ?? '').trim();
                          if (raw.isEmpty) return;
                          String url = raw;
                          if (pid.isNotEmpty) {
                            try {
                              final u = Uri.parse(raw);
                              final qp = Map<String, String>.from(u.queryParameters);
                              qp['projectId'] = pid;
                              url = u.replace(queryParameters: qp).toString();
                            } catch (_) {}
                          }
                          context.push('/play-webgl', extra: {'url': url, 'projectId': pid});
                        },
                  type: ButtonType.primary,
                  icon: const Icon(Icons.play_arrow),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CustomButton(
            text: 'Copy link',
            onPressed: (!isReady || !hasDownload)
                ? null
                : () {
                    _copyDownloadLink(downloadUrl!);
                  },
            type: ButtonType.secondary,
            icon: const Icon(Icons.link),
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  String _formatDurationMs(num? durationMs) {
    if (durationMs == null) return '—';
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes <= 0) return '${seconds}s';
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  Future<void> _load() async {
    final id = _projectId;
    if (id == null || id.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Missing projectId';
      });
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final projectRes = await ProjectsService.getProject(token: token, projectId: id);
      if (!mounted) return;

      if (projectRes['success'] != true || projectRes['data'] is! Map) {
        setState(() {
          _isLoading = false;
          _error = projectRes['message']?.toString() ?? 'Failed to load project';
        });
        return;
      }

      final p = Map<String, dynamic>.from(projectRes['data'] as Map);
      final status = (p['status']?.toString() ?? '').toLowerCase();
      final buildTarget = (p['buildTarget']?.toString() ?? '').trim().toLowerCase();
      final isAndroidApk = buildTarget == 'android_apk' || buildTarget == 'android';
      final isWindows = buildTarget == 'windows' || buildTarget == 'win';
      final isMacos = buildTarget == 'macos' || buildTarget == 'osx';

      String? downloadUrlWebgl;
      String? downloadUrlApk;
      String? downloadUrlWindows;
      String? downloadUrlMacos;
      String? previewUrl;
      if (status == 'ready') {
        try {
          if (isAndroidApk) {
            final dApk = await ProjectsService.getProjectDownloadUrl(token: token, projectId: id, target: 'android_apk');
            if (dApk['success'] == true && dApk['data'] is Map) {
              downloadUrlApk = ((dApk['data'] as Map)['url'])?.toString();
            }
          } else if (isWindows) {
            final dWin = await ProjectsService.getProjectDownloadUrl(token: token, projectId: id, target: 'windows');
            if (dWin['success'] == true && dWin['data'] is Map) {
              downloadUrlWindows = ((dWin['data'] as Map)['url'])?.toString();
            }
          } else if (isMacos) {
            final dMac = await ProjectsService.getProjectDownloadUrl(token: token, projectId: id, target: 'macos');
            if (dMac['success'] == true && dMac['data'] is Map) {
              downloadUrlMacos = ((dMac['data'] as Map)['url'])?.toString();
            }
          } else {
            final dWeb = await ProjectsService.getProjectDownloadUrl(token: token, projectId: id, target: 'webgl');
            if (dWeb['success'] == true && dWeb['data'] is Map) {
              downloadUrlWebgl = ((dWeb['data'] as Map)['url'])?.toString();
            }
          }
        } catch (_) {
          // ignore
        }

        try {
          final prRes = await ProjectsService.getProjectPreviewUrl(token: token, projectId: id);
          if (prRes['success'] == true && prRes['data'] is Map) {
            previewUrl = (prRes['data'] as Map)['url']?.toString();
          }
        } catch (_) {
          // ignore
        }
      }

      setState(() {
        _isLoading = false;
        _project = p;
        _downloadUrlWebgl = downloadUrlWebgl;
        _downloadUrlApk = downloadUrlApk;
        _downloadUrlWindows = downloadUrlWindows;
        _downloadUrlMacos = downloadUrlMacos;
        _previewUrl = previewUrl;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extra = GoRouterState.of(context).extra;
    final projectId = (extra is Map) ? extra['projectId']?.toString() : null;

    final p = _project;
    final status = (p?['status']?.toString() ?? '').toLowerCase();
    final isReady = status == 'ready';
    final isFailed = status == 'failed';
    final buildTarget = (p?['buildTarget']?.toString() ?? '').toLowerCase();
    final isAndroidApk = buildTarget == 'android_apk' || buildTarget == 'android';
    final errorText = p?['error']?.toString();
    final timings = (p?['buildTimings'] is Map) ? Map<String, dynamic>.from(p?['buildTimings'] as Map) : null;
    final dynamic durationRaw = timings == null ? null : timings['durationMs'];
    final num? durationMs = durationRaw is num ? durationRaw : null;

    final hasWebgl = (_previewUrl != null && _previewUrl!.trim().isNotEmpty) ||
        (_downloadUrlWebgl != null && _downloadUrlWebgl!.trim().isNotEmpty);
    final hasApk = _downloadUrlApk != null && _downloadUrlApk!.trim().isNotEmpty;
    final hasWindows = _downloadUrlWindows != null && _downloadUrlWindows!.trim().isNotEmpty;
    final hasMacos = _downloadUrlMacos != null && _downloadUrlMacos!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Build Results',
          style: AppTypography.subtitle1.copyWith(color: cs.onSurface),
        ),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: Icon(
            Icons.arrow_back,
            color: cs.onSurface,
          ),
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (_isLoading) ...[
              const SizedBox(height: AppSpacing.xl),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (!_isLoading && (_error != null)) ...[
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: AppColors.error.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _error!,
                      style: AppTypography.body1.copyWith(color: cs.onSurface),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomButton(
                      text: 'Retry',
                      onPressed: _load,
                      type: ButtonType.secondary,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (projectId != null && projectId.trim().isNotEmpty) ...[
              CustomButton(
                text: 'Play',
                onPressed: () async {
                  final url = _previewUrl;
                  if (url != null && url.trim().isNotEmpty) {
                    final pid = (projectId ?? '').trim();
                    final raw = url.trim();
                    String out = raw;
                    if (pid.isNotEmpty) {
                      try {
                        final u = Uri.parse(raw);
                        final qp = Map<String, String>.from(u.queryParameters);
                        qp['projectId'] = pid;
                        out = u.replace(queryParameters: qp).toString();
                      } catch (_) {}
                    }
                    if (context.mounted) context.push('/play-webgl', extra: {'url': out, 'projectId': pid});
                    return;
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This build is not playable in-app. Build WebGL to play instantly.'),
                      ),
                    );
                  }
                },
                type: ButtonType.primary,
                icon: const Icon(Icons.play_arrow),
                isFullWidth: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            const SizedBox(height: AppSpacing.xl),
            
            // Success animation
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withOpacity(0.1),
                  boxShadow: AppShadows.custom(color: AppColors.success),
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 60,
                  color: AppColors.success,
                ),
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Status message
            Text(
              isFailed
                  ? 'Build Failed'
                  : isReady
                      ? 'Build Completed Successfully!'
                      : 'Build In Progress',
              style: AppTypography.h2.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            Text(
              isFailed
                  ? (errorText != null && errorText.trim().isNotEmpty
                      ? errorText
                      : 'The build failed. Please try again.')
                  : isReady
                      ? 'Your game is ready.'
                      : 'We are generating your game build. Please wait.',
              style: AppTypography.body1.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Build statistics
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Build Statistics',
                    style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Total Build Time',
                          _formatDurationMs(durationMs),
                          Icons.timer,
                          AppColors.primary,
                        ),
                      ),
                      
                      const SizedBox(width: AppSpacing.lg),
                      
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Total Size',
                          '—',
                          Icons.storage,
                          AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Platforms',
                          isReady ? (isAndroidApk ? '1' : '1') : '—',
                          Icons.devices,
                          AppColors.success,
                        ),
                      ),
                      
                      const SizedBox(width: AppSpacing.lg),
                      
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'Success Rate',
                          isFailed ? '0%' : (isReady ? '100%' : '—'),
                          Icons.trending_up,
                          AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Platform results
            Text(
              'Platform Downloads',
              style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
            ),
            
            const SizedBox(height: AppSpacing.lg),

            if (isAndroidApk)
              _buildAndroidPlatformResult(
                context,
                isReady: isReady,
                downloadUrl: _downloadUrlApk,
                buildTime: _formatDurationMs(durationMs),
              )
            else if (buildTarget == 'macos' || buildTarget == 'osx')
              _buildDesktopPlatformResult(
                context,
                title: 'macOS',
                icon: Icons.laptop_mac,
                isReady: isReady,
                isFailed: isFailed,
                downloadUrl: _downloadUrlMacos,
                buildTime: _formatDurationMs(durationMs),
              )
            else if (buildTarget == 'windows' || buildTarget == 'win')
              _buildDesktopPlatformResult(
                context,
                title: 'Windows',
                icon: Icons.desktop_windows,
                isReady: isReady,
                isFailed: isFailed,
                downloadUrl: _downloadUrlWindows,
                buildTime: _formatDurationMs(durationMs),
              )
            else
              _buildWebPlatformResult(
                context,
                isReady: isReady,
                downloadUrl: _downloadUrlWebgl,
                previewUrl: _previewUrl,
                buildTime: _formatDurationMs(durationMs),
              ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Share section
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.share,
                        color: cs.primary,
                      ),
                      
                      const SizedBox(width: AppSpacing.md),
                      
                      Text(
                        'Share Your Game',
                        style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  Text(
                    'Share your game with friends and players to get feedback and build your community.',
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Share Link',
                          onPressed: () {
                            _shareGameLink(context);
                          },
                          type: ButtonType.secondary,
                          icon: const Icon(Icons.link),
                        ),
                      ),
                      
                      const SizedBox(width: AppSpacing.lg),
                      
                      Expanded(
                        child: CustomButton(
                          text: 'Copy QR Code',
                          onPressed: () {
                            _copyQRCode(context);
                          },
                          type: ButtonType.secondary,
                          icon: const Icon(Icons.qr_code),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Action buttons
            CustomButton(
              text: 'Create New Build',
              onPressed: () {
                context.go('/build-configuration');
              },
              type: ButtonType.primary,
              size: ButtonSize.large,
              isFullWidth: true,
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            CustomButton(
              text: 'Back to Dashboard',
              onPressed: () {
                context.go('/dashboard');
              },
              type: ButtonType.ghost,
              isFullWidth: true,
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            ],
          ),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
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


  void _shareGameLink(BuildContext context) {
    final url = (_previewUrl != null && _previewUrl!.trim().isNotEmpty)
        ? _previewUrl!.trim()
        : (_downloadUrlWebgl != null && _downloadUrlWebgl!.trim().isNotEmpty)
            ? _downloadUrlWebgl!.trim()
            : (_downloadUrlApk != null && _downloadUrlApk!.trim().isNotEmpty)
                ? _downloadUrlApk!.trim()
                : null;
    if (url == null) {
      AppNotifier.showError('No link available');
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null)
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height);
    Share.share(url, sharePositionOrigin: origin);
  }

  void _copyQRCode(BuildContext context) {
    final url = (_downloadUrlWebgl != null && _downloadUrlWebgl!.trim().isNotEmpty)
        ? _downloadUrlWebgl!.trim()
        : (_downloadUrlApk != null && _downloadUrlApk!.trim().isNotEmpty)
            ? _downloadUrlApk!.trim()
            : null;
    if (url == null) {
      AppNotifier.showError('No download link available');
      return;
    }
    _copyToClipboard(context, url);
  }

  void _launchDownload(BuildContext context, String url) {
    final u = Uri.tryParse(url);
    if (u == null) {
      AppNotifier.showError('Invalid URL');
      return;
    }
    launchUrl(u, mode: LaunchMode.externalApplication).then((ok) {
      if (!ok) AppNotifier.showError('Could not open link');
    }).catchError((e) {
      AppNotifier.showError(e.toString());
    });
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      AppNotifier.showSuccess('Link copied');
    }).catchError((e) {
      AppNotifier.showError(e.toString());
    });
  }
}
