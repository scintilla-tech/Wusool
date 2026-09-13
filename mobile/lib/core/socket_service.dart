import 'package:socket_io_client/socket_io_client.dart' as io;

/// Thin Socket.IO client wrapper. Only used to publish the driver's location
/// during an ACTIVE trip (server validates role/trip/bus/tenant).
class SocketService {
  io.Socket? _socket;

  bool get connected => _socket?.connected ?? false;

  void connect(String socketUrl, String token) {
    disconnect();
    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
  }

  void publishLocation(double latitude, double longitude) {
    _socket?.emit('trip:location', {'latitude': latitude, 'longitude': longitude});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
