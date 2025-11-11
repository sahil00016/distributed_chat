import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/supabase_service.dart';
import 'full_screen_image.dart';

class MessageMediaWidget extends StatelessWidget {
  final Message message;

  const MessageMediaWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isImageMessage) {
      return _buildImagePreview(context);
    } else if (message.isDocumentMessage) {
      return _buildDocumentPreview(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildImagePreview(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenImage(
              imageUrl: message.fileUrl!,
              filename: message.filename ?? 'Image',
            ),
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 300,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Image
              Image.network(
                message.fileUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 250,
                    height: 200,
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 250,
                    height: 200,
                    color: Colors.grey.shade300,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Failed to load image'),
                      ],
                    ),
                  );
                },
              ),
              // Tap indicator
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Tap to view',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentPreview(BuildContext context) {
    final icon = SupabaseService.getFileIcon(message.fileType);
    final size = message.filesize != null
        ? _formatFileSize(message.filesize!)
        : 'Unknown size';

    return Container(
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isMe
            ? Colors.white.withOpacity(0.2)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: message.isMe
              ? Colors.white.withOpacity(0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          // File icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.isMe ? Colors.white.withOpacity(0.2) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(width: 12),
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.filename ?? 'Document',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: message.isMe ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  size,
                  style: TextStyle(
                    fontSize: 12,
                    color: message.isMe
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Download button
          IconButton(
            icon: Icon(
              Icons.download_rounded,
              color: message.isMe ? Colors.white : Colors.blue,
            ),
            onPressed: () {
              // Open URL in browser to download
              // You can use url_launcher package for this
              debugPrint('Download: ${message.fileUrl}');
            },
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

