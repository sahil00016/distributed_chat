/// Application Configuration
/// Change these values to match your server setup
class AppConfig {
  // Default server configuration
  // CHANGE THIS to your PC's IP address for mobile demos
  static const String defaultHost = '192.168.1.44'; // Your PC IP
  static const int defaultPort = 5555;
  
  // App settings
  static const String appName = 'Distributed Chat';
  static const int minUsernameLength = 3;
  
  // Use localhost for desktop/web testing
  static String get localhostIP => '127.0.0.1';
  
  // Auto-detect best default based on platform
  static bool get isWeb => identical(0, 0.0);
  static String get recommendedHost => defaultHost; // Always use PC IP for demos
}

