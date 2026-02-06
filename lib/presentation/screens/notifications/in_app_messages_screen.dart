import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import '../../presentation/widgets/widgets.dart';

class InAppMessagesScreen extends StatefulWidget {
  const InAppMessagesScreen({super.key});

  @override
  State<InAppMessagesScreen> createState() => _InAppMessagesScreenState();
}

class _InAppMessagesScreenState extends State<InAppMessagesScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Message> _messages = [
    Message(
      id: '1',
      text: 'Welcome to GameForge AI! How can I help you today?',
      sender: MessageSender.support,
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    Message(
      id: '2',
      text: 'I need help with generating my first game',
      sender: MessageSender.user,
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    Message(
      id: '3',
      text: 'I\'d be happy to help! To generate your first game, start by selecting a template from the marketplace. You can choose from various categories like Action, Puzzle, RPG, etc. Once you\'ve selected a template, you can customize the project details and configure AI settings before generation.',
      sender: MessageSender.support,
      timestamp: DateTime.now().subtract(const Duration(minutes: 7)),
    ),
    Message(
      id: '4',
      text: 'That sounds great! What AI models do you recommend?',
      sender: MessageSender.user,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Message(
      id: '5',
      text: 'For beginners, I recommend starting with GPT-3.5 as it\'s faster and more cost-effective. As you become more experienced, you can upgrade to GPT-4 for more advanced features and better game generation quality. The creativity level slider also helps control how innovative the generated content will be.',
      sender: MessageSender.support,
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
  ];

  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: const Icon(
                Icons.support_agent,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
            
            const SizedBox(width: AppSpacing.md),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GameForge Support',
                  style: AppTypography.subtitle2,
                ),
                
                Text(
                  'Usually responds instantly',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Show chat options
            },
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: AppSpacing.paddingLarge,
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          
          // Quick reply suggestions
          _buildQuickReplies(),
          
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.sender == MessageSender.user;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Support avatar
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
          
          // Message bubble
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
                    message.text,
                    style: AppTypography.body2.copyWith(
                      color: isUser 
                          ? AppColors.textPrimary 
                          : AppColors.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xs),
                  
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: AppTypography.caption.copyWith(
                      color: isUser 
                          ? AppColors.textPrimary.withOpacity(0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isUser) ...[
            // User avatar
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

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Support avatar
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
          
          // Typing bubble
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large).copyWith(
                bottomRight: const Radius.circular(AppBorderRadius.small),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.5 + 0.5 * (value + index * 0.3) % 1.0,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickReplies() {
    final quickReplies = [
      'How do I create a game?',
      'What templates are available?',
      'Pricing and plans',
      'Technical support',
    ];
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: quickReplies.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(quickReplies[index]),
              onSelected: (selected) {
                _messageController.text = quickReplies[index];
                _sendMessage();
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

  Widget _buildMessageInput() {
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
          // Attachment button
          IconButton(
            onPressed: () {
              // TODO: Implement attachment
            },
            icon: const Icon(
              Icons.attach_file,
              color: AppColors.textSecondary,
            ),
          ),
          
          // Message input field
          Expanded(
            child: TextField(
              controller: _messageController,
              style: AppTypography.body2.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type a message...',
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
          
          // Send button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(
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
    final text = _messageController.text.trim();
    
    if (text.isEmpty) return;
    
    setState(() {
      _messages.add(Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
      
      _isTyping = true;
      _messageController.clear();
    });
    
    // Scroll to bottom
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    
    // Simulate support response
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(Message(
            id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
            text: _generateSupportResponse(text),
            sender: MessageSender.support,
            timestamp: DateTime.now(),
          ));
        });
        
        // Scroll to bottom again
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _generateSupportResponse(String userMessage) {
    // Simple response generation based on keywords
    if (userMessage.toLowerCase().contains('template')) {
      return 'We have a wide variety of templates available! You can browse them in the marketplace. Categories include Action, Puzzle, RPG, Strategy, Casual, and more. Each template comes with pre-built mechanics and assets that you can customize.';
    } else if (userMessage.toLowerCase().contains('pricing') || userMessage.toLowerCase().contains('cost')) {
      return 'We offer three plans: Free (3 generations/month), Pro (\$9.99/month for unlimited), and Enterprise (custom pricing for teams). The Pro plan gives you access to all features and priority support!';
    } else if (userMessage.toLowerCase().contains('help') || userMessage.toLowerCase().contains('support')) {
      return 'I\'m here to help! You can ask me anything about game creation, templates, AI settings, building, or any other GameForge AI features. What specific aspect would you like to know more about?';
    } else {
      return 'Thanks for your message! I\'m here to help with any questions about GameForge AI. Feel free to ask about templates, game generation, building, or any other features you\'re curious about.';
    }
  }
}

class Message {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
  });
}

enum MessageSender {
  user,
  support,
}
