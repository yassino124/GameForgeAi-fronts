import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'api_service.dart';

typedef CoachOverlayMsg = ({String role, String text});

class CoachOverlayController extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  io.Socket? _socket;

  String _lang = 'en';
  String get lang => _lang;

  bool _connecting = false;
  bool get connecting => _connecting;

  bool _connected = false;
  bool get connected => _connected;

  bool _listening = false;
  bool get listening => _listening;

  bool _speaking = false;
  bool get speaking => _speaking;

  bool _waitingReply = false;
  bool get waitingReply => _waitingReply;

  bool _overlayEnabled = false;
  bool get overlayEnabled => _overlayEnabled;

  bool _handsFree = false;
  bool get handsFree => _handsFree;

  void showOverlay() {
    if (_overlayEnabled) return;
    _overlayEnabled = true;
    notifyListeners();
  }

  Future<void> hideOverlay() async {
    if (!_overlayEnabled) return;
    _overlayEnabled = false;
    _handsFree = false;
    notifyListeners();
    await stopAllAudio();
  }

  String? _lastToken;
  String? _lastProjectId;

  String _draftUser = '';
  String get draftUser => _draftUser;

  String _draftAssistant = '';
  String get draftAssistant => _draftAssistant;

  final List<CoachOverlayMsg> _messages = [];
  List<CoachOverlayMsg> get messages => List.unmodifiable(_messages);

  Timer? _silenceTimer;

  List<stt.LocaleName>? _locales;

  void setLang(String v) {
    final next = v.trim();
    if (_lang == 'en') {
      notifyListeners();
      return;
    }
    if (next.isEmpty) return;
    _lang = 'en';
    notifyListeners();
  }

  Future<void> _ensureLocales() async {
    if (_locales != null) return;
    try {
      _locales = await _speech.locales();
    } catch (_) {
      _locales = const [];
    }
  }

  String _pickLocaleId() {
    final locs = _locales ?? const <stt.LocaleName>[];

    bool matchPrefix(String id, List<String> prefixes) {
      for (final p in prefixes) {
        if (id.toLowerCase().startsWith(p.toLowerCase())) return true;
      }
      return false;
    }

    final hit = locs.where((l) => matchPrefix(l.localeId, const ['en_', 'en-'])).toList();
    if (hit.isNotEmpty) {
      final us = hit.where((l) => l.localeId.toLowerCase().contains('us')).toList();
      return (us.isNotEmpty ? us.first.localeId : hit.first.localeId);
    }
    return 'en_US';
  }

  Future<void> setHandsFree(bool v, {required String token, String? projectId}) async {
    final next = v;
    if (_handsFree == next) return;

    _handsFree = next;
    _lastToken = token.trim().isEmpty ? _lastToken : token.trim();
    _lastProjectId = (projectId?.trim().isNotEmpty == true) ? projectId!.trim() : _lastProjectId;
    notifyListeners();

    if (!_handsFree) {
      await stopAllAudio();
      return;
    }

    if (_waitingReply || _speaking) return;
    if (_listening) return;
    if ((_lastToken ?? '').trim().isEmpty) return;

    await startPushToTalk(token: _lastToken!, projectId: _lastProjectId);
  }

  Uri _socketBaseUri() {
    final api = Uri.parse(ApiService.baseUrl);
    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
    );
  }

  Future<void> _initTtsIfNeeded() async {
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() {
        _speaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _speaking = false;
        notifyListeners();

        if (_handsFree && !_waitingReply && !_listening) {
          final t = (_lastToken ?? '').trim();
          if (t.isNotEmpty) {
            Future.microtask(() async {
              await startPushToTalk(token: t, projectId: _lastProjectId);
            });
          }
        }
      });
      _tts.setCancelHandler(() {
        _speaking = false;
        notifyListeners();

        if (_handsFree && !_waitingReply && !_listening) {
          final t = (_lastToken ?? '').trim();
          if (t.isNotEmpty) {
            Future.microtask(() async {
              await startPushToTalk(token: t, projectId: _lastProjectId);
            });
          }
        }
      });
    } catch (_) {}
  }

  Future<void> connect({required String token}) async {
    final t = token.trim();
    if (t.isEmpty) return;
    if (_connected || _connecting) return;

    _connecting = true;
    _connected = false;
    notifyListeners();

    await _initTtsIfNeeded();

    _lastToken = t;

    final base = _socketBaseUri();
    final url = base.toString();
    final coachNsUrl = Uri.parse(url).resolve('/coach').toString();

    final socket = io.io(
      coachNsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setPath('/socket.io')
          .setAuth({'token': t})
          .build(),
    );

    socket.onConnect((_) {
      _connecting = false;
      _connected = true;
      notifyListeners();
    });

    socket.onDisconnect((_) {
      _connecting = false;
      _connected = false;
      notifyListeners();
    });

    socket.onConnectError((_) {
      _connecting = false;
      _connected = false;
      notifyListeners();
    });

    socket.on('coach:started', (_) {
      _waitingReply = true;
      _draftAssistant = '';
      notifyListeners();
    });

    socket.on('coach:token', (data) {
      final chunk = (data is Map ? data['t'] : null)?.toString() ?? '';
      if (chunk.isEmpty) return;
      _draftAssistant += chunk;
      notifyListeners();
    });

    socket.on('coach:done', (_) async {
      final text = _draftAssistant.trim();
      _waitingReply = false;
      if (text.isNotEmpty) {
        _messages.add((role: 'assistant', text: text));
      }
      _draftAssistant = '';
      notifyListeners();

      if (text.isNotEmpty) {
        await speak(text);
      }
    });

    socket.on('coach:error', (data) {
      _waitingReply = false;
      _draftAssistant = '';
      notifyListeners();
    });

    _socket = socket;

    try {
      socket.connect();
    } catch (_) {
      _connecting = false;
      _connected = false;
      notifyListeners();
    }
  }

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    try {
      await _tts.stop();
    } catch (_) {}

    try {
      await _tts.setLanguage('en-US');
    } catch (_) {}

    try {
      await _tts.speak(t);
    } catch (_) {}
  }

  Future<void> startPushToTalk({required String token, String? projectId}) async {
    _lastToken = token.trim().isEmpty ? _lastToken : token.trim();
    _lastProjectId = (projectId?.trim().isNotEmpty == true) ? projectId!.trim() : _lastProjectId;
    await _startListening(token: token);
  }

  Future<void> _startListening({required String token}) async {
    if (_waitingReply) return;
    if (_listening) return;
    final available = await _speech.initialize(
      onError: (_) {
        _listening = false;
        notifyListeners();
      },
      onStatus: (s) {
        if (s == 'notListening' || s == 'done') {
          _listening = false;
          notifyListeners();
        }
      },
    );

    if (!available) return;

    await _ensureLocales();

    _silenceTimer?.cancel();

    _draftUser = '';
    _listening = true;
    notifyListeners();

    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}

    final localeId = _pickLocaleId();

    await _speech.listen(
      localeId: localeId,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      onResult: (r) {
        _draftUser = r.recognizedWords;
        notifyListeners();

        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 1200), () {
          stopAndSend(token: token, projectId: _lastProjectId);
        });
      },
    );
  }

  Future<void> stopAndSend({required String token, String? projectId}) async {
    _silenceTimer?.cancel();

    if (!_listening && _draftUser.trim().isEmpty) return;

    try {
      await _speech.stop();
    } catch (_) {}

    _listening = false;

    final text = _draftUser.trim();
    _draftUser = '';

    if (text.isNotEmpty) {
      _messages.add((role: 'user', text: text));
    }

    notifyListeners();

    if (text.isEmpty) return;

    await send(text: text, token: token, projectId: projectId ?? _lastProjectId);
  }

  Future<void> send({required String text, required String token, String? projectId}) async {
    final t = text.trim();
    if (t.isEmpty) return;

    await connect(token: token);

    final socket = _socket;
    if (socket == null || !_connected) return;

    _waitingReply = true;
    _draftAssistant = '';
    notifyListeners();

    socket.emit('coach:start', {
      'token': token.trim(),
      'text': t,
      if (projectId != null && projectId.trim().isNotEmpty) 'projectId': projectId.trim(),
      'locale': 'en',
    });
  }

  String snapshotJson() {
    return jsonEncode({
      'connected': _connected,
      'listening': _listening,
      'speaking': _speaking,
      'waitingReply': _waitingReply,
      'draftUser': _draftUser,
      'draftAssistant': _draftAssistant,
    });
  }

  Future<void> stopAllAudio() async {
    _silenceTimer?.cancel();
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}

    _listening = false;
    _speaking = false;
    notifyListeners();
  }

  Future<void> reset() async {
    await stopAllAudio();

    try {
      _socket?.emit('coach:reset');
    } catch (_) {}

    _messages.clear();
    _draftAssistant = '';
    _draftUser = '';
    _waitingReply = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    try {
      _socket?.dispose();
    } catch (_) {}
    try {
      _speech.stop();
    } catch (_) {}
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }
}
