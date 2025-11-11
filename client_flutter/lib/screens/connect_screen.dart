import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../config/app_config.dart';
import 'chat_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController(text: AppConfig.defaultHost);
  final _portController = TextEditingController(text: AppConfig.defaultPort.toString());
  final _usernameController = TextEditingController();
  bool _isConnecting = false;
  bool _showAdvanced = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isConnecting = true);

    final host = _hostController.text.trim();
    final port = int.parse(_portController.text.trim());
    final username = _usernameController.text.trim();

    final socketService = SocketService();
    final success = await socketService.connect(host, port, username);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ChatScreen(socketService: socketService),
        ),
      );
    } else {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to server'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Distributed Chat',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect to start chatting',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Your Name',
                            hintText: 'Enter your name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _connect(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.trim().length < AppConfig.minUsernameLength) {
                              return 'Name must be at least ${AppConfig.minUsernameLength} characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Advanced settings toggle
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _showAdvanced = !_showAdvanced);
                          },
                          icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
                          label: Text(_showAdvanced ? 'Hide Advanced Settings' : 'Advanced Settings'),
                        ),
                        
                        // Advanced settings section
                        if (_showAdvanced) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Server Configuration',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _hostController,
                            decoration: const InputDecoration(
                              labelText: 'Server Host',
                              hintText: '192.168.1.44',
                              prefixIcon: Icon(Icons.dns),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter server host';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Server Port',
                              hintText: '5555',
                              prefixIcon: Icon(Icons.settings_ethernet),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter server port';
                              }
                              final port = int.tryParse(value.trim());
                              if (port == null || port < 1 || port > 65535) {
                                return 'Invalid port number';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connect,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isConnecting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Connect',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

