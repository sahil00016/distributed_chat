import 'dart:async';
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
import '../models/chat_type.dart';

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
  final Set<String> _selectedMessageIds = {};
  bool _isUploading = false;
  bool _isLoadingHistory = true;
  String? _currentUserId;
  String? _currentUsername;
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<List<User>>? _userListSubscription;
  StreamSubscription<FileData>? _fileDataSubscription;

  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;

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
    if (!mounted) return;
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
      
      if (!mounted) return;
      setState(() {
        _selectedMessageIds.clear();
        _messages
          ..clear()
          ..addAll(history.map((msg) {
            return Message(
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
            );
          }));
        _isLoadingHistory = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  void _setupListeners() {
    if (widget.socketService == null) return;
    
    _messageSubscription = widget.socketService!.messageStream.listen((message) {
      if (!mounted) return;
      setState(() {
        if (message.id != null) {
          _selectedMessageIds.remove(message.id);
        }
        _messages.add(
          Message(
            type: message.type,
            username: message.username,
            content: message.content,
            filename: message.filename,
            filesize: message.filesize,
            timestamp: message.timestamp,
            isMe: message.username == _currentUsername,
            messageType: message.messageType,
            fileUrl: message.fileUrl,
            fileType: message.fileType,
            thumbnailUrl: message.thumbnailUrl,
            id: message.id,
          ),
        );
      });
      _scrollToBottom();
    });

    _userListSubscription = widget.socketService!.userListStream.listen((users) {
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(users);
      });
    });

    _fileDataSubscription = widget.socketService!.fileDataStream.listen((fileData) {
      if (!mounted) return;
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

    widget.socketService?.sendChatMessage(content);
    _messageController.clear();
    
    try {
      if (widget.chatType == ChatType.group) {
        await SupabaseService.saveGroupMessage(
          senderId: _currentUserId ?? '',
          senderUsername: _currentUsername ?? '',
          groupId: widget.groupId,
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
      await _loadChatHistory();
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  Future<void> _pickAndSendFile() async {
    if (mounted) setState(() => _isUploading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'ppt', 'pptx'],
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) {
          setState(() => _isUploading = false);
        }
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final fileSize = result.files.single.size;
      final extension = fileName.split('.').last;
      final mimeType = _getMimeType(extension);
      final folder = SupabaseService.getFileCategory(mimeType);

      if (fileSize > 10 * 1024 * 1024) {
        if (mounted) {
          setState(() => _isUploading = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File too large. Maximum size is 10 MB.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final fileUrl = await SupabaseService.uploadFile(
        file: file,
        fileName: fileName,
        folder: folder,
      );

      final messageType = SupabaseService.isImageFile(mimeType) ? 'image' : 'document';

      if (widget.chatType == ChatType.group) {
        await SupabaseService.saveGroupMessage(
          senderId: _currentUserId ?? '',
          senderUsername: _currentUsername ?? '',
          groupId: widget.groupId,
          messageType: messageType,
          fileUrl: fileUrl,
        );
      } else {
        await SupabaseService.savePrivateMessage(
          senderId: _currentUserId ?? '',
          receiverId: widget.otherUserId ?? '',
          senderUsername: _currentUsername ?? '',
          messageType: messageType,
          fileUrl: fileUrl,
        );
      }

      final fileData = await file.readAsBytes();
      await widget.socketService?.sendFile(result.files.single.path!, fileData);
      await _loadChatHistory();
    } catch (e) {
      debugPrint('Error sending file: $e');
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

  void _toggleSelection(Message message) {
    if (message.id == null || !message.isMe) return;
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id!);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedMessageIds.clear());
  }

  Future<void> _deleteSelectedMessages() async {
    final ids = _selectedMessageIds.toList();
    if (ids.isEmpty) return;

    try {
      if (widget.chatType == ChatType.group) {
        await SupabaseService.deleteGroupMessages(ids);
      } else {
        await SupabaseService.deletePrivateMessages(ids);
      }

      if (!mounted) return;
      setState(() {
        _messages.removeWhere((msg) => msg.id != null && _selectedMessageIds.contains(msg.id));
        _selectedMessageIds.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messages deleted')),
      );
    } catch (e) {
      debugPrint('Error deleting messages: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
    }
  }

  void _disconnect() {
    if (_isSelectionMode) {
      _clearSelection();
      return;
    }
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
    _messageSubscription?.cancel();
    _userListSubscription?.cancel();
    _fileDataSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    widget.socketService?.disconnect();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_isSelectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text('${_selectedMessageIds.length} selected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteSelectedMessages,
          ),
        ],
      );
    }

    return AppBar(
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
        Builder(
          builder: (context) => IconButton(
            icon: Badge(
              label: Text('${_users.length}'),
              child: const Icon(Icons.people),
            ),
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _disconnect,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
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
                      final isSelected =
                          message.id != null && _selectedMessageIds.contains(message.id);

                      return GestureDetector(
                        onLongPress: () => _toggleSelection(message),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(message);
                          }
                        },
                        child: MessageBubble(
                          message: message,
                          showAvatar: showAvatar,
                          showUsername: showUsername,
                          isSelected: isSelected,
                        ),
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

