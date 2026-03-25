import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  final String url;
  io.Socket? _socket;

  SocketService({required this.url});

  bool get isConnected => _socket?.connected == true;

  void connect({required String token}) {
    disconnect();
    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void on(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }
}

