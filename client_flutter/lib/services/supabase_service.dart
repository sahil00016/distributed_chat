import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';
import '../models/group.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;
  
  // Save group message
  static Future<void> saveGroupMessage({
    required String senderId,
    required String senderUsername,
    required String groupId,
    String? content,
    String? messageType,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileType,
    String? thumbnailUrl,
  }) async {
    await _client.from('group_messages').insert({
      'sender_id': senderId,
      'sender_username': senderUsername,
      'group_id': groupId,
      'content': content,
      'message_type': messageType ?? 'text',
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'file_type': fileType,
      'thumbnail_url': thumbnailUrl,
    });
  }
  
  // Save private message
  static Future<void> savePrivateMessage({
    required String senderId,
    required String receiverId,
    required String senderUsername,
    String? content,
    String? messageType,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileType,
    String? thumbnailUrl,
  }) async {
    await _client.from('private_messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender_username': senderUsername,
      'content': content,
      'message_type': messageType ?? 'text',
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'file_type': fileType,
      'thumbnail_url': thumbnailUrl,
    });
  }
  
  // Load group messages
  static Future<List<Message>> loadGroupMessages({
    required String groupId,
    int limit = 50,
  }) async {
    final response = await _client
        .from('group_messages')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(limit);
    
    return (response as List)
        .map((msg) => Message.fromJson(msg))
        .toList()
        .reversed
        .toList();
  }
  
  // Load private messages between two users
  static Future<List<Message>> loadPrivateMessages({
    required String userId1,
    required String userId2,
    int limit = 50,
  }) async {
    final response = await _client
        .from('private_messages')
        .select()
        .or('sender_id.eq.$userId1,receiver_id.eq.$userId1')
        .or('sender_id.eq.$userId2,receiver_id.eq.$userId2')
        .order('created_at', ascending: false)
        .limit(limit);
    
    return (response as List)
        .map((msg) => Message.fromJson(msg))
        .toList()
        .reversed
        .toList();
  }
  
  // Upload file to Supabase Storage
  static Future<String> uploadFile({
    required File file,
    required String fileName,
    required String folder, // 'images' or 'documents'
  }) async {
    final bytes = await file.readAsBytes();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$folder/${timestamp}_$fileName';
    
    await _client.storage.from('chat-files').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
      ),
    );
    
    // Get public URL
    final url = _client.storage.from('chat-files').getPublicUrl(path);
    return url;
  }
  
  // Delete file from storage
  static Future<void> deleteFile(String filePath) async {
    await _client.storage.from('chat-files').remove([filePath]);
  }
  
  // Get file type category
  static String getFileCategory(String mimeType) {
    if (mimeType.startsWith('image/')) return 'images';
    return 'documents';
  }
  
  // Check if file is image
  static bool isImageFile(String mimeType) {
    return mimeType.startsWith('image/');
  }
  
  // Get file icon for documents
  static String getFileIcon(String? mimeType) {
    if (mimeType == null) return '📄';
    
    if (mimeType.contains('pdf')) return '📕';
    if (mimeType.contains('word') || mimeType.contains('document')) return '📘';
    if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) return '📙';
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) return '📗';
    if (mimeType.contains('zip') || mimeType.contains('rar')) return '📦';
    if (mimeType.contains('video')) return '🎥';
    if (mimeType.contains('audio')) return '🎵';
    
    return '📄';
  }
  
  // ============ GROUP MANAGEMENT ============
  
  // Load groups for a user
  static Future<List<ChatGroup>> loadUserGroups(String userId) async {
    final response = await _client
        .from('group_members')
        .select('group_id, chat_groups(id, name, created_by, created_at, is_default)')
        .eq('user_id', userId);
    
    List<ChatGroup> groups = [];
    for (var item in response as List) {
      final groupData = item['chat_groups'];
      if (groupData != null) {
        // Get unread count for this group
        final unreadCount = await getGroupUnreadCount(userId, groupData['id']);
        
        groups.add(ChatGroup(
          id: groupData['id'],
          name: groupData['name'],
          createdBy: groupData['created_by'],
          createdAt: DateTime.parse(groupData['created_at']),
          isDefault: groupData['is_default'] ?? false,
          unreadCount: unreadCount,
        ));
      }
    }
    
    // Sort: default group first, then by name
    groups.sort((a, b) {
      if (a.isDefault) return -1;
      if (b.isDefault) return 1;
      return a.name.compareTo(b.name);
    });
    
    return groups;
  }
  
  // Create a new group
  static Future<String> createGroup({
    required String name,
    required String createdBy,
    required List<String> memberIds,
  }) async {
    // Create group
    final groupResponse = await _client
        .from('chat_groups')
        .insert({
          'name': name,
          'created_by': createdBy,
        })
        .select()
        .single();
    
    final groupId = groupResponse['id'] as String;
    
    // Add members
    final memberInserts = memberIds.map((userId) => {
      'group_id': groupId,
      'user_id': userId,
    }).toList();
    
    await _client.from('group_members').insert(memberInserts);
    
    return groupId;
  }
  
  // Add member to group
  static Future<void> addGroupMember(String groupId, String userId) async {
    await _client.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
    });
  }
  
  // Get group members
  static Future<List<String>> getGroupMembers(String groupId) async {
    final response = await _client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);
    
    return (response as List).map((item) => item['user_id'] as String).toList();
  }
  
  // ============ UNREAD TRACKING ============
  
  // Get unread count for private messages
  static Future<int> getPrivateUnreadCount(String forUserId, String fromUserId) async {
    final response = await _client
        .from('private_messages')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('receiver_id', forUserId)
        .eq('sender_id', fromUserId)
        .eq('is_read', false);
    
    return response.count ?? 0;
  }
  
  // Get unread count for group messages
  static Future<int> getGroupUnreadCount(String userId, String groupId) async {
    // Get last read timestamp
    final readStatus = await _client
        .from('group_message_reads')
        .select('last_read_at')
        .eq('user_id', userId)
        .eq('group_id', groupId)
        .maybeSingle();
    
    DateTime lastRead = readStatus != null && readStatus['last_read_at'] != null
        ? DateTime.parse(readStatus['last_read_at'])
        : DateTime(1970);
    
    // Count unread messages
    final response = await _client
        .from('group_messages')
        .select('id', const FetchOptions(count: CountOption.exact))
        .eq('group_id', groupId)
        .neq('sender_id', userId)
        .gt('created_at', lastRead.toIso8601String());
    
    return response.count ?? 0;
  }
  
  // Mark group messages as read
  static Future<void> markGroupAsRead(String userId, String groupId) async {
    await _client.from('group_message_reads').upsert({
      'user_id': userId,
      'group_id': groupId,
      'last_read_at': DateTime.now().toIso8601String(),
    });
  }
  
  // Mark private messages as read
  static Future<void> markPrivateMessagesAsRead(String receiverId, String senderId) async {
    await _client
        .from('private_messages')
        .update({'is_read': true})
        .eq('receiver_id', receiverId)
        .eq('sender_id', senderId)
        .eq('is_read', false);
  }
}

