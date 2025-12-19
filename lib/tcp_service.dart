import 'dart:io';
import 'dart:async';

class TCPService {
  final String host;
  final int port;

  Socket? _socket;
  bool isConnected = false;
  Timer? _reconnectTimer;

  // Callbacks
  Function(String msg)? onDataReceived;
  Function(bool connected)? onConnectionChanged;

  TCPService({required this.host, required this.port});

  /// Kết nối tới ESP32
  Future<void> connect() async {
    // Hủy timer reconnect cũ nếu có
    _reconnectTimer?.cancel();

    try {
      print('🔌 Connecting to ESP32 $host:$port ...');

      // Đóng socket cũ nếu có
      _socket?.destroy();

      // Tạo kết nối mới
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );

      print('✅ Connected to ESP32');
      _setConnectionState(true);

      // Lắng nghe dữ liệu từ ESP32
      _socket!.listen(
        (data) {
          final msg = String.fromCharCodes(data).trim();
          if (onDataReceived != null && msg.isNotEmpty) {
            onDataReceived!(msg);
          }
        },
        onError: (error) {
          print('⚠️ ESP32 socket error: $error');
          _onSocketClosed();
        },
        onDone: () {
          print('⚠️ ESP32 socket closed by remote');
          _onSocketClosed();
        },
      );
    } catch (e) {
      print('❌ Connect failed: $e');
      _setConnectionState(false);
      _scheduleReconnect();
    }
  }

  /// Gửi message tới ESP32
  void send(String msg) {
    if (isConnected && _socket != null) {
      try {
        final line = msg.endsWith('\n') ? msg : '$msg\n';
        _socket!.write(line);
        print('📤 Sent to ESP32: $msg');
      } catch (e) {
        print('❌ Send failed: $e');
        _onSocketClosed();
      }
    } else {
      print('⚠️ Cannot send, not connected');
    }
  }

  /// Xử lý khi socket bị đóng
  void _onSocketClosed() {
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _setConnectionState(false);
    _scheduleReconnect();
  }

  /// Lên lịch reconnect tự động
  void _scheduleReconnect() {
    // Tránh tạo nhiều timer
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (isConnected) {
        timer.cancel();
      } else {
        print('🔄 Trying reconnect to ESP32...');
        connect();
      }
    });
  }

  /// Cập nhật trạng thái kết nối và gọi callback
  void _setConnectionState(bool connected) {
    if (isConnected != connected) {
      isConnected = connected;
      if (onConnectionChanged != null) {
        onConnectionChanged!(connected);
      }
    }
  }

  /// Đóng kết nối
  void close() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _setConnectionState(false);
    print('🔒 TCP connection closed');
  }

  /// Reconnect thủ công (nếu cần)
  void reconnect() {
    _onSocketClosed();
  }
}
