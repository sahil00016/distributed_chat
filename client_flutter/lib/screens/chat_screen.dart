import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../services/socket_service.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../widgets/message_bubble.dart';
import '../widgets/user_list_drawer.dart';

class ChatScreen extends StatefulWidget {
  final SocketService socketService;

  const ChatScreen({super.key, required this.socketService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Message> _messages = [];
  final List<User> _users = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to messages
    widget.socketService.messageStream.listen((message) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    });

    // Listen to user list updates
    widget.socketService.userListStream.listen((users) {
      setState(() {
        _users.clear();
        _users.addAll(users);
      });
    });

    // Listen to file data
    widget.socketService.fileDataStream.listen((fileData) {
      _showFileReceivedDialog(fileData.filename, fileData.size);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    widget.socketService.sendChatMessage(content);
    _messageController.clear();
  }

  Future<void> _pickAndSendFile() async {
    try {
      setState(() => _isUploading = true);

      final result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileData = await file.readAsBytes();

        await widget.socketService.sendFile(result.files.single.path!, fileData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File sent: ${result.files.single.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showFileReceivedDialog(String filename, int size) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Received'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filename: $filename'),
            const SizedBox(height: 8),
            Text('Size: ${_formatFileSize(size)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void _disconnect() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Are you sure you want to disconnect?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.socketService.disconnect();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distributed Chat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.socketService.username ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${_users.length}'),
              child: const Icon(Icons.people),
            ),
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _disconnect,
          ),
        ],
      ),
      endDrawer: UserListDrawer(users: _users),
      body: Column(
        children: [
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: widget.socketService.isConnected
                ? Colors.green.shade100
                : Colors.red.shade100,
            child: Row(
              children: [
                Icon(
                  widget.socketService.isConnected
                      ? Icons.circle
                      : Icons.circle_outlined,
                  size: 12,
                  color: widget.socketService.isConnected
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.socketService.isConnected
                      ? 'Connected'
                      : 'Disconnected',
                  style: TextStyle(
                    color: widget.socketService.isConnected
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No messages yet',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_users.length} ${_users.length == 1 ? 'user' : 'users'} online',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start the conversation! 💬',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final showAvatar = index == 0 ||
                          _messages[index - 1].username != message.username ||
                          _messages[index - 1].isSystemMessage ||
                          message.isSystemMessage;
                      final showUsername = showAvatar && !message.isMe && !message.isSystemMessage;
                      
                      return MessageBubble(
                        message: message,
                        showAvatar: showAvatar,
                        showUsername: showUsername,
                      );
                    },
                  ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isUploading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.attach_file_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      onPressed: _isUploading ? null : _pickAndSendFile,
                      tooltip: 'Send file',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      tooltip: 'Send message',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

