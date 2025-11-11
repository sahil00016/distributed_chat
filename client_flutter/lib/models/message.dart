class Message {
  final String type;
  final String? username;
  final String? content;
  final String? filename;
  final int? filesize;
  final DateTime timestamp;
  final bool isMe;

  Message({
    required this.type,
    this.username,
    this.content,
    this.filename,
    this.filesize,
    required this.timestamp,
    this.isMe = false,
  });

  factory Message.fromJson(Map<String, dynamic> json, {bool isMe = false}) {
    return Message(
      type: json['type'] ?? '',
      username: json['username'],
      content: json['content'],
      filename: json['filename'],
      filesize: json['filesize'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isMe: isMe,
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
    };
  }

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

