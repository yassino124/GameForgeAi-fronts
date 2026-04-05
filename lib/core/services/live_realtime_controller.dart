import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';
import 'package:gamefrogai/core/services/voice_webrtc_controller.dart';

typedef LiveChatMessage = ({
  String id,
  String liveId,
  String userId,
  String username,
  String text,
  int ts,
});

typedef LiveGiftEvent = ({
  String id,
  String liveId,
  String fromUserId,
  String fromUsername,
  String giftName,
  int amount,
  int ts,
});

class LiveRealtimeController extends ChangeNotifier {
  io.Socket? _socket;

  bool _connecting = false;
  bool get connecting => _connecting;

  bool _connected = false;
  bool get connected => _connected;

  String? _error;
  String? get error => _error;

  String? _liveId;
  String? get liveId => _liveId;

  int _viewers = 0;
  int get viewers => _viewers;

  final List<LiveChatMessage> _messages = [];
  List<LiveChatMessage> get messages => List.unmodifiable(_messages);

  final List<LiveGiftEvent> _gifts = [];
  List<LiveGiftEvent> get gifts => List.unmodifiable(_gifts);

  io.Socket? get socket => _socket;

  Uri _socketBaseUri() {
    final api = Uri.parse(ApiService.baseUrl);
    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
    );
  }

  void sendGift({
    required String token,
    required String giftName,
    required int amount,
  }) {
    final t = token.trim();
    final lid = (_liveId ?? '').trim();
    final s = _socket;
    if (t.isEmpty || lid.isEmpty || s == null || !_connected) return;
    final g = giftName.trim();
    if (g.isEmpty) return;

    s.emit('live:gift:send', {
      'token': t,
      'liveId': lid,
      'giftName': g,
      'amount': amount,
    });
  }

  String _liveNamespaceUrl() {
    final base = _socketBaseUri().toString();
    return Uri.parse(base).resolve('/live').toString();
  }

  Future<void> connectAndJoin({
    required String token,
    required String liveId,
  }) async {
    final t = token.trim();
    final lid = liveId.trim();
    if (t.isEmpty || lid.isEmpty) return;

    if (_connected || _connecting) return;

    _connecting = true;
    _connected = false;
    _error = null;
    _liveId = lid;
    notifyListeners();

    final socket = io.io(
      _liveNamespaceUrl(),
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setPath('/socket.io')
          .setAuth({'token': t})
          .build(),
    );

    socket.onConnect((_) {
      _connecting = false;
      _connected = true;
      _error = null;
      notifyListeners();

      socket.emit('live:join', {
        'token': t,
        'liveId': lid,
      });
    });

    socket.onDisconnect((_) {
      _connecting = false;
      _connected = false;
      notifyListeners();
    });

    socket.onConnectError((_) {
      _connecting = false;
      _connected = false;
      _error = 'Connection failed';
      notifyListeners();
    });

    socket.on('live:error', (data) {
      final msg = (data is Map ? data['message'] : null)?.toString();
      if (msg != null && msg.trim().isNotEmpty) {
        _error = msg;
        notifyListeners();
      }
    });

    socket.on('live:viewers', (data) {
      final d = (data is Map ? data['data'] : null);
      if (d is Map) {
        final v = d['viewers'];
        final n = (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '');
        if (n != null) {
          _viewers = n;
          notifyListeners();
        }
      }
    });

    socket.on('live:chat:new', (data) {
      final d = (data is Map ? data['data'] : null);
      if (d is Map) {
        final m = d['message'];
        if (m is Map) {
          final msg = (
            id: (m['id'] ?? '').toString(),
            liveId: (m['liveId'] ?? '').toString(),
            userId: (m['userId'] ?? '').toString(),
            username: (m['username'] ?? '').toString(),
            text: (m['text'] ?? '').toString(),
            ts: (m['ts'] is num) ? (m['ts'] as num).toInt() : (int.tryParse(m['ts']?.toString() ?? '') ?? 0),
          );
          if (msg.id.trim().isNotEmpty) {
            _messages.add(msg);
            if (_messages.length > 150) {
              _messages.removeRange(0, _messages.length - 150);
            }
            notifyListeners();
          }
        }
      }
    });

    socket.on('live:gift:new', (data) {
      final d = (data is Map ? data['data'] : null);
      if (d is Map) {
        final g = d['gift'];
        if (g is Map) {
          final id = (g['id'] ?? g['_id'] ?? '').toString();
          if (id.trim().isEmpty) return;
          if (_gifts.any((e) => e.id == id)) return;

          final evt = (
            id: id,
            liveId: (g['liveId'] ?? '').toString(),
            fromUserId: (g['fromUserId'] ?? g['userId'] ?? '').toString(),
            fromUsername: (g['fromUsername'] ?? g['username'] ?? 'Viewer').toString(),
            giftName: (g['giftName'] ?? g['name'] ?? '').toString(),
            amount: (g['amount'] is num) ? (g['amount'] as num).toInt() : (int.tryParse(g['amount']?.toString() ?? '') ?? 0),
            ts: (g['ts'] is num) ? (g['ts'] as num).toInt() : (int.tryParse(g['ts']?.toString() ?? '') ?? 0),
          );
          if (evt.giftName.trim().isEmpty) return;
          _gifts.add(evt);
          if (_gifts.length > 50) {
            _gifts.removeRange(0, _gifts.length - 50);
          }
          notifyListeners();
        }
      }
    });

    _socket = socket;
    socket.connect();
  }

  void sendChat({required String token, required String text}) {
    final t = token.trim();
    final lid = (_liveId ?? '').trim();
    final s = _socket;
    if (t.isEmpty || lid.isEmpty || s == null || !_connected) return;
    final msg = text.trim();
    if (msg.isEmpty) return;

    s.emit('live:chat:send', {
      'token': t,
      'liveId': lid,
      'text': msg,
    });
  }

  void sendLike({required String token}) {
    final t = token.trim();
    final lid = (_liveId ?? '').trim();
    final s = _socket;
    if (t.isEmpty || lid.isEmpty || s == null || !_connected) return;

    s.emit('live:chat:send', {
      'token': t,
      'liveId': lid,
      'text': 'like',
    });
  }

  Future<void> leave({required String token}) async {
    final t = token.trim();
    final lid = (_liveId ?? '').trim();
    final s = _socket;
    if (s != null && lid.isNotEmpty) {
      try {
        s.emit('live:leave', {
          'token': t,
          'liveId': lid,
        });
      } catch (_) {}
    }
    await disconnect();
  }

  Future<void> disconnect() async {
    final s = _socket;
    _socket = null;
    _connecting = false;
    _connected = false;
    _liveId = null;
    _viewers = 0;
    _messages.clear();
    _gifts.clear();
    notifyListeners();

    if (s != null) {
      try {
        s.disconnect();
      } catch (_) {}
      try {
        s.dispose();
      } catch (_) {}
    }
  }
}
