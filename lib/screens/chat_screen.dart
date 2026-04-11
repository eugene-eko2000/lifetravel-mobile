import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../theme.dart';
import '../utils/trip_helpers.dart';
import '../widgets/trip_card.dart';
import '../widgets/json_viewer.dart';

const _tripPageSize = 10;
const String _defaultWsUrl = 'ws://localhost:8080';

String? _extractMissingInfoText(dynamic payload) {
  if (!isObject(payload)) return null;
  final root = payload as Map<String, dynamic>;
  final sr = root['structured_request'];
  if (!isObject(sr)) return null;
  final output = (sr as Map<String, dynamic>)['output'];
  if (!isObject(output)) return null;
  final mi = (output as Map<String, dynamic>)['missing_info'];
  if (mi is String) return mi;
  if (mi != null && mi is Map) return const JsonEncoder.withIndent('  ').convert(mi);
  if (mi != null) return mi.toString();
  return null;
}

String? _extractPromptId(dynamic value) {
  String? fromObj(Map<String, dynamic> obj) {
    final raw = obj['prompt_id'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is num && raw.isFinite) return raw.toString();
    return null;
  }

  if (isObject(value)) {
    final o = value as Map<String, dynamic>;
    final direct = fromObj(o);
    if (direct != null) return direct;
    for (final k in ['ranked_trip', 'trip', 'ranked_itinerary', 'itinerary', 'data', 'ranked']) {
      final nested = o[k];
      if (isObject(nested)) {
        final pid = fromObj(nested as Map<String, dynamic>);
        if (pid != null) return pid;
      }
    }
  }
  return null;
}

String _normalizeDebugLevel(dynamic value) {
  if (value is! String) return 'info';
  final n = value.toLowerCase();
  if (n == 'warn') return 'warning';
  if (['debug', 'info', 'warning', 'error'].contains(n)) return n;
  return 'info';
}

Color _debugLevelColor(String? level) {
  switch (level) {
    case 'debug':
      return AppColors.debugColor;
    case 'warning':
      return AppColors.warningColor;
    case 'error':
      return AppColors.errorColor;
    default:
      return AppColors.foreground;
  }
}

bool _isStatusMessage(dynamic value) {
  if (!isObject(value)) return false;
  final m = value as Map<String, dynamic>;
  return m['id'] is String && m['message'] is String;
}

class ChatScreen extends StatefulWidget {
  final String wsBaseUrl;
  const ChatScreen({super.key, this.wsBaseUrl = _defaultWsUrl});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messages = <Message>[];
  final _debugMessages = <DebugEntry>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();
  final _wsService = TripWebSocketService();

  bool _isConnecting = false;
  bool _isStreaming = false;
  bool _isDebugOpen = false;
  String? _lastPromptId;
  String? _copiedKey;
  dynamic _tripModalData;
  late AnimationController _statusWaveController;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() => setState(() {}));
    _statusWaveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
  }

  void _syncWaveAnimation() {
    if ((_isConnecting || _isStreaming) && !_statusWaveController.isAnimating) {
      _statusWaveController.repeat();
    } else if (!_isConnecting && !_isStreaming && _statusWaveController.isAnimating) {
      _statusWaveController.stop();
      _statusWaveController.value = 0;
    }
  }

  @override
  void dispose() {
    _wsService.close();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _statusWaveController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final prompt = _inputController.text.trim();
    if (prompt.isEmpty || _isConnecting || _isStreaming) return;

    final continuingSame = _lastPromptId != null;
    final userMessage = Message(role: MessageRole.user, content: prompt);
    final assistantMessage = Message(role: MessageRole.assistant, content: '', blocks: []);

    setState(() {
      if (continuingSame) {
        final promptsOnly = _messages.where((m) => m.role == MessageRole.user).toList();
        _messages
          ..clear()
          ..addAll(promptsOnly)
          ..add(userMessage)
          ..add(assistantMessage);
      } else {
        _debugMessages.clear();
        _messages
          ..clear()
          ..add(userMessage)
          ..add(assistantMessage);
      }
      _inputController.clear();
      _isConnecting = true;
    });
    _syncWaveAnimation();

    final assistantId = assistantMessage.id;

    _wsService.connect(
      baseUrl: widget.wsBaseUrl,
      prompt: prompt,
      promptId: _lastPromptId,
      onOpen: () {
        if (mounted) {
          setState(() { _isConnecting = false; _isStreaming = true; });
          _syncWaveAnimation();
        }
      },
      onMessage: (rawData, parsed) {
        if (!mounted) return;
        final messageType = isObject(parsed) && parsed is Map<String, dynamic> && parsed['type'] is String
            ? parsed['type'] as String
            : null;

        if (messageType == 'debug') {
          final env = parsed is Map<String, dynamic> ? parsed : null;
          final rawDebug = env != null && env.containsKey('debug_message') ? env['debug_message'] : parsed;
          final merged = (env != null && isObject(rawDebug))
              ? <String, dynamic>{...env, ...(rawDebug as Map<String, dynamic>)}
              : rawDebug;
          String msg = 'debug';
          String? level, source, id, requestId;
          Map<String, dynamic>? payload;
          if (isObject(merged)) {
            final m = merged as Map<String, dynamic>;
            msg = m['message']?.toString() ?? 'debug';
            level = _normalizeDebugLevel(m['level']);
            source = m['source']?.toString();
            id = m['id']?.toString();
            requestId = m['request_id']?.toString();
            payload = isObject(m['payload']) ? m['payload'] as Map<String, dynamic> : null;
          }
          setState(() {
            _debugMessages.add(DebugEntry(
              data: DebugMessage(
                  id: id, requestId: requestId, message: msg,
                  source: source, level: level, payload: payload),
            ));
            _isStreaming = false;
          });
          return;
        }

        if (messageType == 'status' || _isStatusMessage(parsed)) {
          final statusMsg = (parsed as Map<String, dynamic>)['message']?.toString() ?? '';
          setState(() {
            _updateAssistant(assistantId, (m) => m.copyWith(statusText: statusMsg));
            _isStreaming = false;
          });
          return;
        }

        if (messageType == 'missing_info') {
          final missingText = _extractMissingInfoText(parsed) ?? '';
          if (parsed != null) {
            final pid = _extractPromptId(parsed);
            if (pid != null) _lastPromptId = pid;
          }
          setState(() {
            _updateAssistant(assistantId, (m) => m.copyWith(
                missingInfoText: missingText, clearStatusText: true));
            _isStreaming = false;
          });
          return;
        }

        // Default: trip/json block
        final newBlock = parsed != null
            ? TripBlock(type: 'json', data: parsed)
            : TripBlock(type: 'text', data: rawData);
        if (parsed != null) {
          final pid = _extractPromptId(parsed);
          if (pid != null) _lastPromptId = pid;
        }
        setState(() {
          _updateAssistant(assistantId, (m) {
            final blocks = List<TripBlock>.from(m.blocks)..add(newBlock);
            return m.copyWith(blocks: blocks, clearStatusText: true);
          });
          _isStreaming = false;
        });
      },
      onError: () {
        if (!mounted) return;
        setState(() {
          _isConnecting = false;
          _isStreaming = false;
          _updateAssistant(assistantId, (m) {
            final blocks = List<TripBlock>.from(m.blocks)
              ..add(const TripBlock(type: 'text', data: '⚠️ Connection error. Please try again.'));
            return m.copyWith(blocks: blocks);
          });
        });
        _syncWaveAnimation();
      },
      onClose: () {
        if (!mounted) return;
        setState(() { _isConnecting = false; _isStreaming = false; });
        _syncWaveAnimation();
      },
    );
  }

  void _updateAssistant(String id, Message Function(Message) updater) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx >= 0) _messages[idx] = updater(_messages[idx]);
  }

  void _copyToClipboard(String text, String key) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedKey = key);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedKey = null);
    });
  }

  void _openTripModal(dynamic data) {
    setState(() => _tripModalData = data);
  }

  void _showDebugSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: const Text('Debug',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground)),
            ),
            Expanded(
              child: _debugMessages.isEmpty
                  ? const Center(
                      child: Text('Waiting for debug messages...',
                          style: TextStyle(fontSize: 14, color: AppColors.muted)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _debugMessages.length,
                      itemBuilder: (context, index) => _buildDebugEntry(_debugMessages[index]),
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _isDebugOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildTripSection()),
                _buildInputArea(),
              ],
            ),
            if (_tripModalData != null) _buildTripModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Text('LifeTravel Chat',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.foreground)),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _isDebugOpen = !_isDebugOpen);
              if (_isDebugOpen) _showDebugSheet();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
                color: _isDebugOpen ? AppColors.accent : AppColors.surface,
              ),
              child: Text(
                _isDebugOpen ? 'Debug on' : 'Debug',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.foreground),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const Text('Trip',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
        ),
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
            child: const Icon(Icons.chat_bubble_outline, color: AppColors.muted, size: 28),
          ),
          const SizedBox(height: 12),
          const Text("Hi, I'm your personal travel assistant.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.center,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.85 : 0.95),
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.userBubble : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: isUser ? _buildUserContent(message) : _buildAssistantContent(message),
      ),
    );
  }

  Widget _buildUserContent(Message message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => _copyToClipboard(message.content, message.id),
            child: Text(
              _copiedKey == message.id ? 'Copied!' : 'Copy',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(message.content, style: const TextStyle(fontSize: 14, color: AppColors.foreground)),
      ],
    );
  }

  Widget _buildAssistantContent(Message message) {
    final blocks = message.blocks;
    final children = <Widget>[];

    if (blocks.isNotEmpty) {
      children.add(_AssistantBlocksView(
        message: message,
        copiedKey: _copiedKey,
        onCopy: _copyToClipboard,
        isConnecting: _isConnecting,
        isStreaming: _isStreaming,
        isDebugOpen: _isDebugOpen,
        onOpenTrip: _openTripModal,
      ));
    }

    if (message.missingInfoText != null && message.missingInfoText!.isNotEmpty) {
      children.add(Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background.withAlpha(130),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Missing information',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
            const SizedBox(height: 8),
            Text(message.missingInfoText!,
                style: const TextStyle(fontSize: 14, color: AppColors.foreground)),
          ],
        ),
      ));
    }

    if (blocks.isEmpty) {
      if (message.content.isNotEmpty) {
        children.add(Text(message.content, style: const TextStyle(fontSize: 14, color: AppColors.foreground)));
      }
      if ((_isConnecting || _isStreaming) && message.missingInfoText == null) {
        children.add(_PulseCursor());
      }
    }

    if (message.statusText != null && message.statusText!.isNotEmpty) {
      children.add(_AnimatedStatusBox(
        text: message.statusText!,
        animate: _isConnecting || _isStreaming,
        waveAnimation: _statusWaveController,
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildDebugEntry(DebugEntry entry) {
    final color = _debugLevelColor(entry.data.level);
    final correlationId = entry.data.id ?? entry.data.requestId;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.data.message, style: TextStyle(fontSize: 14, color: color)),
          if (entry.data.level != null || entry.data.source != null || correlationId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [entry.data.level, entry.data.source, correlationId]
                    .where((s) => s != null)
                    .join(' • '),
                style: TextStyle(fontSize: 12, color: color.withAlpha(200)),
              ),
            ),
          if (entry.data.payload != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(13),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(entry.data.payload),
                  style: TextStyle(fontSize: 12, color: color, fontFamily: 'monospace'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleSend() {
    _sendMessage();
    FocusScope.of(context).unfocus();
  }

  Widget _buildInputArea() {
    final canSend = _inputController.text.trim().isNotEmpty && !_isConnecting && !_isStreaming;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: AppColors.background,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                maxLines: 5,
                minLines: 1,
                enabled: !_isConnecting,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                style: const TextStyle(fontSize: 14, color: AppColors.foreground),
                decoration: const InputDecoration(
                  hintText: 'Describe your travel plan...',
                  hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: canSend ? _handleSend : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canSend ? AppColors.sendButton : AppColors.sendButton.withAlpha(100),
                ),
                child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripModal() {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => setState(() => _tripModalData = null),
          child: Container(
            color: Colors.black.withAlpha(153),
            child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text('Trip',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                          const Spacer(),
                          if (_isDebugOpen)
                            GestureDetector(
                              onTap: () => _copyToClipboard(
                                const JsonEncoder.withIndent('  ').convert(_tripModalData),
                                'trip-modal',
                              ),
                              child: Text(
                                _copiedKey == 'trip-modal' ? 'Copied!' : 'Copy',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _tripModalData = null),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                                color: AppColors.surface,
                              ),
                              child: const Icon(Icons.close, size: 16, color: AppColors.foreground),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: TripCard(data: _tripModalData, detailed: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _AssistantBlocksView extends StatefulWidget {
  final Message message;
  final String? copiedKey;
  final void Function(String text, String key) onCopy;
  final bool isConnecting;
  final bool isStreaming;
  final bool isDebugOpen;
  final void Function(dynamic data) onOpenTrip;

  const _AssistantBlocksView({
    required this.message,
    required this.copiedKey,
    required this.onCopy,
    required this.isConnecting,
    required this.isStreaming,
    required this.isDebugOpen,
    required this.onOpenTrip,
  });

  @override
  State<_AssistantBlocksView> createState() => _AssistantBlocksViewState();
}

class _AssistantBlocksViewState extends State<_AssistantBlocksView> {
  int _visibleTripCount = _tripPageSize;

  @override
  Widget build(BuildContext context) {
    final blocks = widget.message.blocks;
    final tripIndices = <int>[];
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].isJson && looksLikeTrip(blocks[i].data)) tripIndices.add(i);
    }
    final visibleTrips = tripIndices.take(_visibleTripCount).toSet();
    final hiddenCount = (tripIndices.length - _visibleTripCount).clamp(0, tripIndices.length);

    final widgets = <Widget>[];
    var i = 0;
    while (i < blocks.length) {
      final b = blocks[i];
      if (b.isJson && looksLikeTrip(b.data)) {
        // Collect consecutive trip blocks
        final runIndices = <int>[];
        while (i < blocks.length && blocks[i].isJson && looksLikeTrip(blocks[i].data)) {
          if (visibleTrips.contains(i)) runIndices.add(i);
          i++;
        }
        if (runIndices.isNotEmpty) {
          widgets.add(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: runIndices.map((idx) => _buildTripBlock(blocks[idx], idx)).toList(),
            ),
          );
        }
      } else if (b.isJson) {
        widgets.add(_buildJsonBlock(b, i));
        i++;
      } else {
        widgets.add(Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background.withAlpha(130),
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(b.data.toString(),
              style: const TextStyle(fontSize: 12, color: AppColors.foreground, fontFamily: 'monospace')),
        ));
        i++;
      }
    }

    if (hiddenCount > 0) {
      widgets.add(Center(
        child: GestureDetector(
          onTap: () => setState(() => _visibleTripCount += _tripPageSize),
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surface,
            ),
            child: Text('Show more… ($hiddenCount more)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
          ),
        ),
      ));
    }

    if (widget.isConnecting || widget.isStreaming) {
      widgets.add(_PulseCursor());
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildTripBlock(TripBlock block, int index) {
    return GestureDetector(
      onTap: () => widget.onOpenTrip(block.data),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppColors.background.withAlpha(130),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isDebugOpen)
              _CopyBar(
                blockKey: '${widget.message.id}-$index',
                data: block.data,
                copiedKey: widget.copiedKey,
                onCopy: widget.onCopy,
              ),
            AbsorbPointer(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TripCard(data: block.data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJsonBlock(TripBlock block, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withAlpha(130),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CopyBar(
            blockKey: '${widget.message.id}-$index',
            data: block.data,
            copiedKey: widget.copiedKey,
            onCopy: widget.onCopy,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: JsonViewer(data: block.data, defaultExpanded: true),
          ),
        ],
      ),
    );
  }
}

class _CopyBar extends StatelessWidget {
  final String blockKey;
  final dynamic data;
  final String? copiedKey;
  final void Function(String text, String key) onCopy;

  const _CopyBar({
    required this.blockKey,
    required this.data,
    required this.copiedKey,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () => onCopy(const JsonEncoder.withIndent('  ').convert(data), blockKey),
          child: Text(
            copiedKey == blockKey ? 'Copied!' : 'Copy',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _AnimatedStatusBox extends StatelessWidget {
  final String text;
  final bool animate;
  final AnimationController waveAnimation;

  const _AnimatedStatusBox({
    required this.text,
    required this.waveAnimation,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          if (animate)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: waveAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _WaveGradientPainter(waveAnimation.value),
                  );
                },
              ),
            )
          else
            Positioned.fill(
              child: ColoredBox(color: AppColors.background.withAlpha(130)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (animate)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent.withAlpha(180)),
                    ),
                  )
                else
                  const Icon(Icons.check_circle_outline, size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text,
                      style: const TextStyle(fontSize: 12, color: AppColors.foreground)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveGradientPainter extends CustomPainter {
  final double progress;
  _WaveGradientPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(full, Paint()..color = AppColors.surface);

    final waveW = size.width * 0.6;
    final left = -waveW + (size.width + waveW) * progress;
    final waveRect = Rect.fromLTWH(left, 0, waveW, size.height);

    canvas.save();
    canvas.clipRect(waveRect);
    canvas.drawRect(
      waveRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            AppColors.surface,
            Color(0xFF1A5C4A),
            Color(0xFF22896A),
            Color(0xFF1A5C4A),
            AppColors.surface,
          ],
        ).createShader(waveRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WaveGradientPainter oldDelegate) => oldDelegate.progress != progress;
}

class _PulseCursor extends StatefulWidget {
  @override
  State<_PulseCursor> createState() => _PulseCursorState();
}

class _PulseCursorState extends State<_PulseCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: const Text('▊', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
        );
      },
    );
  }
}
