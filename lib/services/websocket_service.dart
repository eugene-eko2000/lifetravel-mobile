import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

typedef WsMessageHandler = void Function(String rawData, dynamic parsed);
typedef WsVoidCallback = void Function();

class TripWebSocketService {
  IOWebSocketChannel? _channel;

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
    // RFC 7692 permessage-deflate: negotiated on the handshake (server must offer it).
    _channel = IOWebSocketChannel(
      WebSocket.connect(
        wsUrl,
        compression: CompressionOptions.compressionDefault,
      ),
    );

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
