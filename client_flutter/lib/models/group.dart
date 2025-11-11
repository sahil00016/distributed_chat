class ChatGroup {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final bool isDefault;
  final int unreadCount;
  final List<String> memberIds;

  ChatGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.isDefault = false,
    this.unreadCount = 0,
    this.memberIds = const [],
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isDefault: json['is_default'] as bool? ?? false,
      unreadCount: json['unread_count'] as int? ?? 0,
      memberIds: json['member_ids'] != null
          ? List<String>.from(json['member_ids'] as List)
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'is_default': isDefault,
    };
  }
}

