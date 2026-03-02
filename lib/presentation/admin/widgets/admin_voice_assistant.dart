import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/admin_theme.dart';
import '../providers/admin_provider.dart';

class AdminVoiceAssistant extends StatefulWidget {
  const AdminVoiceAssistant({super.key});

  @override
  State<AdminVoiceAssistant> createState() => _AdminVoiceAssistantState();
}

class _AdminVoiceAssistantState extends State<AdminVoiceAssistant>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  dynamic _recognition;
  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false; // Track TTS playback
  bool _showOverlay = false;
  bool _showLanguageSelection = false;
  bool _hasSelectedLanguage = false;
  bool _hasGreeted = false; // Track if initial greeting was played
  String _status = 'Done';
  String _transcript = '';
  String _interimTranscript = ''; // Real-time interim text
  String _finalTranscript = ''; // Accumulated final text
  Map<String, dynamic>? _response;
  bool _usedLocalFallback = false;
  String _language = 'fr-FR';
  List<double>? _voiceWaveformData;
  String _assistantState = 'idle'; // idle, listening, thinking, speaking, success, error - used for avatar animation
  
  Timer? _autoNavigateTimer;
  Timer? _autoStopTimer; // 4 second timer before processing
  Timer? _silenceTimer; // 6 second silence timer

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _autoNavigateTimer?.cancel();
    _autoStopTimer?.cancel();
    _silenceTimer?.cancel();
    _safeStopRecognition();
    _waveController.dispose();
    _stopSpeaking();
    super.dispose();
  }

  /// Text-to-speech using Web Speech API
  void _speak(String text) {
    try {
      final jsWindow = globalContext;
      final hasSpeech = jsWindow.hasProperty('speechSynthesis'.toJS) as bool;
      if (!hasSpeech) return;

      final synth = jsWindow['speechSynthesis'] as JSObject;
      
      // Cancel any ongoing speech
      synth.callMethod('cancel'.toJS);
      
      // Create utterance
      final utteranceConstructor = jsWindow['SpeechSynthesisUtterance'] as JSFunction;
      final utterance = utteranceConstructor.callAsConstructor(text.toJS) as JSObject;
      
      // Set properties
      utterance.setProperty('rate'.toJS, 0.95.toJS);
      utterance.setProperty('pitch'.toJS, 1.1.toJS);
      utterance.setProperty('volume'.toJS, 1.0.toJS);
      
      // Set language based on current language selection
      if (_language == 'fr-FR') {
        utterance.setProperty('lang'.toJS, 'fr-FR'.toJS);
      } else {
        utterance.setProperty('lang'.toJS, 'en-US'.toJS);
      }
      
      // Track speaking state
      utterance.setProperty(
        'onstart'.toJS,
        (() {
          setState(() => _isSpeaking = true);
        }).toJS,
      );
      
      utterance.setProperty(
        'onend'.toJS,
        (() {
          setState(() => _isSpeaking = false);
        }).toJS,
      );
      
      // Speak
      synth.callMethod('speak'.toJS, utterance);
    } catch (e) {
      // Fail silently if TTS not available
    }
  }

  /// Stop any ongoing speech
  void _stopSpeaking() {
    try {
      final jsWindow = globalContext;
      final hasSpeech = jsWindow.hasProperty('speechSynthesis'.toJS) as bool;
      if (!hasSpeech) return;
      final synth = jsWindow['speechSynthesis'] as JSObject;
      synth.callMethod('cancel'.toJS);
    } catch (e) {
      // Fail silently
    }
  }

  /// Play initial greeting
  void _playGreeting() {
    if (_hasGreeted) return;
    _hasGreeted = true;
    
    List<String> englishGreetings = [
      "Hello! I'm FORGE, your GameForge assistant. How can I help you?",
      "Hey there! FORGE at your service. What do you need?",
      "Ready to assist! What can I do for you?",
    ];
    
    List<String> frenchGreetings = [
      "Bonjour! Je suis FORGE, votre assistant GameForge. Comment puis-je vous aider?",
      "Salut! FORGE à votre service. Qu'avez-vous besoin?",
      "Prêt à vous aider! Que puis-je faire pour vous?",
    ];
    
    final greetings = _language == 'fr-FR' ? frenchGreetings : englishGreetings;
    final greeting = greetings[math.Random().nextInt(greetings.length)];
    
    Future.delayed(const Duration(milliseconds: 300), () {
      _speak(greeting);
    });
  }

  void _toggleAssistant() {
    if (_showOverlay) {
      _closeOverlay();
    } else {
      if (!_hasSelectedLanguage) {
        setState(() {
          _showLanguageSelection = true;
        });
      } else {
        _openOverlayAndListen();
      }
    }
  }

  void _openOverlayAndListen() {
    setState(() {
      _showOverlay = true;
      _response = null;
      _transcript = '';
      _usedLocalFallback = false;
      _status = 'Listening...';
      _assistantState = 'listening';
    });
    
    // Play greeting on first open only
    if (!_hasGreeted) {
      _playGreeting();
    }
    
    // Play listening indicator after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_language == 'fr-FR') {
        _speak("J'écoute...");
      } else {
        _speak("I'm listening...");
      }
    });
    
    _startListening();
  }

  void _closeOverlay() {
    _autoNavigateTimer?.cancel();
    _safeStopRecognition();
    _stopSpeaking();
    _waveController.stop();
    // Clear transcripts when closing
    _finalTranscript = '';
    _interimTranscript = '';
    setState(() {
      _showOverlay = false;
      _isListening = false;
      _isThinking = false;
      _isSpeaking = false;
      _assistantState = 'idle';
      _status = 'Done';
      _transcript = '';
    });
  }

  void _retryListening() {
    // Clear previous transcripts for fresh retry
    _finalTranscript = '';
    _interimTranscript = '';
    // Stop old recognition before starting new one
    _safeStopRecognition();
    _recognition = null; // Clear the old reference
    // Cancel timers
    _autoStopTimer?.cancel();
    _silenceTimer?.cancel();
    setState(() {
      _response = null;
      _transcript = '';
      _usedLocalFallback = false;
      _status = 'Listening...';
      _isListening = false;
      _isThinking = false;
    });
    // Small delay to ensure old recognition is fully stopped
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _startListening();
      }
    });
  }

  void _startListening() {
    if (!kIsWeb) {
      setState(() {
        _status = 'Voice assistant is web-only.';
        _isListening = false;
      });
      return;
    }

    try {
      // Access window global object using dart:js_interop_unsafe
      final jsWindow = globalContext;
      JSObject? recognition;

      // Try webkit first, then standard
      if (jsWindow.has('webkitSpeechRecognition')) {
        final constructor = jsWindow['webkitSpeechRecognition'] as JSFunction;
        recognition = constructor.callAsConstructor() as JSObject?;
      } else if (jsWindow.has('SpeechRecognition')) {
        final constructor = jsWindow['SpeechRecognition'] as JSFunction;
        recognition = constructor.callAsConstructor() as JSObject?;
      }

      if (recognition == null) {
        setState(() {
          _status = 'Speech recognition unavailable in this browser.';
          _isListening = false;
        });
        return;
      }

      _recognition = recognition;

      // Set properties - CONTINUOUS mode allows long recording without auto-stop
      recognition.setProperty('continuous'.toJS, true.toJS);
      recognition.setProperty('interimResults'.toJS, true.toJS);
      recognition.setProperty('lang'.toJS, _language.toJS);

      // Set onresult callback
      recognition.setProperty(
        'onresult'.toJS,
        ((JSObject event) {
          try {
            final results = event.getProperty('results'.toJS) as JSObject?;
            if (results == null) return;

            final resultIndex = event.getProperty('resultIndex'.toJS);
            final idx =
                resultIndex is num ? (resultIndex as num).toInt() : 0;
            final result = results.getProperty(idx.toString().toJS) as JSObject?;
            if (result == null) return;

            final first = result.getProperty('0'.toJS) as JSObject?;
            if (first == null) return;

            final transcriptObj =
                first.getProperty('transcript'.toJS) as JSString?;
            final String transcript =
                transcriptObj?.toDart.trim() ?? '';

            if (!mounted || transcript.isEmpty) return;

            final isFinal = result.getProperty('isFinal'.toJS) == true;
            
            if (isFinal) {
              // Accumulate final transcripts
              _finalTranscript += ' $transcript'.trim();
              
              // Clear interim text when we get final result
              _interimTranscript = '';
              
              // Reset silence timer - restart 4 second wait
              _silenceTimer?.cancel();
              _autoStopTimer?.cancel();
              
              // Show interim transcript while accumulating
              setState(() {
                _transcript = _finalTranscript;
              });
              
              // Start 4 second timer to process after silence
              _autoStopTimer = Timer(const Duration(seconds: 4), () {
                if (!mounted || _finalTranscript.isEmpty) return;
                recognition?.callMethod('stop'.toJS);
                _onFinalTranscript(_finalTranscript);
              });
            } else {
              // Interim results - show real-time as user speaks
              _interimTranscript = transcript;
              setState(() {
                _transcript = (_finalTranscript + ' ' + _interimTranscript).trim();
              });
              
              // Reset silence timer on interim result
              _silenceTimer?.cancel();
              _silenceTimer = Timer(const Duration(seconds: 6), () {
                // No speech detected for 6 seconds
                if (!mounted || !_isListening) return;
                _speak("I didn't hear anything. Tap the mic to try again.");
                _closeOverlay();
              });
            }
          } catch (e) {
            // Ignore browser-specific parsing issues
          }
        }).toJS,
      );

      // Set onerror callback
      recognition.setProperty(
        'onerror'.toJS,
        ((JSObject event) {
          try {
            final errorObj = event.getProperty('error'.toJS) as JSString?;
            final String errorText = errorObj?.toDart ?? 'unknown';
            if (!mounted) return;

            if (errorText.contains('no-speech')) {
              // Retry with other language if no speech detected
              final nextLang = _language == 'fr-FR' ? 'en-US' : 'fr-FR';
              try {
                recognition?.setProperty('lang'.toJS, nextLang.toJS);
                recognition?.callMethod('start'.toJS);
                setState(() => _language = nextLang);
                return;
              } catch (_) {}
            }

            setState(() {
              _isListening = false;
              _isThinking = false;
              _status = 'Mic error: $errorText';
            });
            _waveController.stop();
          } catch (_) {}
        }).toJS,
      );

      // Set onend callback
      recognition.setProperty(
        'onend'.toJS,
        (() {
          if (!mounted || _isThinking) return;
          setState(() {
            _isListening = false;
            _status = 'Done';
          });
          _waveController.stop();
        }).toJS,
      );

      // Start listening
      recognition.callMethod('start'.toJS);
      setState(() {
        _isListening = true;
        _status = 'Listening...';
      });
      _waveController.repeat();
    } catch (e) {
      setState(() {
        _status = 'Failed to initialize microphone: ${e.toString()}';
        _isListening = false;
      });
      _waveController.stop();
    }
  }

  void _safeStopRecognition() {
    try {
      _recognition?.stop();
    } catch (_) {}
  }

  Future<void> _onFinalTranscript(String query) async {
    if (!mounted) return;

    setState(() {
      _isListening = false;
      _isThinking = true;
      _assistantState = 'thinking';
      _status = 'Thinking...';
      _response = null;
    });
    _waveController.stop();

    // Speak thinking indicator
    if (_language == 'fr-FR') {
      _speak("Un moment...");
    } else {
      _speak("One moment...");
    }

    final provider = context.read<AdminProvider>();
    final remoteData = await provider.aiSearch(query);
    final data = remoteData ?? _buildLocalFallbackResponse(query);

    if (!mounted) return;

    setState(() {
      _isThinking = false;
      _usedLocalFallback = remoteData == null;
      _status = remoteData == null ? 'Done (local mode)' : 'Done';
      _response = data;
    });

    // Get FORGE's voice response
    final speakText = data['speak']?.toString() ?? data['answer']?.toString() ?? 'Done!';
    final action = data['action']?.toString() ?? 'none';
    final target = data['target']?.toString();
    final confidence = double.tryParse(data['confidence']?.toString() ?? '0') ?? 0;
    
    // STRICT CHECKS - Never navigate on low confidence or missing target
    final canNavigate = action == 'navigate' && target != null && target.isNotEmpty && confidence >= 0.6;
    
    if (canNavigate) {
      // High confidence navigation
      setState(() {
        _assistantState = 'success';
      });
      _speak(speakText);
      
      // Auto-navigate after showing response
      _autoNavigateTimer?.cancel();
      _autoNavigateTimer = Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        _applyActionAndNavigate(data);
        // Clear transcripts after navigation
        _finalTranscript = '';
        _interimTranscript = '';
      });
    } else {
      // No valid action OR low confidence - stay on page and show helpful message
      setState(() {
        _assistantState = 'error';
      });
      _speak(speakText);
      // Clear transcripts for retry
      _finalTranscript = '';
      _interimTranscript = '';
    }
  }

  Map<String, dynamic> _buildLocalFallbackResponse(String query) {
    final lower = query.toLowerCase();
    String target = 'overview';
    String action = 'navigate';
    Map<String, dynamic>? filters;
    String answer = 'I can help with admin navigation. Redirecting now.';
    String speak = answer;

    final isBuild = lower.contains('build') || lower.contains('pipeline');
    final isFailed = lower.contains('failed') ||
        lower.contains('error') ||
        lower.contains('failing') ||
        lower.contains('échoué');
    final isUser = lower.contains('user') || lower.contains('users') || lower.contains('utilisateur');
    final isTemplate =
        lower.contains('template') || lower.contains('templates') || lower.contains('marketplace');
    final isProject = lower.contains('project') || lower.contains('projects') || lower.contains('game');
    final isNotification =
        lower.contains('notification') || lower.contains('notifications') || lower.contains('alert');

    if (isBuild) {
      target = 'builds';
      if (isFailed) {
        filters = {'status': 'failed'};
        answer = 'Opening failed builds now.';
        speak = _language == 'fr-FR' ? 'Affichage des builds échoués.' : 'Opening failed builds.';
      } else {
        answer = 'Opening builds now.';
        speak = _language == 'fr-FR' ? 'Affichage des builds.' : 'Opening builds.';
      }
    } else if (isUser) {
      target = 'users';
      answer = 'Opening users now.';
      speak = _language == 'fr-FR' ? 'Affichage des utilisateurs.' : 'Opening users.';
    } else if (isTemplate) {
      target = 'templates';
      answer = 'Opening templates now.';
      speak = _language == 'fr-FR' ? 'Affichage des modèles.' : 'Opening templates.';
    } else if (isProject) {
      target = 'games';
      answer = 'Opening projects now.';
      speak = _language == 'fr-FR' ? 'Affichage des projets.' : 'Opening projects.';
    } else if (isNotification) {
      target = 'notifications';
      answer = 'Opening notifications now.';
      speak = _language == 'fr-FR' ? 'Affichage des notifications.' : 'Opening notifications.';
    } else if (lower.contains('overview') || lower.contains('dashboard') || lower.contains('stats')) {
      target = 'overview';
      answer = 'Opening dashboard overview now.';
      speak = _language == 'fr-FR' ? 'Affichage du tableau de bord.' : 'Opening dashboard.';
    } else {
      // No matching command - provide helpful, friendly suggestions
      action = 'none';
      final notFoundMessages = _language == 'fr-FR' ? [
        'Je n\'ai pas compris cette commande. Essayez "afficher les utilisateurs".',
        'Désolé, je ne reconnais pas ça. Dites "ouvrir les modèles".',
        'Je n\'ai pas saisi. Vous pouvez dire "voir les builds échoués".',
      ] : [
        'I didn\'t understand that command. Try "show users".',
        'Sorry, I don\'t recognize that. Say "open templates".',
        'I didn\'t catch that. You can say "show failed builds".',
      ];
      speak = notFoundMessages[query.hashCode % notFoundMessages.length];
      answer = speak;
    }

    return {
      'answer': answer,
      'action': action,
      'target': target,
      'filters': filters,
      'speak': speak,
      'confidence': action == 'none' ? 0.0 : 0.85, // High confidence for matched commands
      'data': {
        'counts': {},
        'relevantItems': [],
      },
    };
  }

  void _applyActionAndNavigate(Map<String, dynamic>? data) {
    if (data == null) return;
    final String? target = data['target']?.toString();
    if (target == null || target.isEmpty) return;

    final Map<String, dynamic>? filters = data['filters'] is Map<String, dynamic>
        ? data['filters'] as Map<String, dynamic>
        : null;

    final provider = context.read<AdminProvider>();
    final String? statusFilter = filters?['status']?.toString();
    final String? searchFilter = filters?['search']?.toString();

    // Clear all filters first to prevent persistence
    provider.setBuildsStatusFilter('all');
    provider.setUsersSearch('');

    // Apply new filters only if present
    if (statusFilter != null && statusFilter.isNotEmpty) {
      provider.setBuildsStatusFilter(statusFilter);
    }
    if (searchFilter != null && searchFilter.isNotEmpty) {
      provider.setUsersSearch(searchFilter);
    }

    final route = _routeForTarget(target);
    if (route.isNotEmpty) {
      context.go(route);
      // Defer overlay close to allow navigation to complete
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _closeOverlay();
        }
      });
    }
  }

  String _routeForTarget(String target) {
    switch (target) {
      case 'overview':
        return '/admin/overview';
      case 'users':
        return '/admin/users';
      case 'games':
        return '/admin/projects';
      case 'templates':
        return '/admin/marketplace';
      case 'builds':
        return '/admin/builds';
      case 'notifications':
        return '/admin/notifications';
      default:
        return '';
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Show language selection first
    if (_showLanguageSelection && !_isListening && !_isThinking) {
      return _buildLanguageSelectionOverlay();
    }

    return Stack(
      children: [
        if (_showOverlay) _buildOverlay(context),
        Positioned(
          right: 24,
          bottom: 24,
          child: _buildGameForgeBotButton(),
        ),
      ],
    );
  }

  Widget _buildLanguageSelectionOverlay() {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: () {
            setState(() => _showLanguageSelection = false);
          },
          child: Container(
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
        // Language selection dialog
        Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AdminTheme.bgTertiary,
              border: Border.all(
                color: AdminTheme.accentNeon.withValues(alpha: 0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AdminTheme.accentNeon.withValues(alpha: 0.2),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Language',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AdminTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                // French button
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _language = 'fr-FR';
                        _showLanguageSelection = false;
                        _hasSelectedLanguage = true;
                      });
                      _openOverlayAndListen();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.accentNeon,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🇫🇷', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text(
                          'Français',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // English button
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _language = 'en-US';
                        _showLanguageSelection = false;
                        _hasSelectedLanguage = true;
                      });
                      _openOverlayAndListen();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.accentNeon,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Text(
                          'English',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
      ],
    );
  }

  /// Custom GameForge Bot Button - with attention-catching popping/rolling animations
  Widget _buildGameForgeBotButton() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final progress = _waveController.value;
        
        // Popping/bouncing idle animation
        final idlePop = 1.0 + (math.sin(progress * math.pi) * 0.15); // More pronounced pop
        final idleFloat = math.sin(progress * 2 * math.pi) * 5;
        
        // Rolling rotation animation
        final rollRotation = progress * 4 * math.pi; // Full rotations
        
        // Active state animations (when listening/thinking)
        final activeFloat = _isListening || _isThinking
            ? math.sin(progress * 3 * math.pi) * 6
            : 0;
        final activePulse = _isListening || _isThinking
            ? (0.85 + math.sin(progress * 3 * math.pi) * 0.15)
            : 1.0;

        final totalFloat = idleFloat + activeFloat;
        final totalScale = (_isListening || _isThinking) ? activePulse : idlePop;
        final totalRotation = (_isListening || _isThinking) ? 0.0 : rollRotation;

        return Transform.translate(
          offset: Offset(0, totalFloat),
          child: Transform.scale(
            scale: totalScale,
            child: Transform.rotate(
              angle: totalRotation,
              child: GestureDetector(
                onTap: _toggleAssistant,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AdminTheme.accentNeon.withValues(alpha: 0.9),
                        const Color(0xFF00D9FF).withValues(alpha: 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.accentNeon.withValues(
                          alpha: (_isListening || _isThinking) ? 0.8 : 0.5,
                        ),
                        blurRadius: (_isListening || _isThinking) ? 30 : 18,
                        spreadRadius: (_isListening || _isThinking) ? 6 : 3,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated outer ring when active
                      if (_isListening || _isThinking)
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: CustomPaint(
                            painter: _BotGlowPainter(
                              progress: progress,
                              color: AdminTheme.accentNeon,
                            ),
                          ),
                        ),

                      // Bot Head
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF0A1F3C),
                              const Color(0xFF051428),
                            ],
                          ),
                          border: Border.all(
                            color: AdminTheme.accentNeon.withValues(
                              alpha: (_isListening || _isThinking) ? 1.0 : 0.8,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Eyes with glow animation
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AdminTheme.accentNeon,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AdminTheme.accentNeon.withValues(
                                          alpha: _isListening || _isThinking
                                              ? (0.5 + math.sin(progress * 4 * math.pi) * 0.5)
                                              : 0.8,
                                        ),
                                        blurRadius: 6,
                                        spreadRadius: _isListening || _isThinking ? 2 : 0,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AdminTheme.accentNeon,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AdminTheme.accentNeon.withValues(
                                          alpha: _isListening || _isThinking
                                              ? (0.5 + math.sin(progress * 4 * math.pi + 0.5) * 0.5)
                                              : 0.8,
                                        ),
                                        blurRadius: 6,
                                        spreadRadius: _isListening || _isThinking ? 2 : 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Mouth animation
                            if (_isListening)
                              SizedBox(
                                width: 16,
                                height: 4,
                                child: CustomPaint(
                                  painter: _MouthListeningPainter(progress: progress),
                                ),
                              )
                            else if (_isThinking)
                              Container(
                                width: 10 + (math.sin(progress * 3 * math.pi) * 4),
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AdminTheme.accentNeon,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              )
                            else
                              Container(
                                width: 10,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AdminTheme.accentNeon.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(1),
                                ),
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
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final action = _response?['action']?.toString();
    final hasAction = action == 'navigate';
    final String targetLabel = _targetLabel(_response?['target']?.toString());
    final String bubbleText = _isThinking
        ? 'Thinking...'
        : _isListening
            ? 'I am listening'
            : (_response?['answer']?.toString().isNotEmpty == true
                ? _response!['answer'].toString()
                : 'Hello!');

    return Positioned.fill(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _closeOverlay();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _closeOverlay,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.15),
                radius: 1.1,
                colors: [
                  const Color(0xFF0A2A62).withValues(alpha: 0.7),
                  const Color(0xFF071637).withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.95),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: const BoxConstraints(maxWidth: 760),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHologramAvatar(),
                    const SizedBox(height: 14),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF173A75).withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminTheme.accentNeon.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        bubbleText,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildWaveform(),
                    const SizedBox(height: 14),
                    // Separated transcript display
                    if (_transcript.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1E3F).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AdminTheme.accentNeon.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show final transcript (user's words)
                            if (_finalTranscript.isNotEmpty) ...[
                              RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'You: ',
                                      style: TextStyle(
                                        color: AdminTheme.accentNeon,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _finalTranscript,
                                      style: const TextStyle(
                                        color: AdminTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Show interim transcript (real-time, faded)
                            if (_interimTranscript.isNotEmpty) ...[
                              if (_finalTranscript.isNotEmpty)
                                const SizedBox(height: 6),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'You (typing): ',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextSpan(
                                      text: _interimTranscript,
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      Text(
                        'Say something...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AdminTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _language == 'fr-FR'
                                ? AdminTheme.accentNeon.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _language == 'fr-FR'
                                  ? AdminTheme.accentNeon
                                  : AdminTheme.borderGlow,
                            ),
                          ),
                          child: TextButton(
                            onPressed: !_isListening
                                ? () => setState(() => _language = 'fr-FR')
                                : null,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AdminTheme.textPrimary,
                            ),
                            child: const Text('🇫🇷 FR'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _language == 'en-US'
                                ? AdminTheme.accentNeon.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _language == 'en-US'
                                  ? AdminTheme.accentNeon
                                  : AdminTheme.borderGlow,
                            ),
                          ),
                          child: TextButton(
                            onPressed: !_isListening
                                ? () => setState(() => _language = 'en-US')
                                : null,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AdminTheme.textPrimary,
                            ),
                            child: const Text('🇬🇧 EN'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _isThinking ? AdminTheme.accentPurple : AdminTheme.accentNeon,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_usedLocalFallback) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Cloud AI unavailable: using local smart commands.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_response != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AdminTheme.bgTertiary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminTheme.borderGlow),
                        ),
                        child: Text(
                          _response?['answer']?.toString() ?? '',
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Retry button
                          ElevatedButton.icon(
                            onPressed: !_isListening && !_isThinking ? _retryListening : null,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.bgTertiary,
                              foregroundColor: AdminTheme.accentNeon,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: AdminTheme.accentNeon.withValues(alpha: 0.5)),
                              ),
                            ),
                          ),
                          // Navigate button (if action available)
                          if (hasAction)
                            ElevatedButton.icon(
                              onPressed: () => _applyActionAndNavigate(_response),
                              icon: const Icon(Icons.arrow_forward, size: 20),
                              label: Text('Go to $targetLabel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminTheme.accentNeon,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _targetLabel(String? target) {
    switch (target) {
      case 'overview':
        return 'Overview';
      case 'users':
        return 'Users';
      case 'games':
        return 'Games';
      case 'templates':
        return 'Templates';
      case 'builds':
        return 'Builds';
      case 'notifications':
        return 'Notifications';
      default:
        return 'Section';
    }
  }

  Widget _buildWaveform() {
    return SizedBox(
      width: 240,
      height: 100,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return CustomPaint(
            painter: RealisticWaveformPainter(
              progress: _waveController.value,
              isActive: _isListening || _isThinking,
              accentColor: AdminTheme.accentNeon,
              waveformData: _voiceWaveformData,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHologramAvatar() {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          final double pulse = (_isListening || _isThinking)
              ? (0.92 + (math.sin(_waveController.value * 2 * math.pi) * 0.08))
              : 1;

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 182,
                  height: 182,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AdminTheme.accentNeon.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.accentNeon.withValues(alpha: 0.28),
                        blurRadius: 28,
                        spreadRadius: 6,
                      ),
                    ],
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2EE8FF).withValues(alpha: 0.26),
                        const Color(0xFF12306D).withValues(alpha: 0.36),
                        const Color(0xFF071130).withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),
              const Icon(
                Icons.smart_toy_rounded,
                size: 88,
                color: Color(0xFF79F9FF),
              ),
              Positioned(
                bottom: 14,
                child: Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AdminTheme.accentNeon.withValues(alpha: 0.7),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.accentNeon.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final bool isActive;
  final Color accentColor;

  WaveformPainter({
    required this.progress,
    required this.isActive,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) {
      // Draw static ondulation when inactive
      _drawStaticWave(canvas, size);
      return;
    }

    // Draw animated ondulations when active
    _drawAnimatedWaves(canvas, size);
  }

  void _drawStaticWave(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    final double centerY = size.height / 2;
    const double amplitude = 6;
    const double frequency = 0.08;

    path.moveTo(0, centerY);
    for (double x = 0; x <= size.width; x += 2) {
      final double y = centerY + math.sin(x * frequency) * amplitude;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  void _drawAnimatedWaves(Canvas canvas, Size size) {
    final List<Color> colors = [
      accentColor.withValues(alpha: 0.8),
      accentColor.withValues(alpha: 0.6),
      accentColor.withValues(alpha: 0.4),
      accentColor.withValues(alpha: 0.25),
    ];

    // Draw multiple layered waves for ondulation effect
    for (int layer = 0; layer < 4; layer++) {
      _drawWaveLayer(
        canvas,
        size,
        colors[layer],
        layer.toDouble(),
        progress,
      );
    }

    // Draw center peak indicators
    _drawPeakIndicators(canvas, size);
  }

  void _drawWaveLayer(
    Canvas canvas,
    Size size,
    Color color,
    double layer,
    double time,
  ) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.8 + (layer * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    final double centerY = size.height / 2;
    final double amplitude = 8 + (layer * 2);
    final double frequency = 0.065 - (layer * 0.008);
    final double phase = layer * math.pi / 2 + (time * 4 * math.pi);

    path.moveTo(0, centerY);

    for (double x = 0; x <= size.width; x += 1.5) {
      final double waveValue =
          math.sin((x * frequency) + phase + (time * 3 * math.pi)) * amplitude;
      final double y = centerY + waveValue;
      path.lineTo(x, y.clamp(0, size.height));
    }

    canvas.drawPath(path, paint);
  }

  void _drawPeakIndicators(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final int peakCount = 5;
    final double spacing = size.width / (peakCount - 1);

    for (int i = 0; i < peakCount; i++) {
      final double x = i * spacing;
      final double phase = i * (math.pi / peakCount) + (progress * 6 * math.pi);
      final double peakHeight = 12 + (math.sin(phase).abs() * 8);

      // Draw vertical lines with ondulation
      final Path peakPath = Path();
      peakPath.moveTo(x, centerY - peakHeight);
      peakPath.lineTo(x, centerY + peakHeight);

      final Paint gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withValues(alpha: 0.9),
            accentColor.withValues(alpha: 0.3),
          ],
        ).createShader(
          Rect.fromLTWH(x - 1, centerY - peakHeight, 2, peakHeight * 2),
        )
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(peakPath, gradientPaint);

      // Draw glow effect
      final Paint glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);

      canvas.drawCircle(Offset(x, centerY), peakHeight * 0.6, glowPaint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isActive != isActive ||
        oldDelegate.accentColor != accentColor;
  }
}

class RealisticWaveformPainter extends CustomPainter {
  final double progress;
  final bool isActive;
  final Color accentColor;
  final List<double>? waveformData;

  RealisticWaveformPainter({
    required this.progress,
    required this.isActive,
    required this.accentColor,
    this.waveformData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) {
      _drawStaticWave(canvas, size);
      return;
    }
    _drawRealisticVoiceWave(canvas, size);
  }

  void _drawStaticWave(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = accentColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    final double centerY = size.height / 2;

    path.moveTo(0, centerY);
    for (double x = 0; x <= size.width; x += 3) {
      final double y = centerY + math.sin(x * 0.05) * 8;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  void _drawRealisticVoiceWave(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double pixelWidth = size.width / 100; // 100 samples across width

    // Generate natural voice-like waveform with varying amplitudes
    final List<double> amplitudes = List.generate(100, (i) {
      final double baseFreq = 0.04;
      final double timeOffset = progress * 6 * math.pi;

      // Multiple harmonic components for realistic voice
      final double fundamental =
          math.sin(i * baseFreq + timeOffset) * (0.4 + 0.3 * math.sin(timeOffset));
      final double harmonic1 =
          math.sin(i * baseFreq * 2 + timeOffset * 1.5) * 0.2;
      final double harmonic2 =
          math.sin(i * baseFreq * 3 + timeOffset * 2) * 0.1;

      // Add some randomness for organic feel
      final double randomNoise = (math.sin(i * 0.3 + timeOffset * 3) * 0.15);

      return (fundamental + harmonic1 + harmonic2 + randomNoise).clamp(-1, 1);
    });

    // Draw multiple wave layers with different opacities
    for (int layer = 0; layer < 3; layer++) {
      _drawWaveLayer(canvas, size, amplitudes, pixelWidth, layer, centerY);
    }

    // Draw frequency bars for audio spectrum effect
    _drawFrequencyBars(canvas, size, centerY, amplitudes);
  }

  void _drawWaveLayer(
    Canvas canvas,
    Size size,
    List<double> amplitudes,
    double pixelWidth,
    int layer,
    double centerY,
  ) {
    final Paint paint = Paint()
      ..color = accentColor.withValues(alpha: 0.7 - (layer * 0.25))
      ..strokeWidth = 1.5 - (layer * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();
    final double layerOffset = layer * 2.5;

    path.moveTo(0, centerY);
    for (int i = 0; i < amplitudes.length; i++) {
      final double x = i * pixelWidth;
      final double amplitude = amplitudes[i] * (35 - layerOffset);
      final double y = centerY + amplitude;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawFrequencyBars(Canvas canvas, Size size, double centerY,
      List<double> amplitudes) {
    final int barCount = 12;
    final double barWidth = size.width / barCount * 0.8;
    final double spacing = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final int sampleIndex =
          ((i / barCount) * amplitudes.length).toInt().clamp(0, 99);
      final double amplitude = amplitudes[sampleIndex].abs();
      final double barHeight = amplitude * 40;

      final double x = (i * spacing) + (spacing - barWidth) / 2;

      // Gradient bar
      final Paint barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            accentColor.withValues(alpha: 0.85),
            accentColor.withValues(alpha: 0.4),
          ],
        ).createShader(
          Rect.fromLTWH(x, centerY - barHeight, barWidth, barHeight * 2),
        );

      // Draw top bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - barHeight, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        barPaint,
      );

      // Draw bottom bar (mirrored)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        barPaint,
      );

      // Glow effect
      final Paint glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, centerY - barHeight - 2, barWidth + 4,
              barHeight * 2 + 4),
          Radius.circular(barWidth / 2 + 2),
        ),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(RealisticWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isActive != isActive ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.waveformData != waveformData;
  }
}

/// Custom painter for bot glow ring animation
class _BotGlowPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BotGlowPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double baseRadius = size.width / 2;

    // Draw animated glow rings
    for (int ring = 1; ring <= 3; ring++) {
      final double opacity = (1.0 - ((progress * 3 + ring) % 3) / 3).clamp(0.0, 1.0);
      final double radius = baseRadius + (ring * 6);

      final Paint paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    }

    // Draw pulsing dots
    const int dotCount = 8;
    for (int i = 0; i < dotCount; i++) {
      final double angle = (i / dotCount) * 2 * math.pi + (progress * 4 * math.pi);
      final double distance = baseRadius + 8;
      final double x = centerX + math.cos(angle) * distance;
      final double y = centerY + math.sin(angle) * distance;

      final double dotOpacity = (0.5 + math.sin(progress * 2 * math.pi + i) * 0.5).clamp(0.0, 1.0);

      final Paint dotPaint = Paint()
        ..color = color.withValues(alpha: dotOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Mouth listening animation painter
class _MouthListeningPainter extends CustomPainter {
  final double progress;

  _MouthListeningPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF2EE8FF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Draw oscillating mouth pattern (like sound waves)
    const int bars = 5;
    final double barWidth = size.width / bars;

    for (int i = 0; i < bars; i++) {
      final double x = (i * barWidth) + (barWidth / 2);
      final double amplitude = 2 + math.sin(progress * 3 * math.pi + i) * 1.5;

      canvas.drawLine(
        Offset(x, size.height / 2 - amplitude),
        Offset(x, size.height / 2 + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

