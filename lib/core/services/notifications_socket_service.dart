import 'package:socket_io_client/socket_io_client.dart' as IO;

class NotificationsSocketService {
  static final NotificationsSocketService _instance = NotificationsSocketService._internal();

  factory NotificationsSocketService() {
    return _instance;
  }

  NotificationsSocketService._internal();

  late IO.Socket _socket;
  bool _isConnected = false;
  final List<Function(Map<String, dynamic>)> _listeners = [];
  
  /// Callback invoked when user is banned/suspended and force disconnected
  Future<void> Function()? onForceLogout;

  // Initialize connection
  Future<void> connect({
    required String baseUrl,
    required String token,
    bool forceNew = false,
  }) async {
    try {
      final url = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final socketUrl = '${url}notifications';
      
      print('[Socket] Connecting to: $socketUrl');
      print('[Socket] Using token: ${token.substring(0, 20)}...');
      
      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setAuth({'token': 'Bearer $token'})
            .setTransports(['websocket'])
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(99999)
            .build(),
      );

      _socket.onConnect((_) {
        print('[Socket] ✅ Connected successfully');
        print('[Socket] Socket ID: ${_socket.id}');
        _isConnected = true;
        _sendPing();
      });

      _socket.on('notification:received', (data) {
        print('[Socket] 📨 Notification received: $data');
        _notifyListeners(data is Map ? data.cast<String, dynamic>() : {});
      });

      // Listen for ban/suspend notification
      _socket.on('user:banned', (_) async {
        print('[Socket] 🚫 User banned/suspended - force logout');
        disconnect();
        if (onForceLogout != null) {
          await onForceLogout!();
        }
      });

      _socket.onDisconnect((_) {
        print('[Socket] ❌ Disconnected from socket server');
        _isConnected = false;
      });

      _socket.onError((error) {
        print('[Socket] ⚠️ Socket Error: $error');
      });

      _socket.onConnectError((error) {
        print('[Socket] 🔴 Connection Error: $error');
      });

      // Wait for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('[Socket] 💥 Connection exception: $e');
      rethrow;
    }
  }

  // Send ping to keep connection alive
  void _sendPing() {
    if (_isConnected) {
      print('[Socket] 💓 Sending ping...');
      _socket.emit('ping');
      Future.delayed(const Duration(seconds: 30), _sendPing);
    }
  }

  // Add listener for notifications
  void addListener(Function(Map<String, dynamic>) listener) {
    _listeners.add(listener);
  }

  // Remove listener
  void removeListener(Function(Map<String, dynamic>) listener) {
    _listeners.remove(listener);
  }

  // Notify all listeners
  void _notifyListeners(Map<String, dynamic> notification) {
    for (var listener in _listeners) {
      listener(notification);
    }
  }

  // Get connection status
  bool get isConnected => _isConnected;

  // Disconnect
  void disconnect() {
    if (_socket.connected) {
      _socket.disconnect();
    }
    _isConnected = false;
  }

  // Reconnect
  Future<void> reconnect() async {
    disconnect();
    await Future.delayed(const Duration(seconds: 1));
    // Connection will be re-established by the connect method
  }
}
