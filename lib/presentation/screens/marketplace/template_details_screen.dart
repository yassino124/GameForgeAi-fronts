import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui';
import 'dart:io';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/services/templates_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../widgets/widgets.dart';

class TemplateDetailsScreen extends StatefulWidget {
  final String templateId;

  const TemplateDetailsScreen({
    super.key,
    required this.templateId,
  });

  @override
  State<TemplateDetailsScreen> createState() => _TemplateDetailsScreenState();
}

class _TemplateDetailsScreenState extends State<TemplateDetailsScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _template;

  bool _forking = false;

  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = false;

  List<Map<String, dynamic>> _pendingReviews = [];
  bool _pendingLoading = false;
  String? _pendingError;
  final Set<String> _approvingUserIds = {};

  bool _hasAccess = false;
  bool _checkingAccess = false;
  bool _purchasing = false;

  File? _newPreviewImage;
  List<File> _newScreenshots = [];
  File? _newPreviewVideo;
  bool _uploadingMedia = false;

  int _userRating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _submittingReview = false;

  final TextEditingController _aiNotesController = TextEditingController();
  bool _aiOverwrite = false;
  bool _generatingAi = false;
  bool _listingModels = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _showAiModels() async {
    if (_listingModels) return;
    final token = _getToken();
    if (token == null || token.trim().isEmpty) return;

    setState(() {
      _listingModels = true;
    });

    try {
      final res = await AiService.listModels(token: token);
      if (!mounted) return;

      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data'] as Map) : <String, dynamic>{};
      final v1beta = (data['v1beta'] is Map) ? Map<String, dynamic>.from(data['v1beta'] as Map) : null;
      final v1 = (data['v1'] is Map) ? Map<String, dynamic>.from(data['v1'] as Map) : null;

      String formatModels(Map<String, dynamic>? payload) {
        if (payload == null) return 'No data';
        if (payload['ok'] != true) {
          return 'Error (${payload['status']}): ${payload['error'] ?? ''}';
        }
        final models = (payload['models'] is List) ? (payload['models'] as List) : const [];
        if (models.isEmpty) return 'No models returned';

        final lines = <String>[];
        for (final m in models) {
          if (m is! Map) continue;
          final name = m['name']?.toString() ?? '';
          final methods = (m['supportedGenerationMethods'] is List)
              ? (m['supportedGenerationMethods'] as List).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
              : <String>[];
          if (name.isEmpty) continue;
          lines.add('${name}${methods.isEmpty ? '' : '  (${methods.join(', ')})'}');
        }
        return lines.isEmpty ? 'No usable models' : lines.join('\n');
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: cs.surface,
            title: Text('Gemini Models', style: AppTypography.subtitle1),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('v1beta', style: AppTypography.subtitle2),
                    const SizedBox(height: AppSpacing.xs),
                    Text(formatModels(v1beta), style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.lg),
                    Text('v1', style: AppTypography.subtitle2),
                    const SizedBox(height: AppSpacing.xs),
                    Text(formatModels(v1), style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _listingModels = false;
      });
    }
  }

  Future<void> _loadPendingReviews() async {
    if (!_isModerator) return;
    if (_pendingLoading) return;

    final token = _getToken();
    if (token == null || token.trim().isEmpty) return;

    if (!mounted) return;
    setState(() {
      _pendingLoading = true;
      _pendingError = null;
    });

    try {
      final res = await TemplatesService.listPendingTemplateReviews(
        token: token,
        templateId: widget.templateId,
      );
      if (!mounted) return;

      if (res['success'] != true) {
        setState(() {
          _pendingError = res['message']?.toString() ?? 'Failed to load pending reviews';
          _pendingReviews = [];
        });
        return;
      }

      final data = (res['data'] is List)
          ? (res['data'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _pendingReviews = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingError = e.toString();
        _pendingReviews = [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _pendingLoading = false;
      });
    }
  }

  Future<void> _approvePendingReview(Map<String, dynamic> review) async {
    final token = _getToken();
    if (token == null || token.trim().isEmpty) return;

    final cs = Theme.of(context).colorScheme;
    final userId = review['userId']?.toString() ?? '';
    if (userId.isEmpty) return;

    if (_approvingUserIds.contains(userId)) return;
    setState(() {
      _approvingUserIds.add(userId);
    });

    try {
      final res = await TemplatesService.approveTemplateReview(
        token: token,
        templateId: widget.templateId,
        userId: userId,
      );

      if (!mounted) return;
      if (res['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to approve review'),
            backgroundColor: cs.error,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Review approved.'), backgroundColor: cs.primary),
      );

      await _load();
    } finally {
      if (!mounted) return;
      setState(() {
        _approvingUserIds.remove(userId);
      });
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _aiNotesController.dispose();
    super.dispose();
  }

  String? _getToken() {
    try {
      return context.read<AuthProvider>().token;
    } catch (_) {
      return null;
    }
  }

  bool get _isModerator {
    try {
      final auth = context.read<AuthProvider>();
      return auth.isAdmin || auth.isDevl;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadAccess() async {
    final token = _getToken();
    if (token == null || token.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _hasAccess = false;
        _checkingAccess = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _checkingAccess = true;
    });

    try {
      final res = await TemplatesService.getTemplateAccess(token: token, templateId: widget.templateId);
      if (!mounted) return;
      final data = res['data'];
      final has = (res['success'] == true && data is Map) ? (data['hasAccess'] == true) : false;
      setState(() {
        _hasAccess = has;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _checkingAccess = false;
      });
    }
  }

  String _formatStripeError(Object e) {
    if (e.runtimeType.toString() == 'StripeConfigException') {
      final msg = e.toString();
      if (msg.trim().isNotEmpty && !msg.startsWith('Instance of')) {
        return msg;
      }
      return 'Stripe is not configured (missing publishable key or url scheme).';
    }
    if (e is StripeException) {
      final code = e.error.code;
      final codeStr = code?.toString();
      final message = e.error.message;
      if (message != null && message.trim().isNotEmpty) {
        return codeStr != null && codeStr.trim().isNotEmpty ? '$codeStr: $message' : message;
      }
      if (codeStr != null && codeStr.trim().isNotEmpty) return codeStr;
      return 'Stripe error';
    }
    final msg = e.toString();
    if (msg.startsWith('Exception: ')) return msg.replaceFirst('Exception: ', '');
    return msg;
  }

  Future<void> _buyTemplate() async {
    if (_purchasing) return;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final token = _getToken();
    if (token == null || token.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please sign in to purchase.'), backgroundColor: cs.error),
      );
      return;
    }

    if (Stripe.publishableKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Stripe is not configured.'), backgroundColor: cs.error),
      );
      return;
    }

    setState(() {
      _purchasing = true;
    });

    try {
      final res = await TemplatesService.createTemplatePurchasePaymentSheet(
        token: token,
        templateId: widget.templateId,
      );
      if (res['success'] != true) {
        throw Exception(res['message']?.toString() ?? 'Failed to start purchase');
      }

      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data'] as Map) : <String, dynamic>{};
      final clientSecret = data['paymentIntentClientSecret']?.toString() ?? '';
      final paymentIntentId = data['paymentIntentId']?.toString() ?? '';

      if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
        throw Exception('Invalid payment sheet data from server');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'GameForge AI',
          paymentIntentClientSecret: clientSecret,
          style: isDark ? ThemeMode.dark : ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              background: cs.surface,
              primary: cs.primary,
              componentBackground: cs.surface,
              componentBorder: cs.outlineVariant,
              componentDivider: cs.outlineVariant,
              componentText: cs.onSurface,
              primaryText: cs.onPrimary,
              secondaryText: cs.onSurfaceVariant,
              placeholderText: cs.onSurfaceVariant,
              icon: cs.onSurfaceVariant,
              error: cs.error,
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final confirmRes = await TemplatesService.confirmTemplatePurchase(
        token: token,
        templateId: widget.templateId,
        paymentIntentId: paymentIntentId,
      );
      if (confirmRes['success'] != true) {
        throw Exception(confirmRes['message']?.toString() ?? 'Purchase confirmation failed');
      }

      if (!mounted) return;
      setState(() {
        _hasAccess = true;
      });

      final template = (confirmRes['data'] is Map) ? (confirmRes['data'] as Map)['template'] : null;
      if (template is Map) {
        setState(() {
          _template = Map<String, dynamic>.from(template);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Purchase successful. Template unlocked.'), backgroundColor: cs.primary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatStripeError(e)), backgroundColor: cs.error),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _purchasing = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    if (!mounted) return;
    setState(() {
      _reviewsLoading = true;
    });

    try {
      final res = await TemplatesService.listTemplateReviews(widget.templateId);
      if (!mounted) return;
      final data = (res['success'] == true && res['data'] is List)
          ? (res['data'] as List).map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList()
          : <Map<String, dynamic>>[];

      setState(() {
        _reviews = data;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _reviewsLoading = false;
      });
    }
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
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: false);
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
    if (_uploadingMedia) return;
    final token = _getToken();
    if (token == null || token.trim().isEmpty) return;

    if (_newPreviewImage == null && _newPreviewVideo == null && _newScreenshots.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please select at least one media file')),
      );
      return;
    }

    setState(() {
      _uploadingMedia = true;
    });

    try {
      final res = await TemplatesService.updateTemplateMedia(
        token: token,
        templateId: widget.templateId,
        previewImage: _newPreviewImage,
        screenshots: _newScreenshots,
        previewVideo: _newPreviewVideo,
      );

      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        setState(() {
          _template = Map<String, dynamic>.from(res['data'] as Map);
          _newPreviewImage = null;
          _newScreenshots = [];
          _newPreviewVideo = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Media updated')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Upload failed')),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _uploadingMedia = false;
      });
    }
  }

  String? _resolveMediaUrl(String? url) {
    if (url == null) return null;
    final raw = url.trim();
    if (raw.isEmpty) return null;

    try {
      final base = Uri.parse(ApiService.baseUrl);
      final baseOrigin = Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null);

      if (raw.startsWith('/')) {
        return baseOrigin.resolve(raw).toString();
      }

      final u = Uri.parse(raw);
      if (!u.hasScheme) {
        return baseOrigin.resolve('/$raw').toString();
      }

      return baseOrigin.replace(path: u.path, query: u.query).toString();
    } catch (_) {
      return raw;
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await TemplatesService.getTemplate(widget.templateId);
      if (!mounted) return;
      final data = (res['success'] == true && res['data'] is Map) ? Map<String, dynamic>.from(res['data'] as Map) : null;
      if (data == null) {
        setState(() {
          _error = 'Failed to load template';
        });
        return;
      }
      setState(() {
        _template = data;
      });

      _loadReviews();

      if (_isModerator) {
        _loadPendingReviews();
      }

      _loadAccess();
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

  Future<void> _openVideoPlayer(String url) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _VideoPlayerDialog(url: url),
    );
  }

  String _censorProfanity(String input) {
    final s = input;
    final badWords = <String>{
      'fuck',
      'shit',
      'bitch',
      'asshole',
      'bastard',
      'dick',
      'pussy',
      'cunt',
      'fucker',
      'motherfucker',
      'nigga',
      'nigger',
      'putain',
      'merde',
      'salope',
      'connard',
      'encule',
      'enculé',
    };

    String out = s;
    for (final w in badWords) {
      final re = RegExp('\\b${RegExp.escape(w)}\\b', caseSensitive: false);
      out = out.replaceAllMapped(re, (m) => '*' * (m.group(0)?.length ?? w.length));
    }
    return out;
  }

  Future<void> _submitReview() async {
    if (_submittingReview) return;
    final cs = Theme.of(context).colorScheme;

    if (_userRating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a rating.'),
          backgroundColor: cs.error,
        ),
      );
      return;
    }

    final raw = _reviewController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please write a short review.'),
          backgroundColor: cs.error,
        ),
      );
      return;
    }

    setState(() {
      _submittingReview = true;
    });

    try {
      final sanitized = _censorProfanity(raw);

      String? token;
      try {
        token = context.read<AuthProvider>().token;
      } catch (_) {
        token = null;
      }
      token ??= (await SharedPreferences.getInstance()).getString('auth_token');

      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please sign in to submit a review.'),
            backgroundColor: cs.error,
          ),
        );
        return;
      }

      final res = await TemplatesService.submitTemplateReview(
        token: token,
        templateId: widget.templateId,
        rating: _userRating,
        comment: sanitized,
      );
      if (res['success'] != true) {
        throw Exception(res['message']?.toString() ?? 'Failed to submit review');
      }

      final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data'] as Map) : <String, dynamic>{};
      final status = data['reviewStatus']?.toString() ?? '';

      final msg = status == 'pending'
          ? 'Thanks! Your review is pending admin approval.'
          : 'Review submitted!';

      await _loadReviews();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: cs.primary,
        ),
      );

      setState(() {
        _userRating = 0;
        _reviewController.clear();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _submittingReview = false;
      });
    }
  }

  Future<void> _generateAiMetadata() async {
    if (_generatingAi) return;
    final token = _getToken();
    if (token == null || token.trim().isEmpty) return;

    setState(() {
      _generatingAi = true;
    });

    try {
      final res = await TemplatesService.generateTemplateAiMetadata(
        token: token,
        templateId: widget.templateId,
        notes: _aiNotesController.text,
        overwrite: _aiOverwrite,
      );

      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        setState(() {
          _template = Map<String, dynamic>.from(res['data'] as Map);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('AI metadata generated')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed to generate AI metadata')),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _generatingAi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final t = _template;
    final name = t?['name']?.toString() ?? 'Template';
    final desc = t?['description']?.toString() ?? '';
    final category = t?['category']?.toString() ?? 'General';
    final rating = (t?['rating'] is num) ? (t?['rating'] as num).toDouble() : 4.7;
    final downloads = (t?['downloads'] is num) ? (t?['downloads'] as num).toInt() : 0;
    final price = (t?['price'] is num) ? (t?['price'] as num).toDouble() : 0.0;
    final isPaid = price > 0.0;
    final canUse = !isPaid || _hasAccess;

    final coverUrl = _resolveMediaUrl(t?['previewImageUrl']?.toString());
    final screenshotUrlsRaw = t?['screenshotUrls'];
    final screenshotUrls = (screenshotUrlsRaw is List)
        ? screenshotUrlsRaw.map((x) => _resolveMediaUrl(x?.toString()) ?? '').where((x) => x.isNotEmpty).toList()
        : const <String>[];
    final previewVideoUrl = _resolveMediaUrl(t?['previewVideoUrl']?.toString());
    final tagsRaw = t?['tags'];
    final tags = (tagsRaw is List)
        ? tagsRaw.map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).toList()
        : <String>[];
    final compatBadges = _compatBadges(tags);
    final auth = context.watch<AuthProvider>();
    final canEditMedia = auth.isAdmin || auth.isDevl;

    final ai = (t?['aiMetadata'] is Map) ? Map<String, dynamic>.from(t?['aiMetadata'] as Map) : null;
    final aiTags = (ai?['tags'] is List)
        ? (ai?['tags'] as List).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : <String>[];
    final mediaPrompts = (ai?['mediaPrompts'] is Map) ? Map<String, dynamic>.from(ai?['mediaPrompts'] as Map) : null;
    final shotPrompts = (mediaPrompts?['screenshots'] is List)
        ? (mediaPrompts?['screenshots'] as List).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : <String>[];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(name, style: AppTypography.subtitle1),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard?tab=templates');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: SafeArea(
          top: false,
          child: _loading
              ? const _TemplateDetailsSkeleton()
              : (_error != null)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: AppTypography.body2.copyWith(color: cs.error)),
                            const SizedBox(height: AppSpacing.md),
                            CustomButton(text: 'Retry', onPressed: _load),
                          ],
                        ),
                      ),
                    )
                  : (t == null)
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHero(
                                cs: cs,
                                coverUrl: coverUrl,
                                previewVideoUrl: previewVideoUrl,
                                onPlay: previewVideoUrl == null || previewVideoUrl.trim().isEmpty
                                    ? null
                                    : () async {
                                        await _openVideoPlayer(previewVideoUrl);
                                      },
                              ),
                              if (screenshotUrls.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                _buildScreenshots(screenshotUrls),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              Text(name, style: AppTypography.h3.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: AppSpacing.xs),
                              Text(category, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                              if (compatBadges.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: compatBadges.take(3).map((b) => _DetailsBadgeChip(label: b.label, icon: b.icon)).toList(),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 16, color: AppColors.warning),
                                  const SizedBox(width: 6),
                                  Text(rating.toStringAsFixed(1), style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(width: AppSpacing.lg),
                                  Text('$downloads downloads', style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.14),
                                      borderRadius: AppBorderRadius.allSmall,
                                      border: Border.all(color: cs.primary.withOpacity(0.22)),
                                    ),
                                    child: Text(
                                      price == 0.0 ? 'FREE' : '\$${price.toStringAsFixed(2)}',
                                      style: AppTypography.caption.copyWith(color: cs.primary, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                              if (desc.trim().isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xl),
                                Text('About', style: AppTypography.subtitle2),
                                const SizedBox(height: AppSpacing.sm),
                                Text(desc, style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
                              ],
                              if (canEditMedia) ...[
                                Text('Media', style: AppTypography.subtitle1),
                                const SizedBox(height: AppSpacing.md),
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
                                const SizedBox(height: AppSpacing.xl),
                              ],
                              if (canEditMedia) ...[
                                Text('AI', style: AppTypography.subtitle1),
                                const SizedBox(height: AppSpacing.md),
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
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _listingModels ? null : _showAiModels,
                                          child: Text(_listingModels ? 'Loading…' : 'List models'),
                                        ),
                                      ),
                                      TextField(
                                        controller: _aiNotesController,
                                        minLines: 2,
                                        maxLines: 4,
                                        decoration: const InputDecoration(labelText: 'Notes (optional)'),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Overwrite template fields',
                                              style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Switch(
                                            value: _aiOverwrite,
                                            onChanged: _generatingAi
                                                ? null
                                                : (v) {
                                                    setState(() {
                                                      _aiOverwrite = v;
                                                    });
                                                  },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      CustomButton(
                                        text: _generatingAi ? 'Generating…' : 'Generate with Gemini',
                                        onPressed: _generatingAi ? null : _generateAiMetadata,
                                        isFullWidth: true,
                                      ),
                                      if (ai != null) ...[
                                        const SizedBox(height: AppSpacing.lg),
                                        Text('Generated', style: AppTypography.subtitle2),
                                        const SizedBox(height: AppSpacing.sm),
                                        if ((ai['description']?.toString() ?? '').trim().isNotEmpty)
                                          Text(
                                            ai['description'].toString(),
                                            style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                                          ),
                                        if (aiTags.isNotEmpty) ...[
                                          const SizedBox(height: AppSpacing.sm),
                                          Text('Tags: ${aiTags.join(', ')}', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                                        ],
                                        if (mediaPrompts != null) ...[
                                          const SizedBox(height: AppSpacing.md),
                                          if ((mediaPrompts['cover']?.toString() ?? '').trim().isNotEmpty)
                                            Text('Cover prompt: ${mediaPrompts['cover']}', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                                          if (shotPrompts.isNotEmpty) ...[
                                            const SizedBox(height: AppSpacing.xs),
                                            Text('Screenshot prompts:', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                                            const SizedBox(height: 6),
                                            ...shotPrompts.map((p) => Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Text('- $p', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                                                )),
                                          ],
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              _UserReviewCard(
                                rating: _userRating,
                                onRatingChanged: (v) {
                                  setState(() {
                                    _userRating = v;
                                  });
                                },
                                controller: _reviewController,
                                submitting: _submittingReview,
                                onSubmit: _submitReview,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text('Reviews', style: AppTypography.subtitle2),
                              const SizedBox(height: AppSpacing.sm),
                              if (_reviewsLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (_reviews.isEmpty)
                                Text('No reviews yet.', style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant))
                              else
                                Column(
                                  children: _reviews
                                      .take(6)
                                      .map((r) => Padding(
                                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                            child: _ReviewListItem(review: r),
                                          ))
                                      .toList(),
                                ),
                              const SizedBox(height: AppSpacing.xl),
                              Row(
                                children: [
                                  Expanded(
                                    child: CustomButton(
                                      text: isPaid && !canUse
                                          ? (_purchasing ? 'Processing...' : 'Buy for \$${price.toStringAsFixed(2)}')
                                          : 'Use Template',
                                      onPressed: (isPaid && !canUse)
                                          ? (_purchasing ? null : _buyTemplate)
                                          : () {
                                              context.go('/create-project');
                                            },
                                      type: ButtonType.primary,
                                      icon: Icon(isPaid && !canUse ? Icons.lock_open : Icons.auto_awesome),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: CustomButton(
                                      text: _forking ? 'Forking…' : 'Fork Template',
                                      onPressed: _forking
                                          ? null
                                          : () async {
                                              await _forkTemplate(
                                                templateId: widget.templateId,
                                                defaultName: name,
                                                defaultDescription: desc,
                                              );
                                            },
                                      type: ButtonType.secondary,
                                      icon: const Icon(Icons.fork_right_rounded),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxxl),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }

  List<_CompatBadge> _compatBadges(List<String> tags) {
    final normalized = tags.map((e) => e.trim().toLowerCase()).toList();
    bool hasAny(Set<String> values) => normalized.any(values.contains);

    final out = <_CompatBadge>[];
    final is2d = hasAny({'2d', '2d-ready', '2d_only'});
    final is3d = hasAny({'3d', '3d-ready', '3d_only'});
    final mobile = hasAny({'mobile', 'mobile-ready', 'android', 'ios'});

    if (is2d) out.add(const _CompatBadge(label: '2D', icon: Icons.layers_outlined));
    if (is3d) out.add(const _CompatBadge(label: '3D', icon: Icons.view_in_ar));
    if (mobile) out.add(const _CompatBadge(label: 'Mobile', icon: Icons.phone_iphone));

    return out;
  }

  Future<void> _forkTemplate({
    required String templateId,
    required String defaultName,
    required String defaultDescription,
  }) async {
    if (_forking) return;
    final cs = Theme.of(context).colorScheme;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please sign in to fork.'), backgroundColor: cs.error),
      );
      return;
    }

    final nameController = TextEditingController(text: 'Fork of $defaultName');
    final descController = TextEditingController(text: defaultDescription);
    String? resultName;
    String? resultDesc;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cs.surface,
          title: const Text('Fork template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Project name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                resultName = nameController.text.trim();
                resultDesc = descController.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text('Fork'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    descController.dispose();

    if (resultName == null || resultName!.isEmpty) return;

    setState(() {
      _forking = true;
    });

    try {
      final created = await ProjectsService.createFromTemplate(
        token: token,
        templateId: templateId,
        name: resultName!,
        description: (resultDesc != null && resultDesc!.isNotEmpty) ? resultDesc : null,
      );

      final data = created['data'];
      final projectId = (data is Map)
          ? (data['_id']?.toString() ?? data['id']?.toString())
          : null;

      if (created['success'] != true || projectId == null || projectId.trim().isEmpty) {
        throw Exception(created['message']?.toString() ?? 'Failed to fork template');
      }

      if (!mounted) return;
      context.go('/build-progress', extra: {'projectId': projectId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: cs.error),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _forking = false;
      });
    }
  }

  Widget _buildHero({
    required ColorScheme cs,
    required String? coverUrl,
    required String? previewVideoUrl,
    required VoidCallback? onPlay,
  }) {
    return _DetailsPressableGlow(
      onTap: onPlay,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(
                child: (coverUrl != null && coverUrl.trim().isNotEmpty)
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                            child: const Center(child: Icon(Icons.games, color: Colors.white70, size: 44)),
                          );
                        },
                      )
                    : Container(
                        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                        child: const Center(child: Icon(Icons.games, color: Colors.white70, size: 44)),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.06),
                        Colors.black.withOpacity(0.62),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                bottom: AppSpacing.md,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(0.52),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 16, color: cs.primary),
                          const SizedBox(width: 8),
                          Text('Preview', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (previewVideoUrl != null && previewVideoUrl.trim().isNotEmpty)
                Positioned(
                  bottom: AppSpacing.md,
                  right: AppSpacing.md,
                  child: _DetailsPressableGlow(
                    onTap: onPlay,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: cs.onPrimary),
                          const SizedBox(width: 6),
                          Text('Play', style: AppTypography.caption.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w900)),
                        ],
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

  Widget _buildScreenshots(List<String> urls) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (context, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final u = urls[i];
          return _DetailsPressableGlow(
            onTap: null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  u,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                      child: const Center(child: Icon(Icons.image, color: Colors.white70)),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TemplateDetailsSkeleton extends StatelessWidget {
  const _TemplateDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DetailsShimmer(borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.large)), height: 210),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, __) => const _DetailsShimmer(
                borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.medium)),
                height: 170,
                width: 240,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _DetailsShimmer(borderRadius: BorderRadius.all(Radius.circular(10)), height: 18, width: 240),
          const SizedBox(height: 10),
          const _DetailsShimmer(borderRadius: BorderRadius.all(Radius.circular(10)), height: 14, width: 140),
          const SizedBox(height: AppSpacing.lg),
          const _DetailsShimmer(borderRadius: BorderRadius.all(Radius.circular(999)), height: 28, width: 96),
          const SizedBox(height: 10),
          const _DetailsShimmer(borderRadius: BorderRadius.all(Radius.circular(999)), height: 28, width: 120),
          const SizedBox(height: AppSpacing.xl),
          const _DetailsShimmer(borderRadius: BorderRadius.all(Radius.circular(10)), height: 16, width: 160),
          const SizedBox(height: 10),
          const _DetailsShimmer(borderRadius: BorderRadius.all(Radius.circular(10)), height: 14),
          const SizedBox(height: 8),
          const _DetailsShimmer(borderRadius: BorderRadius.all(Radius.circular(10)), height: 14),
          const SizedBox(height: 8),
          const _DetailsShimmer(borderRadius: BorderRadius.all(Radius.circular(10)), height: 14, width: 260),
        ],
      ),
    );
  }
}

class _DetailsPressableGlow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _DetailsPressableGlow({required this.child, required this.onTap});

  @override
  State<_DetailsPressableGlow> createState() => _DetailsPressableGlowState();
}

class _DetailsPressableGlowState extends State<_DetailsPressableGlow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _down ? 0.985 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            boxShadow: _down
                ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.22),
                      blurRadius: 22,
                      spreadRadius: 1,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _DetailsBadgeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _DetailsBadgeChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.caption.copyWith(color: cs.primary, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DetailsShimmer extends StatefulWidget {
  final BorderRadius borderRadius;
  final double height;
  final double? width;
  const _DetailsShimmer({required this.borderRadius, required this.height, this.width});

  @override
  State<_DetailsShimmer> createState() => _DetailsShimmerState();
}

class _DetailsShimmerState extends State<_DetailsShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final x = -1.0 + (2.0 * t);
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.22),
            ),
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment(x - 1, 0),
                  end: Alignment(x + 1, 0),
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.25, 0.5, 0.75],
                ).createShader(rect);
              },
              blendMode: BlendMode.srcATop,
              child: Container(color: Colors.white.withOpacity(0.06)),
            ),
          ),
        );
      },
    );
  }
}

class _CompatBadge {
  final String label;
  final IconData icon;

  const _CompatBadge({
    required this.label,
    required this.icon,
  });
}

class _ReviewListItem extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewListItem({required this.review});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final usernameRaw = review['username']?.toString();
    final username = (usernameRaw != null && usernameRaw.trim().isNotEmpty) ? usernameRaw : 'User';
    final rating = (review['rating'] is num) ? (review['rating'] as num).toInt() : 0;
    final comment = review['comment']?.toString() ?? '';

    return Container(
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
                  username,
                  style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Row(
                children: List.generate(5, (i) {
                  final filled = i < rating;
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 16,
                    color: filled ? AppColors.warning : cs.outline,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            comment,
            style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _UserReviewCard extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _UserReviewCard({
    required this.rating,
    required this.onRatingChanged,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        boxShadow: AppShadows.boxShadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rate_review, color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Your rating', style: AppTypography.subtitle2),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: AppBorderRadius.allSmall,
                ),
                child: Text(
                  rating == 0 ? 'Tap stars' : '$rating/5',
                  style: AppTypography.caption.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _StarRatingInput(
            value: rating,
            onChanged: onRatingChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Tell people what you liked (no insults, please).',
              filled: true,
              fillColor: cs.surfaceVariant.withOpacity(0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                borderSide: BorderSide(color: cs.primary.withOpacity(0.8), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: submitting ? 'Submitting...' : 'Submit review',
                  onPressed: submitting ? null : onSubmit,
                  type: ButtonType.primary,
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarRatingInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarRatingInput({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(5, (i) {
        final v = i + 1;
        final selected = value >= v;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onChanged(v),
            child: Icon(
              selected ? Icons.star : Icons.star_border,
              color: selected ? AppColors.warning : cs.onSurfaceVariant,
              size: 28,
            ),
          ),
        );
      }),
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
                            aspectRatio: _controller.value.aspectRatio == 0 ? 16 / 9 : _controller.value.aspectRatio,
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
                              '${_controller.value.position.inSeconds}s',
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
