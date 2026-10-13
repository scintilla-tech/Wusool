import 'package:socket_io_client/socket_io_client.dart' as io;

/// Thin Socket.IO client wrapper. Only used to publish the driver's location
/// during an ACTIVE trip (server validates role/trip/bus/tenant).
class SocketService {
  io.Socket? _socket;

  bool get connected => _socket?.connected ?? false;

  void connect(
    String socketUrl,
    String token, {
    void Function(Map<String, dynamic> location)? onLocation,
    void Function()? onTripCompleted,
    void Function(Map<String, dynamic> event)? onAttendanceChanged,
    void Function(Map<String, dynamic> event)? onAttendanceClosed,
    void Function(Map<String, dynamic> error)? onError,
  }) {
    disconnect();
    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    if (onLocation != null) {
      _socket!.on('trip:location', (data) {
        if (data is Map) onLocation(data.cast<String, dynamic>());
      });
    }
    if (onTripCompleted != null) {
      _socket!.on('trip:completed', (_) => onTripCompleted());
    }
    if (onAttendanceChanged != null) {
      _socket!.on('attendance:changed', (data) {
        if (data is Map) onAttendanceChanged(data.cast<String, dynamic>());
      });
    }
    if (onAttendanceClosed != null) {
      _socket!.on('attendance:closed', (data) {
        if (data is Map) onAttendanceClosed(data.cast<String, dynamic>());
      });
    }
    if (onError != null) {
      _socket!.on('trip:error', (data) {
        if (data is Map) onError(data.cast<String, dynamic>());
      });
    }
    _socket!.connect();
  }

  void publishLocation(double latitude, double longitude) {
    _socket?.emit('trip:location', {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
