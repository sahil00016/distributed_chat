# Distributed Chat Application with File Sharing

Full-stack distributed chat system with **Python (Backend)** and **Flutter (Frontend)** featuring real-time messaging and file sharing.

## Features

### Server (Python)
- Multi-client TCP socket server (100 concurrent clients)
- Real-time message broadcasting
- Binary file transfer
- Thread-safe operations

### Client (Flutter)
- Beautiful Material Design 3 UI
- Cross-platform (Android, iOS, Windows, Web)
- Real-time chat interface
- File sharing with picker

## Tech Stack

- **Backend:** Python 3.7+ (TCP sockets)
- **Frontend:** Flutter/Dart
- **Protocol:** TCP/IP with JSON
- **File Transfer:** Binary over TCP

## Quick Start

### 1. Start Server
```bash
cd server
python server.py
```

### 2. Run Client

**First time setup:**
```bash
cd client_flutter
flutter pub get
```

**Configure server IP** in `client_flutter/lib/config/app_config.dart`:
```dart
static const String defaultHost = '192.168.1.44'; // Your PC IP
```

**Run on device:**
```bash
flutter run -d <device>
```

**Build APK:**
```bash
flutter build apk --release
```

### 3. Windows Firewall (Required for mobile)
Run as Administrator:
```powershell
netsh advfirewall firewall add rule name="Python Chat Server" dir=in action=allow protocol=TCP localport=5555
```

## Project Structure

```
DPC_PROJECT/
├── server/
│   ├── server.py          # TCP server with threading
│   └── config.py          # Server configuration
├── client_flutter/
│   ├── lib/
│   │   ├── config/        # App configuration
│   │   ├── models/        # Data models
│   │   ├── services/      # Socket service
│   │   ├── screens/       # UI screens
│   │   └── widgets/       # Reusable widgets
│   └── pubspec.yaml
└── README.md
```

## How It Works

### Multi-Client Architecture
```
Clients (Android/iOS/Windows/Web)
              ↕
        TCP Socket (Port 5555)
              ↕
    Python Multi-threaded Server
```

### Communication Flow
1. Client connects via TCP socket
2. Server creates new thread for client
3. Messages broadcast to all connected clients
4. Files transferred as binary data

## Configuration

**Server** (`server/config.py`):
```python
HOST = '0.0.0.0'
PORT = 5555
MAX_CLIENTS = 100
```

**Client** (`client_flutter/lib/config/app_config.dart`):
```dart
static const String defaultHost = '192.168.1.44';
static const int defaultPort = 5555;
```

## Troubleshooting

**Connection Failed:**
- Verify server is running
- Check firewall allows port 5555
- Use correct server IP (not 127.0.0.1 for mobile)
- Ensure phone and PC on same WiFi

**Android Build Errors:**
- Run `flutter clean && flutter pub get`
- Check NDK version in `android/app/build.gradle.kts`

**Find Your PC IP:**
```bash
# Windows
ipconfig

# Linux/Mac
ifconfig
```

## License

MIT License
