import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final bool showUsername;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.showUsername = true,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isSystemMessage) {
      return _buildSystemMessage(context);
    }

    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar ? 8 : 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMe) ...[
            SizedBox(
              width: 32,
              child: showAvatar
                  ? CircleAvatar(
                      radius: 16,
                      backgroundColor: _getColorForUsername(message.username ?? ''),
                      child: Text(
                        (message.username ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showUsername && !message.isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      message.username ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _getColorForUsername(message.username ?? ''),
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: message.isMe
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(message.isMe || !showAvatar ? 18 : 4),
                      topRight: Radius.circular(message.isMe && showAvatar ? 4 : 18),
                      bottomLeft: const Radius.circular(18),
                      bottomRight: const Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          color: message.isMe
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: message.isMe
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimary
                                      .withOpacity(0.7)
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.7),
                            ),
                          ),
                          if (message.isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all,
                              size: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withOpacity(0.7),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (message.isMe) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: showAvatar
                  ? CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        (message.username ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getColorForSystemMessage().withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForSystemMessage(),
                  size: 14,
                  color: _getColorForSystemMessage(),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message.displayMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForSystemMessage() {
    switch (message.type) {
      case 'user_joined':
        return Colors.green;
      case 'user_left':
        return Colors.orange;
      case 'file_notification':
        return Colors.blue;
      case 'connect_success':
        return Colors.green;
      case 'server_shutdown':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForSystemMessage() {
    switch (message.type) {
      case 'user_joined':
        return Icons.login;
      case 'user_left':
        return Icons.logout;
      case 'file_notification':
        return Icons.attach_file;
      case 'connect_success':
        return Icons.check_circle;
      case 'server_shutdown':
        return Icons.warning;
      default:
        return Icons.info;
    }
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

