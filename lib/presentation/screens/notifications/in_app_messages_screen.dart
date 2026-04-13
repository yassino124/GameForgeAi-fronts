import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:mime/mime.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/support_tickets_service.dart';
import '../../widgets/widgets.dart';

class InAppMessagesScreen extends StatefulWidget {
  const InAppMessagesScreen({super.key});

  @override
  State<InAppMessagesScreen> createState() => _InAppMessagesScreenState();
}

class _InAppMessagesScreenState extends State<InAppMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _macros = [];
  List<Map<String, dynamic>> _pendingAttachments = [];

  bool _loadingTickets = false;
  bool _loadingMessages = false;
  bool _sending = false;
  String? _selectedTicketId;
  String _ticketFilterStatus = 'all';
  String _ticketFilterPriority = 'all';
  String? _queuedMacroKey;

  bool get _isSupportAgent {
    try {
      final auth = context.read<AuthProvider>();
      return auth.isAdmin || auth.isDevl;
    } catch (_) {
      return false;
    }
  }

  String? get _token {
    try {
      final t = context.read<AuthProvider>().token;
      if (t == null || t.trim().isEmpty) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get _selectedTicket {
    final id = _selectedTicketId;
    if (id == null) return null;
    for (final t in _tickets) {
      if ((t['_id']?.toString() ?? '') == id) return t;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final token = _token;
    if (token == null) {
      AppNotifier.showError('Please sign in first');
      return;
    }

    await Future.wait([
      _loadTickets(),
      _loadMacros(),
    ]);
  }

  Future<void> _loadMacros() async {
    if (!_isSupportAgent) {
      if (!mounted) return;
      setState(() => _macros = const []);
      return;
    }

    final token = _token;
    if (token == null) return;
    try {
      final res = await SupportTicketsService.listMacros(token: token);
      if (!mounted) return;
      final data = res['data'];
      final items = data is List ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
      setState(() => _macros = items);
    } catch (_) {}
  }

  Future<void> _loadTickets() async {
    final token = _token;
    if (token == null) return;

    setState(() => _loadingTickets = true);
    try {
      final status = _ticketFilterStatus == 'all' ? null : _ticketFilterStatus;
      final priority = _ticketFilterPriority == 'all' ? null : _ticketFilterPriority;
      final q = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
      final res = await SupportTicketsService.listTickets(
        token: token,
        status: status,
        priority: priority,
        q: q,
      );

      final data = res['data'];
      final list = data is List
          ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      String? nextSelectedId = _selectedTicketId;
      if (nextSelectedId == null || !list.any((e) => (e['_id']?.toString() ?? '') == nextSelectedId)) {
        nextSelectedId = list.isNotEmpty ? (list.first['_id']?.toString()) : null;
      }

      if (!mounted) return;
      setState(() {
        _tickets = list;
        _selectedTicketId = nextSelectedId;
      });

      if (nextSelectedId != null) {
        await _loadMessages(nextSelectedId);
      } else {
        if (!mounted) return;
        setState(() => _messages = const []);
      }
    } catch (e) {
      AppNotifier.showError('Failed to load tickets');
    } finally {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _loadMessages(String ticketId) async {
    final token = _token;
    if (token == null) return;

    setState(() => _loadingMessages = true);
    try {
      final res = await SupportTicketsService.listMessages(token: token, ticketId: ticketId);
      final data = res['data'];
      final list = data is List
          ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() => _messages = list);
      _scrollToBottom();
    } catch (_) {
      AppNotifier.showError('Failed to load messages');
    } finally {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to dashboard',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: AppColors.primary),
            SizedBox(width: AppSpacing.sm),
            Text('Support Tickets'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadingTickets ? null : _loadTickets,
            icon: const Icon(
              Icons.refresh,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTicketDialog,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New Ticket'),
      ),

      body: Column(
        children: [
          _buildFiltersBar(),
          Expanded(
            child: isCompact
                ? (_selectedTicketId == null
                    ? _buildTicketList(isCompact: true)
                    : _buildConversationPanel(isCompact: true))
                : Row(
                    children: [
                      SizedBox(
                        width: 290,
                        child: _buildTicketList(),
                      ),
                      const VerticalDivider(width: 1, color: AppColors.border),
                      Expanded(
                        child: _buildConversationPanel(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadTickets(),
              decoration: InputDecoration(
                hintText: 'Search ticket subject...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildEnumFilter(
            value: _ticketFilterStatus,
            items: const ['all', 'open', 'pending', 'closed'],
            onChanged: (v) {
              setState(() => _ticketFilterStatus = v);
              _loadTickets();
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildEnumFilter(
            value: _ticketFilterPriority,
            items: const ['all', 'low', 'normal', 'high', 'urgent'],
            onChanged: (v) {
              setState(() => _ticketFilterPriority = v);
              _loadTickets();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnumFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildTicketList({bool isCompact = false}) {
    if (_loadingTickets && _tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent_rounded, color: AppColors.primary.withOpacity(0.85), size: 38),
              const SizedBox(height: AppSpacing.md),
              const Text('No tickets yet. Create your first support ticket.', textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              if (isCompact)
                OutlinedButton.icon(
                  onPressed: _showCreateTicketDialog,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Create ticket'),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _tickets.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
      itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final id = ticket['_id']?.toString() ?? '';
        final selected = id == _selectedTicketId;
        final subject = ticket['subject']?.toString() ?? 'Untitled ticket';
        final status = ticket['status']?.toString() ?? 'open';
        final priority = ticket['priority']?.toString() ?? 'normal';
        final sla = (ticket['sla'] is Map) ? Map<String, dynamic>.from(ticket['sla'] as Map) : <String, dynamic>{};
        final breached = sla['breached'] == true;
        final remaining = (sla['remainingMinutes'] is num) ? (sla['remainingMinutes'] as num).toInt() : 0;

        return InkWell(
          onTap: () {
            setState(() => _selectedTicketId = id);
            _loadMessages(id);
          },
          child: Container(
            color: selected ? AppColors.primary.withOpacity(0.10) : null,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body2.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _pill(status.toUpperCase(), _statusColor(status)),
                    _pill(priority.toUpperCase(), _priorityColor(priority)),
                    _pill(
                      breached ? 'SLA BREACHED' : 'SLA ${_minutesToHuman(remaining)}',
                      breached ? AppColors.error : AppColors.success,
                    ),
                  ],
                ),
                if (isCompact) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withOpacity(0.8)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationPanel({bool isCompact = false}) {
    final selected = _selectedTicket;
    if (selected == null) {
      return const Center(
        child: Text('Select a ticket to open conversation'),
      );
    }

    final status = selected['status']?.toString() ?? 'open';
    final priority = selected['priority']?.toString() ?? 'normal';
    final sla = (selected['sla'] is Map) ? Map<String, dynamic>.from(selected['sla'] as Map) : <String, dynamic>{};
    final breached = sla['breached'] == true;
    final remaining = (sla['remainingMinutes'] is num) ? (sla['remainingMinutes'] as num).toInt() : 0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: AppSpacing.paddingAll,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isCompact)
                    IconButton(
                      onPressed: () => setState(() {
                        _selectedTicketId = null;
                        _messages = const [];
                      }),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back to tickets',
                    ),
                  Expanded(
                    child: Text(
                      selected['subject']?.toString() ?? 'Ticket',
                      style: AppTypography.subtitle2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(status.toUpperCase(), _statusColor(status)),
                  _pill(priority.toUpperCase(), _priorityColor(priority)),
                  _pill(
                    breached ? 'SLA breached' : 'SLA ${_minutesToHuman(remaining)}',
                    breached ? AppColors.error : AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  if (_isSupportAgent)
                    TextButton.icon(
                      onPressed: () => _showSupportActions(selected),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Support actions'),
                    ),
                  if (!_isSupportAgent && status != 'closed')
                    TextButton.icon(
                      onPressed: _closeTicketAsUser,
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark resolved'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: AppSpacing.paddingLarge,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
        ),
  if (_isSupportAgent) _buildQuickReplies(),
        _buildPendingAttachmentsPreview(),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final authorType = message['authorType']?.toString() ?? 'user';
    final isUser = authorType == 'user';
    final body = message['body']?.toString() ?? '';
    final createdAt = DateTime.tryParse(message['createdAt']?.toString() ?? '') ?? DateTime.now();
    final attachmentsRaw = message['attachments'];
    final attachments = attachmentsRaw is List
        ? attachmentsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: const Icon(
                Icons.support_agent,
                color: AppColors.textPrimary,
                size: 16,
              ),
            ),
          ],

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isUser 
                    ? AppColors.primary 
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large).copyWith(
                  bottomLeft: Radius.circular(isUser ? AppBorderRadius.large : AppBorderRadius.small),
                  bottomRight: Radius.circular(isUser ? AppBorderRadius.small : AppBorderRadius.large),
                ),
                border: isUser 
                    ? null 
                    : Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: AppTypography.body2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: attachments.map((att) {
                        final name = att['name']?.toString() ?? 'attachment';
                        final size = (att['size'] is num) ? (att['size'] as num).toInt() : 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: isUser ? Colors.white.withOpacity(0.2) : AppColors.background,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '$name${size > 0 ? ' • ${_bytesToHuman(size)}' : ''}',
                            style: AppTypography.caption,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: AppSpacing.xs),
                  
                  Text(
                    _formatTimestamp(createdAt),
                    style: AppTypography.caption.copyWith(
                      color: isUser ? AppColors.textPrimary.withOpacity(0.7) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textSecondary.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    if (_macros.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _macros.length,
        itemBuilder: (context, index) {
          final macro = _macros[index];
          final title = macro['title']?.toString() ?? macro['key']?.toString() ?? 'Macro';
          final body = macro['body']?.toString() ?? '';
          final key = macro['key']?.toString();
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(title),
              onSelected: (selected) {
                _messageController.text = body;
                _queuedMacroKey = key;
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary.withOpacity(0.2),
              labelStyle: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
              ),
              side: const BorderSide(color: AppColors.border),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingAttachmentsPreview() {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _pendingAttachments.map((att) {
          final name = att['name']?.toString() ?? 'file';
          final size = (att['size'] is num) ? (att['size'] as num).toInt() : 0;
          return Chip(
            label: Text('$name${size > 0 ? ' • ${_bytesToHuman(size)}' : ''}'),
            onDeleted: () {
              setState(() {
                _pendingAttachments.remove(att);
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageInput() {
    final selected = _selectedTicket;
    final canSend = selected != null && !_sending;

    return Container(
      padding: AppSpacing.paddingLarge,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: canSend ? _pickAttachments : null,
            icon: const Icon(
              Icons.attach_file,
              color: AppColors.textSecondary,
            ),
          ),

          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: canSend,
              style: AppTypography.body2.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: selected == null ? 'Select a ticket first...' : 'Type a message...',
                hintStyle: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: canSend ? _sendMessage : null,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.send,
                      color: AppColors.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  void _sendMessage() {
    final ticketId = _selectedTicketId;
    if (ticketId == null || ticketId.isEmpty) return;
    final token = _token;
    if (token == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    final macroKey = _queuedMacroKey;
    final attachments = List<Map<String, dynamic>>.from(_pendingAttachments);

    setState(() => _sending = true);
    SupportTicketsService.sendMessage(
      token: token,
      ticketId: ticketId,
      body: text.isEmpty ? '[Attachment]' : text,
      macroKey: macroKey,
      attachments: attachments,
    ).then((_) async {
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _pendingAttachments = [];
        _queuedMacroKey = null;
      });
      await _loadTickets();
      await _loadMessages(ticketId);
    }).catchError((_) {
      AppNotifier.showError('Failed to send message');
    }).whenComplete(() {
      if (mounted) setState(() => _sending = false);
    });
  }

  Future<void> _pickAttachments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'mp4', 'mov', 'mkv', 'txt', 'log', 'json'],
      );
      if (result == null || result.files.isEmpty) return;

      final prepared = result.files.map((f) {
        final mimeType = lookupMimeType(f.name) ?? '';
        return <String, dynamic>{
          'name': f.name,
          'mimeType': mimeType,
          'size': f.size,
          'url': '',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _pendingAttachments = [..._pendingAttachments, ...prepared];
      });
    } catch (_) {
      AppNotifier.showError('Unable to pick attachments');
    }
  }

  void _showCreateTicketDialog() {
    final token = _token;
    if (token == null) {
      AppNotifier.showError('Please sign in first');
      return;
    }

    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String priority = 'normal';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Create support ticket'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Describe your issue'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      value: priority,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => priority = v);
                      },
                      decoration: const InputDecoration(labelText: 'Priority'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                CustomButton(
                  text: 'Create',
                  size: ButtonSize.small,
                  onPressed: () async {
                    final subject = subjectCtrl.text.trim();
                    final body = bodyCtrl.text.trim();
                    if (subject.isEmpty || body.isEmpty) {
                      AppNotifier.showError('Please fill subject and description');
                      return;
                    }
                    final res = await SupportTicketsService.createTicket(
                      token: token,
                      subject: subject,
                      body: body,
                      priority: priority,
                    );
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    if (res['success'] == true) {
                      AppNotifier.showSuccess('Ticket created');
                      await _loadTickets();
                    } else {
                      AppNotifier.showError(_friendlySupportError(res['message']?.toString()));
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _closeTicketAsUser() async {
    final ticketId = _selectedTicketId;
    final token = _token;
    if (ticketId == null || token == null) return;
    try {
      await SupportTicketsService.updateTicket(
        token: token,
        ticketId: ticketId,
        status: 'closed',
      );
      AppNotifier.showSuccess('Ticket marked as resolved');
      await _loadTickets();
    } catch (_) {
      AppNotifier.showError('Failed to update ticket');
    }
  }

  void _showSupportActions(Map<String, dynamic> ticket) {
    final ticketId = ticket['_id']?.toString() ?? '';
    if (ticketId.isEmpty) return;
    final token = _token;
    if (token == null) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: const Text('Assign to me'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await SupportTicketsService.assignMe(token: token, ticketId: ticketId);
                  await _loadTickets();
                },
              ),
              ListTile(
                leading: const Icon(Icons.pending_actions),
                title: const Text('Set status: pending'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await SupportTicketsService.updateTicket(token: token, ticketId: ticketId, status: 'pending');
                  await _loadTickets();
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Set status: closed'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await SupportTicketsService.updateTicket(token: token, ticketId: ticketId, status: 'closed');
                  await _loadTickets();
                },
              ),
              ListTile(
                leading: const Icon(Icons.priority_high),
                title: const Text('Set priority: urgent'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await SupportTicketsService.updateTicket(
                    token: token,
                    ticketId: ticketId,
                    status: ticket['status']?.toString() ?? 'open',
                    priority: 'urgent',
                  );
                  await _loadTickets();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final v = status.trim().toLowerCase();
    if (v == 'closed') return AppColors.success;
    if (v == 'pending') return AppColors.warning;
    return AppColors.primary;
  }

  Color _priorityColor(String priority) {
    final v = priority.trim().toLowerCase();
    if (v == 'urgent') return AppColors.error;
    if (v == 'high') return AppColors.warning;
    if (v == 'low') return AppColors.success;
    return AppColors.primary;
  }

  String _minutesToHuman(int minutes) {
    if (minutes <= 0) return '0m';
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h < 24) return m == 0 ? '${h}h' : '${h}h ${m}m';
    final d = h ~/ 24;
    final hr = h % 24;
    return hr == 0 ? '${d}d' : '${d}d ${hr}h';
  }

  String _bytesToHuman(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final n = v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$n ${units[i]}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      try {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } catch (_) {}
    });
  }

  String _friendlySupportError(String? raw) {
    final msg = (raw ?? '').trim();
    if (msg.contains('Cannot POST /api/support/tickets')) {
      return 'Support API موش مفعّل توا (backend قديم). اعمل restart للbackend ومن بعد جرّب مرّة أخرى.';
    }
    if (msg.isEmpty) return 'Failed to create ticket';
    return msg;
  }
}
