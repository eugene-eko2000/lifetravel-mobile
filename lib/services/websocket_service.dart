import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WsMessageHandler = void Function(String rawData, dynamic parsed);
typedef WsVoidCallback = void Function();

class TripWebSocketService {
  WebSocketChannel? _channel;

  void connect({
    required String baseUrl,
    required String prompt,
    required String? promptId,
    required WsMessageHandler onMessage,
    required WsVoidCallback onOpen,
    required WsVoidCallback onError,
    required WsVoidCallback onClose,
  }) {
    close();

    final wsUrl = '$baseUrl/api/v1/trip';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    onOpen();

    _channel!.sink.add(jsonEncode({
      'id': null,
      'prompt_id': promptId,
      'content': prompt,
    }));

    _channel!.stream.listen(
      (data) {
        final rawData = data is String ? data : data.toString();
        dynamic parsed;
        try {
          parsed = jsonDecode(rawData);
        } catch (_) {
          parsed = null;
        }
        onMessage(rawData, parsed);
      },
      onError: (_) {
        onError();
        _channel = null;
      },
      onDone: () {
        onClose();
        _channel = null;
      },
    );
  }

  void close() {
    _channel?.sink.close();
    _channel = null;
  }
}
