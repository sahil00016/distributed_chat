import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/socket_service.dart';
import '../services/supabase_service.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../widgets/message_bubble.dart';
import '../widgets/user_list_drawer.dart';
import 'chat_list_screen.dart';

class ChatScreen extends StatefulWidget {
  final SocketService? socketService;
  final ChatType chatType;
  final String chatTitle;
  final String? otherUserId;
  final String? groupId;

  const ChatScreen({
    super.key,
    this.socketService,
    required this.chatType,
    required this.chatTitle,
    this.otherUserId,
    this.groupId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Message> _messages = [];
  final List<User> _users = [];
  bool _isUploading = false;
  bool _isLoadingHistory = true;
  String? _currentUserId;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupListeners();
  }
  
  Future<void> _initialize() async {
    await _loadUserData();
    await _loadChatHistory();
  }
  
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId');
      _currentUsername = prefs.getString('username');
    });
  }
  
  Future<void> _loadChatHistory() async {
    try {
      List<Message> history;
      
      if (widget.chatType == ChatType.group) {
        if (widget.groupId == null) {
          debugPrint('Error: Group ID not available for group chat');
          setState(() => _isLoadingHistory = false);
          return;
        }
        history = await SupabaseService.loadGroupMessages(groupId: widget.groupId!);
      } else {
        if (_currentUserId == null || widget.otherUserId == null) {
          debugPrint('Error: User IDs not available for private chat');
          setState(() => _isLoadingHistory = false);
          return;
        }
        history = await SupabaseService.loadPrivateMessages(
          userId1: _currentUserId!,
          userId2: widget.otherUserId!,
        );
      }
      
      setState(() {
        _messages.clear();
        for (var msg in history) {
          _messages.add(Message(
            type: msg.type,
            username: msg.username,
            content: msg.content,
            filename: msg.filename,
            filesize: msg.filesize,
            timestamp: msg.timestamp,
            isMe: msg.username == _currentUsername,
            messageType: msg.messageType,
            fileUrl: msg.fileUrl,
            fileType: msg.fileType,
            thumbnailUrl: msg.thumbnailUrl,
            id: msg.id,
          ));
        }
        _isLoadingHistory = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  void _setupListeners() {
    if (widget.socketService == null) return;
    
    // Listen to messages
    widget.socketService!.messageStream.listen((message) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    });

    // Listen to user list updates
    widget.socketService!.userListStream.listen((users) {
      setState(() {
        _users.clear();
        _users.addAll(users);
      });
    });

    // Listen to file data
    widget.socketService!.fileDataStream.listen((fileData) {
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // Send via socket for real-time (if available)
    widget.socketService?.sendChatMessage(content);
    _messageController.clear();
    
    // Save to Supabase for persistence
    try {
      if (widget.chatType == ChatType.group) {
        await SupabaseService.saveGroupMessage(
          senderId: _currentUserId ?? '',
          senderUsername: _currentUsername ?? '',
          groupId: widget.groupId ?? '',
          content: content,
          messageType: 'text',
        );
      } else {
        await SupabaseService.savePrivateMessage(
          senderId: _currentUserId ?? '',
          receiverId: widget.otherUserId ?? '',
          senderUsername: _currentUsername ?? '',
          content: content,
          messageType: 'text',
        );
      }
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      setState(() => _isUploading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;
        final mimeType = result.files.single.extension != null
            ? _getMimeType(result.files.single.extension!)
            : 'application/octet-stream';
        
        // Upload to Supabase Storage
        final folder = SupabaseService.getFileCategory(mimeType);
        final fileUrl = await SupabaseService.uploadFile(
          file: file,
          fileName: fileName,
          folder: folder,
        );
        
        final messageType = SupabaseService.isImageFile(mimeType) ? 'image' : 'document';
        
        // Save to Supabase database
        if (widget.chatType == ChatType.group) {
          await SupabaseService.saveGroupMessage(
            senderId: _currentUserId ?? '',
            senderUsername: _currentUsername ?? '',
            groupId: widget.groupId ?? '',
            messageType: messageType,
            fileUrl: fileUrl,
            fileName: fileName,
            fileSize: fileSize,
            fileType: mimeType,
          );
        } else {
          await SupabaseService.savePrivateMessage(
            senderId: _currentUserId ?? '',
            receiverId: widget.otherUserId ?? '',
            senderUsername: _currentUsername ?? '',
            messageType: messageType,
            fileUrl: fileUrl,
            fileName: fileName,
            fileSize: fileSize,
            fileType: mimeType,
          );
        }
        
        // Also send via socket for real-time (optional)
        final fileData = await file.readAsBytes();
        await widget.socketService?.sendFile(result.files.single.path!, fileData);
        
        // Add to local messages for immediate display
        setState(() {
          _messages.add(Message(
            type: 'message',
            username: _currentUsername,
            timestamp: DateTime.now(),
            isMe: true,
            messageType: messageType,
            fileUrl: fileUrl,
            filename: fileName,
            filesize: fileSize,
            fileType: mimeType,
          ));
        });
        
        _scrollToBottom();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${messageType == 'image' ? 'Image' : 'File'} sent: $fileName'),
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
  
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
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
              widget.socketService?.disconnect();
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
            Text(
              widget.chatTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.chatType == ChatType.group
                  ? '${_users.length} members'
                  : 'Private Chat',
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
          if (widget.socketService != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: widget.socketService!.isConnected
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              child: Row(
                children: [
                  Icon(
                    widget.socketService!.isConnected
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 12,
                    color: widget.socketService!.isConnected
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.socketService!.isConnected
                        ? 'Connected'
                        : 'Disconnected',
                    style: TextStyle(
                      color: widget.socketService!.isConnected
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
            child: _isLoadingHistory
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading messages...'),
                      ],
                    ),
                  )
                : _messages.isEmpty
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

