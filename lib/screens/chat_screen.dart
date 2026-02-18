import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../models/session.dart';
import '../providers/chat_provider.dart';
import '../providers/gateway_provider.dart';

class ChatScreen extends StatefulWidget {
  final Session session;

  const ChatScreen({super.key, required this.session});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatProvider _chatProvider;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    final gw = context.read<GatewayProvider>();
    _chatProvider = ChatProvider(gw, widget.session.key);
    _chatProvider.addListener(_onMessagesChange);
  }

  void _onMessagesChange() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chatProvider.removeListener(_onMessagesChange);
    _chatProvider.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    setState(() => _isComposing = false);
    await _chatProvider.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.session.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (widget.session.model != null)
              Text(
                widget.session.model!,
                style: const TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        trailing: _chatProvider.isRunning
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _chatProvider.abortCurrent,
                child: const Icon(CupertinoIcons.stop_circle, color: CupertinoColors.systemRed),
              )
            : null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_chatProvider.loading)
              const SizedBox(
                height: 2,
                child: CupertinoActivityIndicator(),
              ),
            Expanded(
              child: _buildMessageList(),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_chatProvider.loading && _chatProvider.messages.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_chatProvider.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.session.kindEmoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              widget.session.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start the conversation',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _chatProvider.messages.length,
      itemBuilder: (ctx, i) => _MessageBubble(
        message: _chatProvider.messages[i],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
        color: CupertinoColors.systemBackground,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _inputController,
              placeholder: 'Message',
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onChanged: (v) => setState(() => _isComposing = v.trim().isNotEmpty),
              onSubmitted: (_) => _sendMessage(),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: _isComposing && !_chatProvider.isRunning
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _sendMessage,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.arrow_up,
                        color: CupertinoColors.white,
                        size: 18,
                      ),
                    ),
                  )
                : SizedBox(
                    width: 34,
                    height: 34,
                    child: _chatProvider.isRunning
                        ? const CupertinoActivityIndicator()
                        : null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isSystem = message.isSystem || message.isTool;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel,
                fontFamily: 'Menlo',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🦞', style: TextStyle(fontSize: 16)),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? CupertinoColors.systemBlue
                    : CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 15,
                      ),
                    )
                  : _AssistantContent(message: message),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantContent extends StatelessWidget {
  final ChatMessage message;

  const _AssistantContent({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isStreaming && message.content.isEmpty) {
      return const SizedBox(
        height: 20,
        child: CupertinoActivityIndicator(radius: 8),
      );
    }

    return MarkdownBody(
      data: message.content,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 15, color: CupertinoColors.label),
        code: const TextStyle(
          fontFamily: 'Menlo',
          fontSize: 13,
          backgroundColor: Color(0x1A000000),
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0x0F000000),
          borderRadius: BorderRadius.circular(8),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        blockquoteDecoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: CupertinoColors.systemGrey3, width: 3),
          ),
        ),
      ),
    );
  }
}
