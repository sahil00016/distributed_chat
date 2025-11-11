import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/user.dart';

class SocketService extends ChangeNotifier {
  Socket? _socket;
  String? _username;
  bool _isConnected = false;
  
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  final StreamController<List<User>> _userListController = StreamController<List<User>>.broadcast();
  final StreamController<FileData> _fileDataController = StreamController<FileData>.broadcast();
  
  Stream<Message> get messageStream => _messageController.stream;
  Stream<List<User>> get userListStream => _userListController.stream;
  Stream<FileData> get fileDataStream => _fileDataController.stream;
  
  bool get isConnected => _isConnected;
  String? get username => _username;

  Future<bool> connect(String host, int port, String username) async {
    try {
      _socket = await Socket.connect(host, port);
      _username = username;
      _isConnected = true;
      
      // Send connect message
      final connectMsg = {
        'type': 'connect',
        'username': username,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _sendMessage(connectMsg);
      
      // Listen to server messages
      _socket!.listen(
        _handleServerData,
        onError: (error) {
          debugPrint('Socket error: $error');
          disconnect();
        },
        onDone: () {
          debugPrint('Connection closed');
          disconnect();
        },
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Connection error: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  void _handleServerData(Uint8List data) {
    try {
      final jsonString = utf8.decode(data);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final type = jsonData['type'] as String;
      
      switch (type) {
        case 'connect_success':
        case 'user_joined':
        case 'user_left':
        case 'message':
        case 'file_notification':
        case 'server_shutdown':
          final message = Message.fromJson(jsonData);
          _messageController.add(message);
          break;
          
        case 'user_list':
          final userList = (jsonData['users'] as List)
              .map((username) => User.fromString(username as String))
              .toList();
          _userListController.add(userList);
          break;
          
        case 'file_data':
          // File data follows this message
          final filename = jsonData['filename'] as String;
          final filesize = jsonData['filesize'] as int;
          _receiveFileData(filename, filesize);
          break;
      }
    } catch (e) {
      debugPrint('Error handling server data: $e');
    }
  }

  void _receiveFileData(String filename, int filesize) {
    // Note: In a real implementation, we'd need to handle this differently
    // as the file data comes after the JSON message
    // For this implementation, we'll emit an event that file is available
    _fileDataController.add(FileData(filename: filename, size: filesize));
  }

  void sendChatMessage(String content) {
    if (!_isConnected || content.trim().isEmpty) return;
    
    final message = {
      'type': 'message',
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _sendMessage(message);
  }

  Future<void> sendFile(String filepath, Uint8List fileData) async {
    if (!_isConnected) return;
    
    try {
      final filename = filepath.split('/').last;
      final filesize = fileData.length;
      
      // Send file request
      final fileRequest = {
        'type': 'file_request',
        'filename': filename,
        'filesize': filesize,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _sendMessage(fileRequest);
      
      // Send file data
      await Future.delayed(const Duration(milliseconds: 100));
      _socket?.add(fileData);
      
      debugPrint('File sent: $filename ($filesize bytes)');
    } catch (e) {
      debugPrint('Error sending file: $e');
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_socket == null || !_isConnected) return;
    
    try {
      final jsonString = jsonEncode(message);
      _socket!.write(jsonString);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void disconnect() {
    if (_isConnected) {
      try {
        final disconnectMsg = {
          'type': 'disconnect',
          'timestamp': DateTime.now().toIso8601String(),
        };
        _sendMessage(disconnectMsg);
      } catch (e) {
        debugPrint('Error sending disconnect message: $e');
      }
    }
    
    _socket?.destroy();
    _socket = null;
    _isConnected = false;
    _username = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    _userListController.close();
    _fileDataController.close();
    super.dispose();
  }
}

class FileData {
  final String filename;
  final int size;
  
  FileData({required this.filename, required this.size});
}

