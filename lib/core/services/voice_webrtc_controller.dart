import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class VoiceWebRtcController extends ChangeNotifier {
  final Map<String, RTCPeerConnection> _pcs = {};
  MediaStream? _local;

  RTCPeerConnection? _loopPcA;
  RTCPeerConnection? _loopPcB;
  bool _loopback = false;
  bool get loopback => _loopback;

  bool _enabled = false;
  bool get enabled => _enabled;

  bool _muted = false;
  bool get muted => _muted;

  String? _roomId;

  Future<void> removePeer(String peerSocketId) async {
    final pc = _pcs.remove(peerSocketId);
    if (pc != null) {
      try {
        await pc.close();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> start({
    required io.Socket socket,
    required String token,
    required String roomId,
  }) async {
    final rid = roomId.trim();
    if (rid.isEmpty) return;
    if (_enabled) return;

    _roomId = rid;

    _local = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    _enabled = true;
    _muted = false;
    notifyListeners();

    socket.emit('voice:join', {
      'token': token,
      'roomId': rid,
    });

    void ensurePc(String peerSocketId) {
      if (_pcs.containsKey(peerSocketId)) return;
      _createPeer(socket: socket, token: token, peerSocketId: peerSocketId);
    }

    socket.on('voice:joined', (data) {
      final d = (data is Map) ? data['data'] : null;
      final peers = (d is Map) ? d['peers'] : null;
      if (peers is List) {
        for (final p in peers) {
          if (p is! Map) continue;
          final sid = p['socketId']?.toString() ?? '';
          if (sid.trim().isEmpty) continue;
          if (sid == socket.id) continue;
          ensurePc(sid);
        }
      }
    });

    socket.on('voice:peer:joined', (data) {
      final d = (data is Map) ? data['data'] : null;
      final sid = (d is Map) ? (d['socketId']?.toString() ?? '') : '';
      if (sid.trim().isEmpty) return;
      if (sid == socket.id) return;
      ensurePc(sid);
    });

    socket.on('voice:offer', (data) async {
      final d = (data is Map) ? data['data'] : null;
      if (d is! Map) return;
      final from = d['from']?.toString() ?? '';
      final offer = d['data'];
      if (from.trim().isEmpty || offer is! Map) return;

      final pc = await _getOrCreatePeer(socket: socket, token: token, peerSocketId: from);
      await pc.setRemoteDescription(
        RTCSessionDescription(offer['sdp']?.toString() ?? '', offer['type']?.toString() ?? 'offer'),
      );

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      socket.emit('voice:answer', {
        'token': token,
        'roomId': rid,
        'to': from,
        'data': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      });
    });

    socket.on('voice:answer', (data) async {
      final d = (data is Map) ? data['data'] : null;
      if (d is! Map) return;
      final from = d['from']?.toString() ?? '';
      final ans = d['data'];
      if (from.trim().isEmpty || ans is! Map) return;

      final pc = _pcs[from];
      if (pc == null) return;
      await pc.setRemoteDescription(
        RTCSessionDescription(ans['sdp']?.toString() ?? '', ans['type']?.toString() ?? 'answer'),
      );
    });

    socket.on('voice:ice', (data) async {
      final d = (data is Map) ? data['data'] : null;
      if (d is! Map) return;
      final from = d['from']?.toString() ?? '';
      final ice = d['data'];
      if (from.trim().isEmpty || ice is! Map) return;

      final pc = _pcs[from];
      if (pc == null) return;
      await pc.addCandidate(
        RTCIceCandidate(
          ice['candidate']?.toString(),
          ice['sdpMid']?.toString(),
          int.tryParse(ice['sdpMLineIndex']?.toString() ?? ''),
        ),
      );
    });
  }

  Future<RTCPeerConnection> _getOrCreatePeer({
    required io.Socket socket,
    required String token,
    required String peerSocketId,
  }) async {
    if (_pcs.containsKey(peerSocketId)) return _pcs[peerSocketId]!;
    return _createPeer(socket: socket, token: token, peerSocketId: peerSocketId);
  }

  Future<RTCPeerConnection> _createPeer({
    required io.Socket socket,
    required String token,
    required String peerSocketId,
  }) async {
    final rid = (_roomId ?? '').trim();

    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    _pcs[peerSocketId] = pc;

    final local = _local;
    if (local != null) {
      for (final t in local.getAudioTracks()) {
        await pc.addTrack(t, local);
      }
    }

    pc.onIceCandidate = (c) {
      if (c == null) return;
      if (rid.isEmpty) return;
      socket.emit('voice:ice', {
        'token': token,
        'roomId': rid,
        'to': peerSocketId,
        'data': {
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        },
      });
    };

    pc.onConnectionState = (s) {
      notifyListeners();
    };

    pc.onTrack = (e) {
      // Audio will play automatically when track is added by the system.
    };

    // Deterministic offerer to avoid glare: only the lower socketId makes the offer.
    final shouldOffer = (socket.id ?? '').compareTo(peerSocketId) < 0;
    if (shouldOffer) {
      final offer = await pc.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 0,
      });
      await pc.setLocalDescription(offer);

      socket.emit('voice:offer', {
        'token': token,
        'roomId': rid,
        'to': peerSocketId,
        'data': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      });
    }

    return pc;
  }

  Future<void> toggleMute() async {
    final local = _local;
    if (local == null) return;
    _muted = !_muted;
    for (final t in local.getAudioTracks()) {
      t.enabled = !_muted;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _enabled = false;
    _muted = false;
    notifyListeners();

    await stopLoopback();

    for (final pc in _pcs.values) {
      try {
        await pc.close();
      } catch (_) {}
    }
    _pcs.clear();

    final local = _local;
    _local = null;
    if (local != null) {
      try {
        for (final t in local.getTracks()) {
          await t.stop();
        }
        await local.dispose();
      } catch (_) {}
    }

    _roomId = null;
  }

  Future<void> startLoopback() async {
    if (_enabled) return;
    if (_loopback) return;

    _local = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    _enabled = true;
    _muted = false;
    _loopback = true;
    notifyListeners();

    final pcA = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });
    final pcB = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });
    _loopPcA = pcA;
    _loopPcB = pcB;

    final local = _local;
    if (local != null) {
      for (final t in local.getAudioTracks()) {
        await pcA.addTrack(t, local);
      }
    }

    pcA.onIceCandidate = (c) {
      if (c == null) return;
      pcB.addCandidate(c);
    };
    pcB.onIceCandidate = (c) {
      if (c == null) return;
      pcA.addCandidate(c);
    };

    pcB.onTrack = (e) {
      // Remote audio should play automatically.
      notifyListeners();
    };

    final offer = await pcA.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });
    await pcA.setLocalDescription(offer);
    await pcB.setRemoteDescription(offer);

    final answer = await pcB.createAnswer();
    await pcB.setLocalDescription(answer);
    await pcA.setRemoteDescription(answer);
  }

  Future<void> stopLoopback() async {
    if (!_loopback) return;
    _loopback = false;
    notifyListeners();

    final a = _loopPcA;
    final b = _loopPcB;
    _loopPcA = null;
    _loopPcB = null;
    try {
      await a?.close();
    } catch (_) {}
    try {
      await b?.close();
    } catch (_) {}

    if (_pcs.isEmpty) {
      final local = _local;
      _local = null;
      if (local != null) {
        try {
          for (final t in local.getTracks()) {
            await t.stop();
          }
          await local.dispose();
        } catch (_) {}
      }
      _enabled = false;
      _muted = false;
      notifyListeners();
    }
  }
}
