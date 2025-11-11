class Message {
  final String type;
  final String? username;
  final String? content;
  final String? filename;
  final int? filesize;
  final DateTime timestamp;
  final bool isMe;
  final String? messageType; // 'text', 'image', 'document', 'file'
  final String? fileUrl;
  final String? fileType; // MIME type
  final String? thumbnailUrl;
  final String? id; // Supabase message ID

  Message({
    required this.type,
    this.username,
    this.content,
    this.filename,
    this.filesize,
    required this.timestamp,
    this.isMe = false,
    this.messageType,
    this.fileUrl,
    this.fileType,
    this.thumbnailUrl,
    this.id,
  });

  factory Message.fromJson(Map<String, dynamic> json, {bool isMe = false}) {
    return Message(
      type: json['type'] ?? '',
      username: json['username'] ?? json['sender_username'],
      content: json['content'],
      filename: json['filename'] ?? json['file_name'],
      filesize: json['filesize'] ?? json['file_size'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      isMe: isMe,
      messageType: json['message_type'],
      fileUrl: json['file_url'],
      fileType: json['file_type'],
      thumbnailUrl: json['thumbnail_url'],
      id: json['id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (username != null) 'username': username,
      if (content != null) 'content': content,
      if (filename != null) 'filename': filename,
      if (filesize != null) 'filesize': filesize,
      'timestamp': timestamp.toIso8601String(),
      if (messageType != null) 'message_type': messageType,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileType != null) 'file_type': fileType,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (id != null) 'id': id,
    };
  }
  
  bool get isImageMessage => messageType == 'image' && fileUrl != null;
  bool get isDocumentMessage => messageType == 'document' && fileUrl != null;

  bool get isSystemMessage =>
      type == 'user_joined' ||
      type == 'user_left' ||
      type == 'file_notification' ||
      type == 'connect_success' ||
      type == 'server_shutdown';

  bool get isChatMessage => type == 'message';

  bool get isFileNotification => type == 'file_notification';

  String get displayMessage {
    if (content != null) return content!;
    if (type == 'user_joined') return '$username joined the chat';
    if (type == 'user_left') return '$username left the chat';
    if (type == 'file_notification') return '$username sent a file: $filename';
    if (type == 'connect_success') return 'Connected successfully!';
    if (type == 'server_shutdown') return 'Server is shutting down';
    return '';
  }
}

