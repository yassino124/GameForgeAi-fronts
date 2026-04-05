import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';
import 'voice_webrtc_controller.dart';

typedef MpMessage = ({String id, String roomId, String userId, String username, String text, DateTime createdAt});

typedef MpMember = ({String userId, String username, bool isOnline});

typedef MpRoom = ({
  String roomId,
  String name,
  String hostUserId,
  bool isPublic,
  int maxPlayers,
  bool isMatchStarted,
  List<MpMember> members,
});

typedef MpVoicePeer = ({String socketId, String userId});

typedef MpGameInput = ({
  String sessionId,
  String userId,
  String type,
  Map<String, dynamic> payload,
  int ts,
});

typedef MpGameState = ({
  String sessionId,
  Map<String, dynamic> state,
  int ts,
});

class MultiplayerController extends ChangeNotifier {
  io.Socket? _socket;

  bool _demo = false;
  bool get demoMode => _demo;

  Timer? _demoTimer;

  bool _connecting = false;
  bool get connecting => _connecting;

  bool _connected = false;
  bool get connected => _connected;

  String? _error;
  String? get error => _error;

  String? _myUserId;
  String? get myUserId => _myUserId;

  MpRoom? _room;
  MpRoom? get room => _room;

  bool _queued = false;
  bool get queued => _queued;

  final Set<String> _readyUserIds = <String>{};
  Set<String> get readyUserIds => Set.unmodifiable(_readyUserIds);

  String? _sessionId;
  String? get sessionId => _sessionId;

  String? _startedProjectId;
  String? get startedProjectId => _startedProjectId;

  String? _startedRuntimeUrl;
  String? get startedRuntimeUrl => _startedRuntimeUrl;

  String? _startedArcadePostId;
  String? get startedArcadePostId => _startedArcadePostId;

  bool _voiceJoined = false;
  bool get voiceJoined => _voiceJoined;

  final VoiceWebRtcController _voiceRtc = VoiceWebRtcController();

  bool get voiceMuted => _voiceRtc.muted;

  bool get voiceLoopback => _voiceRtc.loopback;

  final List<MpVoicePeer> _voicePeers = [];
  List<MpVoicePeer> get voicePeers => List.unmodifiable(_voicePeers);

  final List<MpMessage> _messages = [];
  List<MpMessage> get messages => List.unmodifiable(_messages);

  final List<MpGameInput> _gameInputs = [];
  List<MpGameInput> get gameInputs => List.unmodifiable(_gameInputs);

  MpGameState? _lastGameState;
  MpGameState? get lastGameState => _lastGameState;

  String? _token;
  String? _username;

  Uri _socketBaseUri() {
    final api = Uri.parse(ApiService.baseUrl);
    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
    );
  }

  void sendGameInput({
    required String sessionId,
    required String type,
    required Map<String, dynamic> payload,
    String? roomId,
  }) {
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;
    final sid = sessionId.trim();
    if (sid.isEmpty) return;
    s.emit('game:input', {
      'token': t,
      if ((roomId ?? '').trim().isNotEmpty) 'roomId': roomId!.trim(),
      'sessionId': sid,
      'type': type.trim().isEmpty ? 'input' : type.trim(),
      'payload': payload,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void sendGameState({
    required String sessionId,
    required Map<String, dynamic> state,
    String? roomId,
  }) {
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;
    final sid = sessionId.trim();
    if (sid.isEmpty) return;
    s.emit('game:state', {
      'token': t,
      if ((roomId ?? '').trim().isNotEmpty) 'roomId': roomId!.trim(),
      'sessionId': sid,
      'state': state,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  String _mpNamespaceUrl() {
    final base = _socketBaseUri().toString();
    return Uri.parse(base).resolve('/mp').toString();
  }

  Future<void> connect({required String token, String? username}) async {
    final t = token.trim();
    if (t.isEmpty) return;
    if (_connected || _connecting) return;

    _token = t;
    _username = (username ?? '').trim();

    _connecting = true;
    _error = null;
    notifyListeners();

    final socket = io.io(
      _mpNamespaceUrl(),
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setPath('/socket.io')
          .setAuth({'token': t})
          .build(),
    );

    void markConnected() {
      if (_connected && !_connecting) return;
      _connecting = false;
      _connected = true;
      _error = null;
      notifyListeners();
      try {
        socket.emit('mp:auth', {'token': t, if (_username != null && _username!.isNotEmpty) 'username': _username});
      } catch (_) {}
    }

    void markDisconnected({String? error}) {
      _connecting = false;
      _connected = false;
      if (error != null && error.trim().isNotEmpty) {
        _error = error.trim();
      }
      notifyListeners();
    }

    Timer? connectTimeout;
    connectTimeout = Timer(const Duration(seconds: 8), () {
      if (_connected) return;
      if (!_connecting) return;
      markDisconnected(error: _error ?? 'Connection timeout');
      try {
        socket.disconnect();
      } catch (_) {}
    });

    socket.onConnect((_) {
      connectTimeout?.cancel();
      connectTimeout = null;
      markConnected();
    });

    socket.on('connect', (_) {
      connectTimeout?.cancel();
      connectTimeout = null;
      markConnected();
    });

    socket.on('mp:auth:ok', (data) {
      if (data is! Map) return;
      final d = data['data'];
      if (d is! Map) return;
      final uid = d['userId']?.toString();
      if (uid != null && uid.trim().isNotEmpty) {
        _myUserId = uid.trim();
        notifyListeners();
      }
    });

    socket.onDisconnect((_) {
      connectTimeout?.cancel();
      connectTimeout = null;
      markDisconnected();
    });

    socket.on('disconnect', (_) {
      connectTimeout?.cancel();
      connectTimeout = null;
      markDisconnected();
    });

    socket.onConnectError((err) {
      connectTimeout?.cancel();
      connectTimeout = null;
      markDisconnected(error: 'Connection failed');
    });

    socket.on('connect_error', (err) {
      connectTimeout?.cancel();
      connectTimeout = null;
      markDisconnected(error: 'Connection failed');
    });

    socket.on('error', (err) {
      if (_connected) return;
      markDisconnected(error: 'Connection failed');
    });

    socket.on('mp:error', (data) {
      final msg = (data is Map ? data['message'] : null)?.toString();
      if (msg != null && msg.trim().isNotEmpty) {
        _error = msg;
        notifyListeners();
      }
    });

    socket.on('matchmaking:queued', (data) {
      _queued = true;
      notifyListeners();
    });

    socket.on('matchmaking:left', (data) {
      _queued = false;
      notifyListeners();
    });

    socket.on('matchmaking:found', (data) {
      dynamic rawRoom;
      if (data is Map) {
        final d = data['data'];
        if (d is Map && d['room'] != null) rawRoom = d['room'];
      }
      final room = _parseRoom(rawRoom);
      if (room != null) {
        _queued = false;
        _room = room;
        notifyListeners();
      }
    });

    socket.on('room:ready:update', (data) {
      if (data is! Map) return;
      final d = data['data'];
      if (d is! Map) return;
      final items = d['readyUserIds'];
      if (items is! List) return;

      _readyUserIds
        ..clear()
        ..addAll(items.map((e) => e.toString()).where((e) => e.trim().isNotEmpty));
      notifyListeners();
    });

    socket.on('game:start', (data) {
      if (data is! Map) return;
      final d = data['data'];
      if (d is! Map) return;
      final sid = d['sessionId']?.toString();
      final pid = d['projectId']?.toString();
      final rurl = d['runtimeUrl']?.toString();
      final postId = d['arcadePostId']?.toString();
      if (sid != null && sid.trim().isNotEmpty) {
        _sessionId = sid.trim();
        if (pid != null && pid.trim().isNotEmpty) {
          _startedProjectId = pid.trim();
        }
        if (rurl != null && rurl.trim().isNotEmpty) {
          _startedRuntimeUrl = rurl.trim();
        }
        if (postId != null && postId.trim().isNotEmpty) {
          _startedArcadePostId = postId.trim();
        }
        notifyListeners();
      }
    });

    socket.on('game:input', (data) {
      if (data is! Map) return;
      final d = data['data'];
      if (d is! Map) return;
      final sid = d['sessionId']?.toString() ?? (_sessionId ?? '');
      final uid = d['userId']?.toString() ?? '';
      final type = d['type']?.toString() ?? 'input';
      final payloadRaw = d['payload'];
      final payload = payloadRaw is Map ? Map<String, dynamic>.from(payloadRaw) : <String, dynamic>{};
      final ts = (d['ts'] is num) ? (d['ts'] as num).toInt() : (int.tryParse(d['ts']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch);
      if (sid.trim().isEmpty) return;
      _gameInputs.add((sessionId: sid.trim(), userId: uid, type: type, payload: payload, ts: ts));
      if (_gameInputs.length > 180) {
        _gameInputs.removeRange(0, _gameInputs.length - 180);
      }
      notifyListeners();
    });

    socket.on('game:state', (data) {
      if (data is! Map) return;
      final d = data['data'];
      if (d is! Map) return;
      final sid = d['sessionId']?.toString() ?? (_sessionId ?? '');
      final stateRaw = d['state'];
      final state = stateRaw is Map ? Map<String, dynamic>.from(stateRaw) : <String, dynamic>{};
      final ts = (d['ts'] is num) ? (d['ts'] as num).toInt() : (int.tryParse(d['ts']?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch);
      if (sid.trim().isEmpty) return;
      _lastGameState = (sessionId: sid.trim(), state: state, ts: ts);
      notifyListeners();
    });

    socket.on('voice:joined', (data) {
      if (data is! Map) return;
      final d = data['data'];
      if (d is! Map) return;
      final peers = d['peers'];
      _voicePeers.clear();
      if (peers is List) {
        for (final p in peers) {
          if (p is! Map) continue;
          final socketId = p['socketId']?.toString() ?? '';
          final userId = p['userId']?.toString() ?? '';
          if (socketId.trim().isEmpty || userId.trim().isEmpty) continue;
          _voicePeers.add((socketId: socketId, userId: userId));
        }
      }
      _voiceJoined = true;
      notifyListeners();
    });

    socket.on('voice:peer:joined', (data) {
      if (data is! Map) return;
      final d = data['data'];
      if (d is! Map) return;
      final socketId = d['socketId']?.toString() ?? '';
      final userId = d['userId']?.toString() ?? '';
      if (socketId.trim().isEmpty || userId.trim().isEmpty) return;
      if (_voicePeers.any((p) => p.socketId == socketId)) return;
      _voicePeers.add((socketId: socketId, userId: userId));
      notifyListeners();
    });

    socket.on('voice:peer:left', (data) {
      if (data is! Map) return;
      final d = data['data'];
      if (d is! Map) return;
      final socketId = d['socketId']?.toString() ?? '';
      if (socketId.trim().isEmpty) return;
      _voicePeers.removeWhere((p) => p.socketId == socketId);
      _voiceRtc.removePeer(socketId);
      notifyListeners();
    });

    socket.on('room:update', (data) {
      dynamic rawRoom;
      if (data is Map) {
        final d = data['data'];
        if (d is Map && d['room'] != null) {
          rawRoom = d['room'];
        } else {
          rawRoom = data['room'];
        }
      }

      final room = _parseRoom(rawRoom);
      if (room != null) {
        _room = room;
        notifyListeners();
      }
    });

    socket.on('room:deleted', (data) {
      _room = null;
      notifyListeners();
    });

    socket.on('chat:history', (data) {
      final d = (data is Map ? data['data'] : null);
      final items = (d is Map ? d['items'] : null);
      if (items is List) {
        _messages
          ..clear()
          ..addAll(items.whereType<Map>().map(_parseMessage).whereType<MpMessage>());
        notifyListeners();
      }
    });

    socket.on('chat:message', (data) {
      final d = (data is Map ? data['data'] : null);
      final item = (d is Map ? d['item'] : null);
      if (item is Map) {
        final msg = _parseMessage(item);
        if (msg != null) {
          _messages.add(msg);
          if (_messages.length > 200) {
            _messages.removeRange(0, _messages.length - 200);
          }
          notifyListeners();
        }
      }
    });

    _socket = socket;
    socket.connect();
  }

  Future<void> disconnect() async {
    _demoTimer?.cancel();
    _demoTimer = null;
    _demo = false;
    final s = _socket;
    _socket = null;
    _connecting = false;
    _connected = false;
    _room = null;
    _messages.clear();
    _myUserId = null;
    _queued = false;
    _readyUserIds.clear();
    _sessionId = null;
    _startedProjectId = null;
    _startedRuntimeUrl = null;
    _startedArcadePostId = null;
    _voiceJoined = false;
    _voicePeers.clear();
    await _voiceRtc.stop();
    notifyListeners();
    try {
      s?.disconnect();
      s?.dispose();
    } catch (_) {}
  }

  Future<void> startDemoRoom({required String username}) async {
    await disconnect();

    _demo = true;
    _connecting = false;
    _connected = true;
    _error = null;

    final meId = 'demo-me';
    _myUserId = meId;

    final rid = 'demo_room_${DateTime.now().millisecondsSinceEpoch}';
    final members = <MpMember>[
      (userId: meId, username: username.trim().isEmpty ? 'You' : username.trim(), isOnline: true),
      (userId: 'bot-1', username: 'BotA', isOnline: true),
      (userId: 'bot-2', username: 'BotB', isOnline: true),
      (userId: 'bot-3', username: 'BotC', isOnline: true),
    ];

    _room = (
      roomId: rid,
      name: 'Demo Lobby',
      hostUserId: meId,
      isPublic: true,
      maxPlayers: 4,
      isMatchStarted: false,
      members: members,
    );

    _readyUserIds
      ..clear()
      ..add(meId);

    _messages
      ..clear()
      ..add((
        id: 'demo-0',
        roomId: rid,
        userId: 'bot-1',
        username: 'BotA',
        text: 'Demo mode: bots are ready to play.',
        createdAt: DateTime.now(),
      ));

    notifyListeners();

    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_demo) return;
      final room = _room;
      if (room == null) return;

      final botIds = ['bot-1', 'bot-2', 'bot-3'];
      for (final bid in botIds) {
        if (!_readyUserIds.contains(bid)) {
          _readyUserIds.add(bid);
          _messages.add((
            id: 'demo-ready-$bid-${DateTime.now().millisecondsSinceEpoch}',
            roomId: room.roomId,
            userId: bid,
            username: room.members.firstWhere((m) => m.userId == bid).username,
            text: 'Ready ✅',
            createdAt: DateTime.now(),
          ));
          if (_messages.length > 200) {
            _messages.removeRange(0, _messages.length - 200);
          }
          notifyListeners();
          break;
        }
      }
    });
  }

  Future<void> createRoom({String? name}) async {
    if (_demo) {
      await startDemoRoom(username: _username ?? 'You');
      return;
    }
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;

    s.emit('room:create', {
      'token': t,
      if (_username != null && _username!.isNotEmpty) 'username': _username,
      if ((name ?? '').trim().isNotEmpty) 'name': name!.trim(),
    });
  }

  Future<void> queueMatchmaking() async {
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;

    _messages.clear();
    _gameInputs.clear();
    _lastGameState = null;
    notifyListeners();

    s.emit('matchmaking:queue', {
      'token': t,
      if (_username != null && _username!.isNotEmpty) 'username': _username,
    });
  }

  Future<void> leaveMatchmaking() async {
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;

    _queued = false;
    notifyListeners();

    s.emit('matchmaking:leave', {
      'token': t,
      if (_username != null && _username!.isNotEmpty) 'username': _username,
    });
  }

  Future<void> setReady({required bool ready, String? roomId}) async {
    if (_demo) {
      final me = _myUserId;
      if (me == null) return;
      if (ready) {
        _readyUserIds.add(me);
      } else {
        _readyUserIds.remove(me);
      }
      notifyListeners();
      return;
    }
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;

    s.emit('room:ready', {
      'token': t,
      if ((roomId ?? '').trim().isNotEmpty) 'roomId': roomId!.trim(),
      'ready': ready,
    });
  }

  Future<void> startMatch({
    String? roomId,
    String? projectId,
    String? runtimeUrl,
    String? arcadePostId,
  }) async {
    if (_demo) {
      final sid = 'demo-session-${DateTime.now().millisecondsSinceEpoch}';
      _sessionId = sid;
      final pid = (projectId ?? '').trim();
      final rurl = (runtimeUrl ?? '').trim();
      final postId = (arcadePostId ?? '').trim();
      if (pid.isNotEmpty) {
        _startedProjectId = pid;
      } else if (rurl.isNotEmpty) {
        _startedRuntimeUrl = rurl;
      } else {
        _startedProjectId = 'demo-project';
      }
      if (postId.isNotEmpty) {
        _startedArcadePostId = postId;
      }
      final r = _room;
      if (r != null) {
        _room = (
          roomId: r.roomId,
          name: r.name,
          hostUserId: r.hostUserId,
          isPublic: r.isPublic,
          maxPlayers: r.maxPlayers,
          isMatchStarted: true,
          members: r.members,
        );
        _messages.add((
          id: 'demo-start-${DateTime.now().millisecondsSinceEpoch}',
          roomId: r.roomId,
          userId: 'bot-2',
          username: 'BotB',
          text: 'Game started 🎮 (demo)',
          createdAt: DateTime.now(),
        ));
      }
      notifyListeners();
      return;
    }
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;

    final pid = (projectId ?? '').trim();
    final rurl = (runtimeUrl ?? '').trim();
    final postId = (arcadePostId ?? '').trim();
    if (pid.isEmpty && rurl.isEmpty) return;

    s.emit('room:start', {
      'token': t,
      if (pid.isNotEmpty) 'projectId': pid,
      if (rurl.isNotEmpty) 'runtimeUrl': rurl,
      if (postId.isNotEmpty) 'arcadePostId': postId,
      if ((roomId ?? '').trim().isNotEmpty) 'roomId': roomId!.trim(),
    });
  }

  Future<void> voiceJoin({String? roomId}) async {
    final s = _socket;
    final t = (_token ?? '').trim();
    final rid = (roomId ?? '').trim();
    if (s == null || t.isEmpty || rid.isEmpty) return;

    await _voiceRtc.start(socket: s, token: t, roomId: rid);
    _voiceJoined = _voiceRtc.enabled;
    notifyListeners();
  }

  Future<void> voiceToggleMute() async {
    if (!_voiceRtc.enabled) return;
    await _voiceRtc.toggleMute();
    notifyListeners();
  }

  Future<void> voiceStop() async {
    await _voiceRtc.stop();
    _voiceJoined = false;
    notifyListeners();
  }

  Future<void> voiceSelfTestStart() async {
    await _voiceRtc.startLoopback();
    _voiceJoined = false;
    notifyListeners();
  }

  Future<void> voiceSelfTestStop() async {
    await _voiceRtc.stopLoopback();
    notifyListeners();
  }

  Future<void> joinRoom({required String roomId}) async {
    if (_demo) return;
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;

    s.emit('room:join', {
      'token': t,
      if (_username != null && _username!.isNotEmpty) 'username': _username,
      'roomId': roomId.trim(),
    });
  }

  Future<void> leaveRoom({String? roomId}) async {
    if (_demo) {
      await disconnect();
      return;
    }
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;

    s.emit('room:leave', {
      'token': t,
      if ((roomId ?? '').trim().isNotEmpty) 'roomId': roomId!.trim(),
    });
  }

  Future<void> sendChat({required String text, String? roomId}) async {
    if (_demo) {
      final r = _room;
      final me = _myUserId;
      if (r == null || me == null) return;
      final trimmed = text.trim();
      if (trimmed.isEmpty) return;
      final uname = r.members.firstWhere((m) => m.userId == me).username;
      _messages.add((
        id: 'demo-me-${DateTime.now().millisecondsSinceEpoch}',
        roomId: r.roomId,
        userId: me,
        username: uname,
        text: trimmed,
        createdAt: DateTime.now(),
      ));
      if (_messages.length > 200) {
        _messages.removeRange(0, _messages.length - 200);
      }

      Timer(const Duration(milliseconds: 650), () {
        if (!_demo) return;
        final replyFrom = 'bot-1';
        _messages.add((
          id: 'demo-reply-${DateTime.now().millisecondsSinceEpoch}',
          roomId: r.roomId,
          userId: replyFrom,
          username: 'BotA',
          text: 'BotA: received "${trimmed.length > 38 ? trimmed.substring(0, 38) : trimmed}"',
          createdAt: DateTime.now(),
        ));
        if (_messages.length > 200) {
          _messages.removeRange(0, _messages.length - 200);
        }
        notifyListeners();
      });

      notifyListeners();
      return;
    }
    final s = _socket;
    final t = (_token ?? '').trim();
    if (s == null || t.isEmpty) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    s.emit('chat:send', {
      'token': t,
      if (_username != null && _username!.isNotEmpty) 'username': _username,
      if ((roomId ?? '').trim().isNotEmpty) 'roomId': roomId!.trim(),
      'text': trimmed,
    });
  }

  MpRoom? _parseRoom(dynamic raw) {
    if (raw is! Map) return null;

    final roomId = (raw['roomId'] ?? raw['_id'] ?? raw['id'])?.toString() ?? '';
    final name = raw['name']?.toString() ?? 'Lobby';
    final hostUserId = raw['hostUserId']?.toString() ?? '';
    final isPublic = raw['isPublic'] == true;
    final maxPlayers = int.tryParse(raw['maxPlayers']?.toString() ?? '') ?? 4;
    final isMatchStarted = raw['isMatchStarted'] == true;

    final membersRaw = raw['members'];
    final members = <MpMember>[];
    if (membersRaw is List) {
      for (final m in membersRaw) {
        if (m is! Map) continue;
        members.add((
          userId: m['userId']?.toString() ?? '',
          username: m['username']?.toString() ?? 'player',
          isOnline: m['isOnline'] == true,
        ));
      }
    }

    if (roomId.trim().isEmpty) return null;

    return (
      roomId: roomId,
      name: name,
      hostUserId: hostUserId,
      isPublic: isPublic,
      maxPlayers: maxPlayers,
      isMatchStarted: isMatchStarted,
      members: members,
    );
  }

  MpMessage? _parseMessage(dynamic raw) {
    if (raw is! Map) return null;

    final id = (raw['_id'] ?? raw['id'])?.toString() ?? '';
    final roomId = raw['roomId']?.toString() ?? '';
    final userId = raw['userId']?.toString() ?? '';
    final username = raw['username']?.toString() ?? 'player';
    final text = raw['text']?.toString() ?? '';

    DateTime createdAt = DateTime.now();
    final c = raw['createdAt']?.toString();
    if (c != null && c.trim().isNotEmpty) {
      createdAt = DateTime.tryParse(c) ?? createdAt;
    }

    if (roomId.trim().isEmpty || text.trim().isEmpty) return null;

    return (
      id: id,
      roomId: roomId,
      userId: userId,
      username: username,
      text: text,
      createdAt: createdAt,
    );
  }
}
