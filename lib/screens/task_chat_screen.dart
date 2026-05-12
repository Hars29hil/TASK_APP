import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TaskChatScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  const TaskChatScreen({super.key, required this.taskId, required this.taskTitle});
  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  final _supabase = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _channel;

  String get _backendUrl => dotenv.maybeGet('BACKEND_URL') ?? 'http://10.0.2.2:5000';
  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _channel = _supabase.channel('task-chat-${widget.taskId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'task_group_messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'task_id', value: widget.taskId),
        callback: (_) => _fetchMessages(),
      )
      .subscribe();
  }

  Future<void> _fetchMessages() async {
    try {
      final resp = await http.get(Uri.parse('$_backendUrl/tasks/${widget.taskId}/messages'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true && mounted) {
          setState(() { _messages = List<Map<String, dynamic>>.from(data['messages']); _isLoading = false; });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    setState(() => _isSending = true);
    try {
      await http.post(
        Uri.parse('$_backendUrl/tasks/${widget.taskId}/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sender_id': _currentUserId, 'content': text}),
      );
    } catch (e) {
      debugPrint("Send error: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A00E0), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.taskTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Text("Task Group Chat", style: TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        actions: [
          CircleAvatar(radius: 18, backgroundColor: Colors.white.withValues(alpha: 0.2), child: const Icon(Icons.group_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A00E0)))
            : _messages.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text("No messages yet", style: TextStyle(color: Colors.grey[400])),
                ]))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) => _buildMessage(_messages[i]),
                ),
        ),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == _currentUserId;
    final profile = msg['profiles'];
    final name = profile?['full_name'] ?? 'User';
    final content = msg['content'] ?? '';
    final time = _formatTime(msg['created_at']);
    final isSystem = content.startsWith('📋') || content.startsWith('✅') || content.startsWith('🎉');

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF4A00E0).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
        child: Text(content, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic)),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          if (!isMe) Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 10, backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${msg['sender_id']}')),
              const SizedBox(width: 6),
              Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF4A00E0) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(content, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
              const SizedBox(height: 4),
              Text(time, style: TextStyle(color: isMe ? Colors.white60 : Colors.grey[400], fontSize: 10)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildInputBar() => Container(
    padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3))]),
    child: Row(children: [
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(25)),
        child: TextField(
          controller: _msgCtrl,
          decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
          onSubmitted: (_) => _sendMessage(),
        ),
      )),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _isSending ? null : _sendMessage,
        child: Container(
          width: 45, height: 45,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)])),
          child: Icon(_isSending ? Icons.hourglass_top_rounded : Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return "$h:$m";
    } catch (_) { return ''; }
  }
}
