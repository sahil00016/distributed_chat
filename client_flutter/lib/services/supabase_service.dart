import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;
  
  // Save group message
  static Future<void> saveGroupMessage({
    required String senderId,
    required String senderUsername,
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
  static Future<List<Message>> loadGroupMessages({int limit = 50}) async {
    final response = await _client
        .from('group_messages')
        .select()
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
}

