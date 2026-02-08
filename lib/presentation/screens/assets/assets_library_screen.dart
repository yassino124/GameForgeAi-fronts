import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/assets_service.dart';
import '../../widgets/widgets.dart';

class AssetsLibraryScreen extends StatefulWidget {
  const AssetsLibraryScreen({super.key});

  @override
  State<AssetsLibraryScreen> createState() => _AssetsLibraryScreenState();
}

class _AssetsLibraryScreenState extends State<AssetsLibraryScreen> {
  bool _loading = false;
  String? _error;
  List<dynamic> _items = const [];

  final TextEditingController _searchController = TextEditingController();
  String? _selectedType;
  int _page = 1;
  int _limit = 20;
  int _total = 0;
  bool _loadingMore = false;

  List<dynamic> _collections = const [];
  String? _selectedCollectionId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _page = 1;
      _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _uploadByUrl() async {
    final token = _getToken();
    if (token == null || token.isEmpty) return;

    String selectedType = 'other';
    String url = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Upload from URL'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'File URL (https://...)'),
                    onChanged: (v) => setDialogState(() => url = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'texture', child: Text('Texture')),
                      DropdownMenuItem(value: 'model', child: Text('Model')),
                      DropdownMenuItem(value: 'audio', child: Text('Audio')),
                      DropdownMenuItem(value: 'shader', child: Text('Shader')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => selectedType = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: url.trim().isEmpty ? null : () => Navigator.of(ctx).pop(true),
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (ok != true) return;

    url = url.trim();
    if (url.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AssetsService.uploadAssetByUrl(
        token: token,
        url: url,
        type: selectedType,
        collectionId: _selectedCollectionId,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _getToken() {
    try {
      return context.read<AuthProvider>().token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final token = _getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Please sign in to manage your Unity assets.';
        _items = const [];
        _collections = const [];
        _selectedCollectionId = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final colRes = await AssetsService.listCollections(token: token);
      final listRes = await AssetsService.listAssets(
        token: token,
        collectionId: _selectedCollectionId,
        type: _selectedType,
        q: _searchController.text,
        page: 1,
        limit: _limit,
      );

      setState(() {
        _collections = (colRes['success'] == true && colRes['data'] is List) ? (colRes['data'] as List) : const [];
        final data = listRes['data'];
        final map = (listRes['success'] == true && data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _items = (map['items'] is List) ? (map['items'] as List) : const [];
        _page = (map['page'] is num) ? (map['page'] as num).toInt() : 1;
        _limit = (map['limit'] is num) ? (map['limit'] as num).toInt() : _limit;
        _total = (map['total'] is num) ? (map['total'] as num).toInt() : _items.length;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _createCollection() async {
    final token = _getToken();
    if (token == null || token.isEmpty) return;

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('New Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
              const SizedBox(height: 6),
              Text(
                'Example Unity path root: Assets/GameForge/<CollectionName>/',
                style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create')),
          ],
        );
      },
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    await AssetsService.createCollection(
      token: token,
      name: name,
      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    );

    await _load();
  }

  Future<void> _pickAndUpload() async {
    final token = _getToken();
    if (token == null || token.isEmpty) return;

    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;

    final picked = res.files.first;
    final path = picked.path;
    File file;
    if (path != null && path.isNotEmpty) {
      file = File(path);
    } else {
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) return;
      final safeName = (picked.name.isNotEmpty ? picked.name : 'asset')
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final tmp = File('${Directory.systemTemp.path}/gf_${DateTime.now().millisecondsSinceEpoch}_$safeName');
      await tmp.writeAsBytes(bytes, flush: true);
      file = tmp;
    }

    final type = await _askType();
    if (type == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AssetsService.uploadAsset(
        token: token,
        file: file,
        type: type,
        collectionId: _selectedCollectionId,
      );
      await _load();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<String?> _askType() async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Texture'),
                onTap: () => Navigator.of(ctx).pop('texture'),
              ),
              ListTile(
                leading: const Icon(Icons.view_in_ar_outlined),
                title: const Text('Model'),
                onTap: () => Navigator.of(ctx).pop('model'),
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack_outlined),
                title: const Text('Audio'),
                onTap: () => Navigator.of(ctx).pop('audio'),
              ),
              ListTile(
                leading: const Icon(Icons.code_outlined),
                title: const Text('Shader'),
                onTap: () => Navigator.of(ctx).pop('shader'),
              ),
              ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('Other'),
                onTap: () => Navigator.of(ctx).pop('other'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportSelectedCollection() async {
    final token = _getToken();
    if (token == null || token.isEmpty) return;
    if (_selectedCollectionId == null || _selectedCollectionId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a collection first')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final created = await AssetsService.createExport(
        token: token,
        collectionId: _selectedCollectionId!,
        format: 'zip',
      );
      final exportId = (created['data'] is Map) ? (created['data']['_id']?.toString() ?? created['data']['id']?.toString()) : null;
      if (exportId == null || exportId.isEmpty) {
        throw Exception('Missing export id');
      }

      Map<String, dynamic> job;
      while (true) {
        final r = await AssetsService.getExport(token: token, exportId: exportId);
        job = (r['data'] is Map) ? Map<String, dynamic>.from(r['data']) : <String, dynamic>{};
        final status = job['status']?.toString();
        if (status == 'ready') break;
        if (status == 'failed') {
          throw Exception(job['error']?.toString() ?? 'Export failed');
        }
        await Future<void>.delayed(const Duration(milliseconds: 650));
      }

      final urlRes = await AssetsService.getExportDownloadUrl(token: token, exportId: exportId);
      final url = (urlRes['data'] is Map) ? urlRes['data']['url']?.toString() : null;
      if (url == null || url.isEmpty) throw Exception('Missing download url');

      if (!mounted) return;
      context.push('/assets/export', extra: {'url': url});
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    if (_items.length >= _total) return;

    final token = _getToken();
    if (token == null || token.isEmpty) return;

    setState(() {
      _loadingMore = true;
    });

    try {
      final nextPage = _page + 1;
      final listRes = await AssetsService.listAssets(
        token: token,
        collectionId: _selectedCollectionId,
        type: _selectedType,
        q: _searchController.text,
        page: nextPage,
        limit: _limit,
      );

      final data = listRes['data'];
      final map = (listRes['success'] == true && data is Map)
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final nextItems = (map['items'] is List) ? (map['items'] as List) : const [];

      if (!mounted) return;
      setState(() {
        _items = [..._items, ...nextItems];
        _page = (map['page'] is num) ? (map['page'] as num).toInt() : nextPage;
        _total = (map['total'] is num) ? (map['total'] as num).toInt() : _total;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
      });
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'texture':
        return Icons.image_outlined;
      case 'model':
        return Icons.view_in_ar_outlined;
      case 'audio':
        return Icons.audiotrack_outlined;
      case 'shader':
        return Icons.code_outlined;
      default:
        return Icons.widgets_outlined;
    }
  }

  String _fmtSize(dynamic size) {
    final s = (size is num) ? size.toDouble() : double.tryParse(size?.toString() ?? '') ?? 0.0;
    if (s <= 0) return '';
    const kb = 1024.0;
    const mb = kb * 1024.0;
    if (s >= mb) return '${(s / mb).toStringAsFixed(1)} MB';
    if (s >= kb) return '${(s / kb).toStringAsFixed(1)} KB';
    return '${s.toStringAsFixed(0)} B';
  }

  Future<void> _downloadAsset(Map<String, dynamic> asset) async {
    final token = _getToken();
    if (token == null || token.isEmpty) return;
    final id = (asset['_id'] ?? asset['id'])?.toString() ?? '';
    if (id.isEmpty) return;

    final res = await AssetsService.getDownloadUrl(token: token, assetId: id);
    final url = (res['success'] == true && res['data'] is Map)
        ? (res['data']['url']?.toString() ?? '')
        : '';
    if (url.isEmpty) return;

    if (!mounted) return;
    context.push('/assets/export', extra: {'url': url});
  }

  Future<void> _deleteAsset(Map<String, dynamic> asset) async {
    final token = _getToken();
    if (token == null || token.isEmpty) return;
    final id = (asset['_id'] ?? asset['id'])?.toString() ?? '';
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete asset?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _loading = true;
    });
    try {
      await AssetsService.deleteAsset(token: token, assetId: id);
      await _load();
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _assetCard(Map<String, dynamic> a) {
    final cs = Theme.of(context).colorScheme;
    final name = a['name']?.toString() ?? 'Asset';
    final type = a['type']?.toString() ?? 'other';
    final unityPath = a['unityPath']?.toString() ?? '';
    final size = _fmtSize(a['size']);
    final tags = (a['tags'] is List)
        ? (a['tags'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    return Container(
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                ),
                child: Icon(_typeIcon(type), color: cs.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [type.toUpperCase(), if (size.isNotEmpty) size].join(' • '),
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'download') await _downloadAsset(a);
                  if (v == 'delete') await _deleteAsset(a);
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'download', child: Text('Download')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (unityPath.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              unityPath,
              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(5).map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Text(t, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _downloadAsset(a),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _deleteAsset(a),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final token = _getToken();
    final isAuthed = token != null && token.isNotEmpty;
    final needsCollection = isAuthed && !_loading && _collections.isEmpty;
    final canLoadMore = !_loading && !_loadingMore && _items.length < _total;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: true,
        title: const Text('Unity Assets'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'new_collection',
            onPressed: (!isAuthed || _loading) ? null : _createCollection,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Collection'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'upload_url',
            onPressed: (!isAuthed || _loading) ? null : _uploadByUrl,
            icon: const Icon(Icons.link),
            label: const Text('Upload URL'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'upload_asset',
            onPressed: (!isAuthed || _loading) ? null : _pickAndUpload,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload'),
          ),
        ],
      ),
      body: Padding(
        padding: AppSpacing.paddingLarge,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search assets...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCollectionId,
                        isExpanded: true,
                        hint: const Text('All collections'),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('All collections')),
                          ..._collections
                              .where((e) => e is Map)
                              .map((c) {
                                final cm = Map<String, dynamic>.from(c as Map);
                                final id = (cm['_id'] ?? cm['id'])?.toString();
                                final name = cm['name']?.toString() ?? 'Collection';
                                if (id == null || id.isEmpty) return null;
                                return DropdownMenuItem<String>(value: id, child: Text(name));
                              })
                              .whereType<DropdownMenuItem<String>>(),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCollectionId = val;
                            _page = 1;
                          });
                          _load();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      hint: const Text('Type'),
                      items: const [
                        DropdownMenuItem<String>(value: null, child: Text('All')),
                        DropdownMenuItem<String>(value: 'texture', child: Text('Texture')),
                        DropdownMenuItem<String>(value: 'model', child: Text('Model')),
                        DropdownMenuItem<String>(value: 'audio', child: Text('Audio')),
                        DropdownMenuItem<String>(value: 'shader', child: Text('Shader')),
                        DropdownMenuItem<String>(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedType = val;
                          _page = 1;
                        });
                        _load();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: (!isAuthed || _loading || _selectedCollectionId == null)
                      ? null
                      : _exportSelectedCollection,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Export ZIP'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (!isAuthed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sign in to create collections, upload assets, and export ZIP.',
                        style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => context.go('/signin'),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            if (!isAuthed) const SizedBox(height: 12),

            if (needsCollection)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: cs.primary.withOpacity(0.25)),
                ),
                child: Text(
                  'Start here: 1) Tap "Collection" to create one. 2) Tap "Upload" to add assets. 3) Select your collection to enable Export ZIP.',
                  style: AppTypography.body2.copyWith(color: cs.onSurface),
                ),
              ),
            if (needsCollection) const SizedBox(height: 12),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
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
            if (_loading) const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_items.isEmpty)
                      ? Center(
                          child: Text(
                            isAuthed ? 'No assets yet' : 'Sign in to see your assets',
                            style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            itemCount: _items.length + (canLoadMore ? 1 : 0),
                            separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, i) {
                              if (canLoadMore && i == _items.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                  child: Center(
                                    child: OutlinedButton(
                                      onPressed: _loadMore,
                                      child: _loadingMore
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : Text('Load more (${_items.length}/$_total)'),
                                    ),
                                  ),
                                );
                              }

                              final raw = _items[i];
                              final a = raw is Map ? Map<String, dynamic>.from(raw as Map) : <String, dynamic>{};
                              return _assetCard(a);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

}
