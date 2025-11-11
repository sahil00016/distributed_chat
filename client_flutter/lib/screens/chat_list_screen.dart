import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/socket_service.dart';
import '../services/supabase_service.dart';
import '../models/group.dart';
import 'chat_screen.dart';
import 'username_setup_screen.dart';
import 'create_group_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String username;
  final String userId;

  const ChatListScreen({
    super.key,
    required this.username,
    required this.userId,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatGroup> _groups = [];
  List<Map<String, dynamic>> _allUsers = [];
  Map<String, int> _userUnreadCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setOnlineStatus(true);
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadGroups(),
      _loadUsers(),
    ]);
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await SupabaseService.loadUserGroups(widget.userId);
      setState(() {
        _groups = groups;
      });
    } catch (e) {
      debugPrint('Error loading groups: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await Supabase.instance.client
          .from('chat_users')
          .select()
          .neq('id', widget.userId)
          .order('username');

      final users = List<Map<String, dynamic>>.from(response);
      
      // Load unread counts for each user
      final Map<String, int> unreadCounts = {};
      for (var user in users) {
        final userId = user['id'] as String;
        final count = await SupabaseService.getPrivateUnreadCount(
          widget.userId,
          userId,
        );
        unreadCounts[userId] = count;
      }

      setState(() {
        _allUsers = users;
        _userUnreadCounts = unreadCounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    try {
      await Supabase.instance.client
          .from('chat_users')
          .update({'is_online': isOnline}).eq('id', widget.userId);
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  Future<void> _logout() async {
    await _setOnlineStatus(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const UsernameSetupScreen()),
      (route) => false,
    );
  }

  Future<void> _openGroupChat(ChatGroup group) async {
    final socketService = SocketService();
    final success = await socketService.connect(
      AppConfig.defaultHost,
      AppConfig.defaultPort,
      widget.username,
    );

    if (!mounted) return;

    if (success) {
      // Mark as read when opening
      await SupabaseService.markGroupAsRead(widget.userId, group.id);
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            socketService: socketService,
            chatType: ChatType.group,
            chatTitle: group.name,
            groupId: group.id,
          ),
        ),
      ).then((_) => _loadData()); // Refresh when returning
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to server'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openPrivateChat(String otherUsername, String otherUserId) async {
    final socketService = SocketService();
    final success = await socketService.connect(
      AppConfig.defaultHost,
      AppConfig.defaultPort,
      widget.username,
    );

    if (!mounted) return;

    if (success) {
      // Mark as read when opening
      await SupabaseService.markPrivateMessagesAsRead(widget.userId, otherUserId);
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            socketService: socketService,
            chatType: ChatType.private,
            chatTitle: otherUsername,
            otherUserId: otherUserId,
          ),
        ),
      ).then((_) => _loadData()); // Refresh when returning
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to server'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _setOnlineStatus(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chats',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '@${widget.username}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _logout,
                child: const Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  // Groups Section
                  if (_groups.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'GROUPS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => CreateGroupScreen(
                                    currentUserId: widget.userId,
                                    currentUsername: widget.username,
                                  ),
                                ),
                              ).then((_) => _loadData());
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('New'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...(_groups.map((group) {
                      final hasUnread = group.unreadCount > 0;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: hasUnread ? 3 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  group.isDefault
                                      ? Icons.groups_rounded
                                      : Icons.group,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              if (hasUnread)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    child: Text(
                                      '${group.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            group.name,
                            style: TextStyle(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            group.isDefault ? 'Public Group' : 'Private Group',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                          onTap: () => _openGroupChat(group),
                        ),
                      );
                    })),
                  ],

                  // Section Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'PRIVATE CHATS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  // Users List
                  if (_allUsers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No other users yet',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share the app with friends!',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...(_allUsers.map((user) {
                      final username = user['username'] as String;
                      final userId = user['id'] as String;
                      final isOnline = user['is_online'] as bool? ?? false;
                      final unreadCount = _userUnreadCounts[userId] ?? 0;
                      final hasUnread = unreadCount > 0;

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: _getColorForUsername(username),
                              child: Text(
                                username[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          username,
                          style: TextStyle(
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline ? Colors.green : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        trailing: hasUnread
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : Icon(
                                Icons.chat_bubble_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        onTap: () => _openPrivateChat(username, userId),
                      );
                    }).toList()),
                ],
              ),
            ),
    );
  }

  Color _getColorForUsername(String username) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    final hash = username.codeUnits.fold(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }
}

enum ChatType { group, private }

