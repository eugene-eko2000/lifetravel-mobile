import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum MessageRole { user, assistant }

class TripBlock {
  final String type; // "json" | "text"
  final dynamic data;
  const TripBlock({required this.type, required this.data});
  bool get isJson => type == 'json';
  bool get isText => type == 'text';
}

class Message {
  final String id;
  final MessageRole role;
  final String content;
  List<TripBlock> blocks;
  String? statusText;
  String? missingInfoText;

  Message({
    String? id,
    required this.role,
    required this.content,
    List<TripBlock>? blocks,
    this.statusText,
    this.missingInfoText,
  })  : id = id ?? _uuid.v4(),
        blocks = blocks ?? [];

  Message copyWith({
    List<TripBlock>? blocks,
    String? statusText,
    String? missingInfoText,
    bool clearStatusText = false,
  }) {
    return Message(
      id: id,
      role: role,
      content: content,
      blocks: blocks ?? this.blocks,
      statusText: clearStatusText ? null : (statusText ?? this.statusText),
      missingInfoText: missingInfoText ?? this.missingInfoText,
    );
  }
}

class DebugMessage {
  final String? id;
  final String? requestId;
  final String message;
  final String? source;
  final String? level; // debug | info | warning | error
  final Map<String, dynamic>? payload;

  const DebugMessage({
    this.id,
    this.requestId,
    required this.message,
    this.source,
    this.level,
    this.payload,
  });
}

class DebugEntry {
  final String id;
  final DebugMessage data;
  DebugEntry({required this.data}) : id = _uuid.v4();
}
