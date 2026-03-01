import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/admin_button.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchTemplates();
    });
  }

  static const _categoryColors = {
    'Platformer': AdminTheme.accentNeon,
    'Shooter': AdminTheme.accentRed,
    'RPG': AdminTheme.accentPurple,
    'Puzzle': AdminTheme.accentGreen,
    'Racing': AdminTheme.accentOrange,
    'Strategy': AdminTheme.accentPurple,
    'Music': AdminTheme.accentOrange,
    'Survival': AdminTheme.accentGreen,
    'Casual': AdminTheme.accentNeon,
    'Adventure': AdminTheme.accentPurple,
    'Simulation': AdminTheme.accentGreen,
    'default': AdminTheme.textSecondary,
  };

  static const _categories = ['all', 'Platformer', 'Shooter', 'RPG', 'Puzzle', 'Racing', 'Adventure'];

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final filteredTemplates = provider.filteredTemplates;
        final templates = provider.paginatedTemplates;
        final isGrid = provider.marketplaceGridView;
        final isLoading = provider.templatesLoading;
        final error = provider.templatesError;
        final currentPage = provider.templatesCurrentPage;
        final totalPages = provider.templatesTotalPages;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ..._categories.map((c) => FilterChip(
                  label: Text(c == 'all' ? 'All' : c),
                  selected: provider.marketplaceCategoryFilter.toLowerCase() == c.toLowerCase(),
                  onSelected: (_) => provider.setMarketplaceCategoryFilter(c),
                  selectedColor: AdminTheme.accentNeon.withOpacity(0.3),
                  checkmarkColor: AdminTheme.accentNeon,
                )),
                const Spacer(),
                IconButton(
                  icon: Icon(provider.marketplaceGridView ? Icons.grid_view : Icons.list, color: AdminTheme.textSecondary),
                  onPressed: () => provider.setMarketplaceGridView(!provider.marketplaceGridView),
                  tooltip: provider.marketplaceGridView ? 'List view' : 'Grid view',
                ),
                AdminButton(label: 'Add New Template', icon: Icons.add, onPressed: () => _showTemplateModal(context)),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: AdminTheme.accentNeon),
                ),
              )
            else if (error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AdminTheme.accentRed, size: 48),
                      const SizedBox(height: 16),
                      Text(error, style: const TextStyle(color: AdminTheme.textSecondary)),
                      const SizedBox(height: 16),
                      AdminButton(
                        label: 'Retry',
                        icon: Icons.refresh,
                        onPressed: () => provider.fetchTemplates(),
                      ),
                    ],
                  ),
                ),
              )
            else if (filteredTemplates.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text(
                    'No templates found',
                    style: TextStyle(color: AdminTheme.textSecondary, fontSize: 16),
                  ),
                ),
              )
            else if (isGrid)
              Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : 2);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: templates.length,
                        itemBuilder: (context, i) => _TemplateCard(
                          template: templates[i],
                          color: _categoryColors[templates[i]['category']] ?? _categoryColors['default']!,
                          onEdit: () => _showTemplateModal(context, templates[i]),
                          onToggle: () => _showToggleConfirm(context, templates[i]),
                        ),
                      );
                    }
                  ),
                  // Pagination controls
                  if (totalPages > 1) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: AdminTheme.textSecondary),
                          onPressed: provider.templatesHasPrevPage ? provider.prevTemplatesPage : null,
                          tooltip: 'Previous page',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AdminTheme.bgSecondary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminTheme.borderGlow),
                          ),
                          child: Text(
                            'Page $currentPage of $totalPages',
                            style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: AdminTheme.textSecondary),
                          onPressed: provider.templatesHasNextPage ? provider.nextTemplatesPage : null,
                          tooltip: 'Next page',
                        ),
                      ],
                    ),
                  ],
                ],
              )
            else
              Column(
                children: [
                  ...templates.map((t) => _TemplateListTile(
                    template: t,
                    color: _categoryColors[t['category']] ?? _categoryColors['default']!,
                    onEdit: () => _showTemplateModal(context, t),
                  )),
                  // Pagination controls for list view
                  if (totalPages > 1) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: AdminTheme.textSecondary),
                          onPressed: provider.templatesHasPrevPage ? provider.prevTemplatesPage : null,
                          tooltip: 'Previous page',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AdminTheme.bgSecondary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminTheme.borderGlow),
                          ),
                          child: Text(
                            'Page $currentPage of $totalPages',
                            style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: AdminTheme.textSecondary),
                          onPressed: provider.templatesHasNextPage ? provider.nextTemplatesPage : null,
                          tooltip: 'Next page',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }

  void _showTemplateModal(BuildContext context, [Map<String, dynamic>? template]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => template != null
          ? _EditTemplateDialog(template: template)
          : _AddTemplateDialog(),
    );
  }

  void _showToggleConfirm(BuildContext context, Map<String, dynamic> template) {
    final isActive = template['isActive'] != false;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: Text(isActive ? 'Deactivate Template' : 'Activate Template', 
          style: const TextStyle(color: AdminTheme.textPrimary)),
        content: Text(
          isActive 
            ? 'This template will no longer appear to users'
            : 'This template will be visible to users again',
          style: const TextStyle(color: AdminTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<AdminProvider>();
              final success = await provider.toggleTemplate(template['_id'].toString());
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Template ${isActive ? 'deactivated' : 'activated'}'), backgroundColor: AdminTheme.accentGreen),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('Failed to toggle template'), backgroundColor: AdminTheme.accentRed),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentOrange,
              foregroundColor: AdminTheme.bgPrimary,
            ),
            child: Text(isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for adding a new template with file upload
class _AddTemplateDialog extends StatefulWidget {
  @override
  State<_AddTemplateDialog> createState() => _AddTemplateDialogState();
}

class _AddTemplateDialogState extends State<_AddTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  
  String _selectedCategory = 'Platformer';
  Uint8List? _zipFileBytes;
  Uint8List? _previewImageBytes;
  String? _zipFileName;
  String? _previewImageName;
  bool _generatingDescription = false;
  
  final List<String> _categories = ['Platformer', 'FPS', 'RPG', 'Puzzle', 'General'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickZipFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,  // Critical for Flutter Web
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _zipFileBytes = file.bytes;
        _zipFileName = file.name;
      });
    }
  }

  Future<void> _pickPreviewImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,  // Critical for Flutter Web
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _previewImageBytes = file.bytes;
        _previewImageName = file.name;
      });
    }
  }

  Future<void> _generateDescription() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a template name first'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _generatingDescription = true);
    
    final provider = context.read<AdminProvider>();
    final description = await provider.generateAiDescription(
      name: name,
      category: _selectedCategory,
      tags: _tagsController.text.trim(),
    );
    
    if (mounted) {
      setState(() => _generatingDescription = false);
      
      if (description != null && description.isNotEmpty) {
        _descriptionController.text = description;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Description generated successfully!'),
            backgroundColor: AdminTheme.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate description'),
            backgroundColor: AdminTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _submitUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_zipFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a .zip file'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
      return;
    }

    final provider = context.read<AdminProvider>();
    final success = await provider.uploadTemplate(
      zipFileBytes: _zipFileBytes!,
      zipFileName: _zipFileName!,
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      category: _selectedCategory,
      tags: _tagsController.text.trim().isNotEmpty ? _tagsController.text.trim() : null,
      price: _priceController.text.trim(),
      previewImageBytes: _previewImageBytes,
      previewImageFileName: _previewImageName,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template uploaded successfully!'),
          backgroundColor: AdminTheme.accentGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to upload template. Please try again.'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isUploading = provider.uploadingTemplate;

    return AlertDialog(
      backgroundColor: AdminTheme.bgSecondary,
      title: const Text(
        'Add New Template',
        style: TextStyle(color: AdminTheme.textPrimary),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zip file picker (required)
                const Text(
                  'Template File (required)',
                  style: TextStyle(
                    color: AdminTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: isUploading ? null : _pickZipFile,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminTheme.bgTertiary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _zipFileBytes != null ? AdminTheme.accentNeon : AdminTheme.borderGlow,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _zipFileBytes != null ? Icons.check_circle : Icons.file_upload,
                          color: _zipFileBytes != null ? AdminTheme.accentNeon : AdminTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _zipFileName ?? 'Click to select .zip file',
                            style: TextStyle(
                              color: _zipFileBytes != null ? AdminTheme.textPrimary : AdminTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name field
                TextFormField(
                  controller: _nameController,
                  enabled: !isUploading,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                    labelStyle: TextStyle(color: AdminTheme.textSecondary),
                    hintText: 'Auto-filled from zip if empty',
                    hintStyle: TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                  ),
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
                const SizedBox(height: 16),

                // Category dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: AdminTheme.textSecondary),
                  ),
                  dropdownColor: AdminTheme.bgSecondary,
                  style: const TextStyle(color: AdminTheme.textPrimary),
                  items: _categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: isUploading ? null : (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Description field with AI button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Description (optional)',
                      style: TextStyle(
                        color: AdminTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: (isUploading || _generatingDescription) ? null : _generateDescription,
                      icon: _generatingDescription
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AdminTheme.accentPurple),
                            )
                          : const Icon(Icons.auto_awesome, size: 16, color: AdminTheme.accentPurple),
                      label: const Text('Generate with AI', style: TextStyle(color: AdminTheme.accentPurple, fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !isUploading,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter description or generate with AI',
                    hintStyle: TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                  ),
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
                const SizedBox(height: 16),

                // Tags field
                TextFormField(
                  controller: _tagsController,
                  enabled: !isUploading,
                  decoration: const InputDecoration(
                    labelText: 'Tags (optional)',
                    labelStyle: TextStyle(color: AdminTheme.textSecondary),
                    hintText: 'Comma-separated: 3D, multiplayer, FPS',
                    hintStyle: TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                  ),
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
                const SizedBox(height: 16),

                // Price field
                TextFormField(
                  controller: _priceController,
                  enabled: !isUploading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    labelStyle: TextStyle(color: AdminTheme.textSecondary),
                    hintText: '0 for free',
                    hintStyle: TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                  ),
                  style: const TextStyle(color: AdminTheme.textPrimary),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final price = double.tryParse(value);
                      if (price == null || price < 0) {
                        return 'Please enter a valid price';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Preview image picker (optional)
                const Text(
                  'Preview Image (optional)',
                  style: TextStyle(
                    color: AdminTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: isUploading ? null : _pickPreviewImage,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminTheme.bgTertiary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _previewImageBytes != null ? AdminTheme.accentPurple : AdminTheme.borderGlow,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _previewImageBytes != null ? Icons.image : Icons.add_photo_alternate,
                          color: _previewImageBytes != null ? AdminTheme.accentPurple : AdminTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _previewImageName ?? 'Click to select image',
                            style: TextStyle(
                              color: _previewImageBytes != null ? AdminTheme.textPrimary : AdminTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AdminTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: isUploading ? null : _submitUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.accentNeon,
            foregroundColor: AdminTheme.bgPrimary,
            disabledBackgroundColor: AdminTheme.accentNeon.withOpacity(0.5),
          ),
          child: isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AdminTheme.bgPrimary),
                  ),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }
}

/// Dialog for editing an existing template
class _EditTemplateDialog extends StatefulWidget {
  final Map<String, dynamic> template;

  const _EditTemplateDialog({required this.template});

  @override
  State<_EditTemplateDialog> createState() => _EditTemplateDialogState();
}

class _EditTemplateDialogState extends State<_EditTemplateDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.template['name']?.toString() ?? '');
  late final _descriptionController = TextEditingController(text: widget.template['description']?.toString() ?? '');
  late final _tagsController = TextEditingController(
    text: (widget.template['tags'] is List)
        ? (widget.template['tags'] as List).join(', ')
        : widget.template['tags']?.toString() ?? '',
  );
  late final _priceController = TextEditingController(text: widget.template['price']?.toString() ?? '0');
  
  late String _selectedCategory = widget.template['category']?.toString() ?? 'Platformer';
  Uint8List? _zipFileBytes;
  Uint8List? _previewImageBytes;
  String? _zipFileName;
  String? _previewImageName;
  bool _generatingDescription = false;
  
  final List<String> _categories = ['Platformer', 'FPS', 'RPG', 'Puzzle', 'General'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickZipFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _zipFileBytes = file.bytes;
        _zipFileName = file.name;
      });
    }
  }

  Future<void> _pickPreviewImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _previewImageBytes = file.bytes;
        _previewImageName = file.name;
      });
    }
  }

  Future<void> _generateDescription() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a template name first'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _generatingDescription = true);
    
    final provider = context.read<AdminProvider>();
    final description = await provider.generateAiDescription(
      name: name,
      category: _selectedCategory,
      tags: _tagsController.text.trim(),
    );
    
    if (mounted) {
      setState(() => _generatingDescription = false);
      
      if (description != null && description.isNotEmpty) {
        _descriptionController.text = description;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Description generated successfully!'),
            backgroundColor: AdminTheme.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate description'),
            backgroundColor: AdminTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AdminProvider>();
    final success = await provider.editTemplate(
      templateId: widget.template['_id'].toString(),
      zipFileBytes: _zipFileBytes,
      zipFileName: _zipFileName,
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      category: _selectedCategory,
      tags: _tagsController.text.trim().isNotEmpty ? _tagsController.text.trim() : null,
      price: _priceController.text.trim(),
      previewImageBytes: _previewImageBytes,
      previewImageFileName: _previewImageName,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template updated successfully!'),
          backgroundColor: AdminTheme.accentGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update template. Please try again.'),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final isUpdating = provider.uploadingTemplate;

    return AlertDialog(
      backgroundColor: AdminTheme.bgSecondary,
      title: const Text(
        'Edit Template',
        style: TextStyle(color: AdminTheme.textPrimary),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zip file picker (optional for edit)
                const Text(
                  'Template File (optional - leave empty to keep current)',
                  style: TextStyle(
                    color: AdminTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: isUpdating ? null : _pickZipFile,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminTheme.bgTertiary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _zipFileBytes != null ? AdminTheme.accentNeon : AdminTheme.borderGlow,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _zipFileBytes != null ? Icons.check_circle : Icons.file_upload,
                          color: _zipFileBytes != null ? AdminTheme.accentNeon : AdminTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _zipFileName ?? 'Click to select new .zip file (optional)',
                            style: TextStyle(
                              color: _zipFileBytes != null ? AdminTheme.textPrimary : AdminTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name field
                TextFormField(
                  controller: _nameController,
                  enabled: !isUpdating,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: AdminTheme.textSecondary),
                  ),
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
                const SizedBox(height: 16),

                // Category dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: AdminTheme.textSecondary),
                  ),
                  dropdownColor: AdminTheme.bgSecondary,
                  style: const TextStyle(color: AdminTheme.textPrimary),
                  items: _categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: isUpdating ? null : (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Description field with AI button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: AdminTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: (isUpdating || _generatingDescription) ? null : _generateDescription,
                      icon: _generatingDescription
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AdminTheme.accentPurple),
                            )
                          : const Icon(Icons.auto_awesome, size: 16, color: AdminTheme.accentPurple),
                      label: const Text('Generate with AI', style: TextStyle(color: AdminTheme.accentPurple, fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !isUpdating,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter description or generate with AI',
                    hintStyle: TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                  ),
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
                const SizedBox(height: 16),

                // Tags field
                TextFormField(
                  controller: _tagsController,
                  enabled: !isUpdating,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    labelStyle: TextStyle(color: AdminTheme.textSecondary),
                    hintText: 'Comma-separated: 3D, multiplayer, FPS',
                    hintStyle: TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                  ),
                  style: const TextStyle(color: AdminTheme.textPrimary),
                ),
                const SizedBox(height: 16),

                // Price field
                TextFormField(
                  controller: _priceController,
                  enabled: !isUpdating,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    labelStyle: TextStyle(color: AdminTheme.textSecondary),
                    hintText: '0 for free',
                    hintStyle: TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                  ),
                  style: const TextStyle(color: AdminTheme.textPrimary),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final price = double.tryParse(value);
                      if (price == null || price < 0) {
                        return 'Please enter a valid price';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Preview image picker (optional)
                const Text(
                  'Preview Image (optional)',
                  style: TextStyle(
                    color: AdminTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: isUpdating ? null : _pickPreviewImage,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminTheme.bgTertiary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _previewImageBytes != null ? AdminTheme.accentPurple : AdminTheme.borderGlow,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _previewImageBytes != null ? Icons.image : Icons.add_photo_alternate,
                          color: _previewImageBytes != null ? AdminTheme.accentPurple : AdminTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _previewImageName ?? 'Click to select image (optional)',
                            style: TextStyle(
                              color: _previewImageBytes != null ? AdminTheme.textPrimary : AdminTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isUpdating ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AdminTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: isUpdating ? null : _submitUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.accentNeon,
            foregroundColor: AdminTheme.bgPrimary,
            disabledBackgroundColor: AdminTheme.accentNeon.withOpacity(0.5),
          ),
          child: isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AdminTheme.bgPrimary),
                  ),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> template;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _TemplateCard({required this.template, required this.color, required this.onEdit, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final platforms = (template['platforms'] as List?)?.cast<String>() ?? [];
    final price = template['price'];
    final priceStr = (price == 0 || price == 0.0) ? 'FREE' : '\$${price.toStringAsFixed(2)}';

    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.5), color.withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template['name']?.toString() ?? '',
                    style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${template['category']} ★ ${template['rating'] ?? 0}',
                    style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(template['downloads'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} downloads',
                    style: GoogleFonts.jetBrainsMono(color: AdminTheme.textMuted, fontSize: 11),
                  ),
                  Text(template['unityVersion']?.toString() ?? '', style: GoogleFonts.jetBrainsMono(color: AdminTheme.textMuted, fontSize: 11)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: platforms.take(4).map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AdminTheme.bgTertiary, borderRadius: BorderRadius.circular(4)),
                      child: Text(p, style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 10)),
                    )).toList(),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(priceStr, style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.accentNeon)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 18, color: AdminTheme.accentPurple), onPressed: onEdit, tooltip: 'Edit'),
                          IconButton(icon: Icon((template['isActive'] != false ? Icons.toggle_on : Icons.toggle_off), size: 24, color: template['isActive'] != false ? AdminTheme.accentGreen : AdminTheme.accentRed), onPressed: onToggle, tooltip: template['isActive'] != false ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateListTile extends StatelessWidget {
  final Map<String, dynamic> template;
  final Color color;
  final VoidCallback onEdit;

  const _TemplateListTile({required this.template, required this.color, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final price = template['price'];
    final priceStr = (price == 0 || price == 0.0) ? 'FREE' : '\$${price.toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template['name']?.toString() ?? '', style: GoogleFonts.orbitron(fontSize: 16, color: AdminTheme.textPrimary)),
                Text('${template['category']} • ★ ${template['rating']} • ${template['downloads']} downloads', style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(priceStr, style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.accentNeon)),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.edit, color: AdminTheme.accentPurple), onPressed: onEdit, tooltip: 'Edit'),
        ],
      ),
    );
  }
}
