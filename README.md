# Distributed Chat Application with File Sharing

Full-stack distributed chat system with **Python (Backend)** and **Flutter (Frontend)** featuring real-time messaging, file sharing, and **Supabase integration** for user management and private messaging.

## 🌟 Features

### Server (Python)
- Multi-client TCP socket server (100 concurrent clients)
- Real-time message broadcasting
- Binary file transfer
- Thread-safe operations
- Support for group and private messaging

### Client (Flutter)
- **Beautiful Splash Screen** with animations
- **Username Registration** with Supabase
- **Persistent Authentication** (login once)
- **Chat List** showing:
  - Group chat (all users)
  - Private chats (1-on-1)
- Beautiful Material Design 3 UI
- Cross-platform (Android, iOS, Windows, Web)
- Real-time chat interface
- File sharing with picker
- Online/offline status
- Smart message grouping

### Database (Supabase)
- User registration and management
- Unique username validation
- Online/offline status tracking
- Private message storage (coming soon)
- Real-time updates

## Tech Stack

- **Backend:** Python 3.7+ (TCP sockets)
- **Frontend:** Flutter/Dart
- **Database:** Supabase (PostgreSQL)
- **Protocol:** TCP/IP with JSON
- **File Transfer:** Binary over TCP
- **Auth:** Persistent local storage

## Quick Start

### 1. Setup Supabase

**Important:** Set up Supabase first before running the app!

Follow the complete guide: [SUPABASE_SETUP.md](SUPABASE_SETUP.md)

**Quick Summary:**
1. Create Supabase project at [supabase.com](https://supabase.com)
2. Run the SQL schema (provided in guide)
3. Copy your Project URL and anon key
4. Update `client_flutter/lib/config/supabase_config.dart`

### 2. Start Server
```bash
cd server
python server.py
```

### 3. Run Client

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

### 4. Windows Firewall (Required for mobile)
Run as Administrator:
```powershell
netsh advfirewall firewall add rule name="Python Chat Server" dir=in action=allow protocol=TCP localport=5555
```

## App Flow

```
Splash Screen (2s)
        ↓
Username Setup (Register with Supabase)
        ↓
Chat List Screen
   ├── Group Chat → Connect to server → Group chat with all users
   └── User List → Select user → Private chat with that user
```

## Features in Detail

### 1. **Splash Screen** 
- Beautiful animated intro
- Checks if user already registered
- Auto-navigates to correct screen

### 2. **Username Registration**
- Register unique username with Supabase
- Validation (3-20 chars, alphanumeric + underscore)
- One-time setup (stored locally)
- Username uniqueness verified

### 3. **Chat List**
- **Group Chat Card**: Chat with all registered users
- **Private Chats**: List of all users from Supabase
- Online/offline indicators
- Pull to refresh user list
- Logout option

### 4. **Group Chat**
- Real-time messaging with all users
- File sharing with everyone
- See all online members
- Smart message grouping

### 5. **Private Chat** 
- 1-on-1 messaging with any user
- Dedicated chat window per user
- File sharing in private chat
- WhatsApp-like interface

## Project Structure

```
DPC_PROJECT/
├── server/
│   ├── server.py          # TCP server with threading
│   └── config.py          # Server configuration
├── client_flutter/
│   ├── lib/
│   │   ├── config/
│   │   │   ├── app_config.dart      # App settings
│   │   │   └── supabase_config.dart # Supabase credentials
│   │   ├── models/        # Data models
│   │   ├── services/      # Socket service
│   │   ├── screens/
│   │   │   ├── splash_screen.dart       # Splash screen
│   │   │   ├── username_setup_screen.dart # Registration
│   │   │   ├── chat_list_screen.dart    # Home screen
│   │   │   ├── chat_screen.dart         # Chat interface
│   │   │   └── connect_screen.dart      # Legacy
│   │   └── widgets/       # Reusable widgets
│   └── pubspec.yaml
├── README.md
└── SUPABASE_SETUP.md      # Complete Supabase guide
```

## How It Works

### Architecture
```
Flutter App
     ↓ (Supabase)
  User Management
     ↓ (TCP Socket)
  Python Server
     ↓
  Multi-threaded Broadcasting
     ↓
  All Connected Clients
```

### Communication Flow
1. User registers username → Saved to Supabase
2. App opens → Loads users from Supabase
3. User clicks Group Chat → Connects to TCP server
4. User clicks Private Chat → Connects with user identifier
5. Messages broadcast in real-time via TCP
6. Files transferred as binary data

## Configuration

### Server (`server/config.py`):
```python
HOST = '0.0.0.0'
PORT = 5555
MAX_CLIENTS = 100
```

### Client (`client_flutter/lib/config/app_config.dart`):
```dart
static const String defaultHost = '192.168.1.44';
static const int defaultPort = 5555;
```

### Supabase (`client_flutter/lib/config/supabase_config.dart`):
```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

## Troubleshooting

### Supabase Issues
- **"Failed to initialize"**: Check URL and anon key in config
- **"Username taken"**: Choose different username
- **"Can't see users"**: Check Supabase table has data

### Connection Issues
- Verify server is running
- Check firewall allows port 5555
- Use correct server IP (not 127.0.0.1 for mobile)
- Ensure phone and PC on same WiFi

### Build Issues
- Run `flutter clean && flutter pub get`
- Check NDK version in `android/app/build.gradle.kts`
- Update Flutter: `flutter upgrade`

### Find Your PC IP:
```bash
# Windows
ipconfig

# Linux/Mac
ifconfig
```

## What's New

### ✨ Latest Features:
- 🎨 **Splash Screen** with smooth animations
- 👤 **Supabase Integration** for user management
- 💾 **Persistent Login** (register once)
- 📋 **Chat List** like WhatsApp
- 💬 **Private Messaging** (1-on-1 chats)
- 🟢 **Online Status** indicators
- 🎯 **Smart Message Grouping**
- 🎨 **Modern UI** with gradients and shadows

## Coming Soon

- [ ] Private message history in Supabase
- [ ] Typing indicators
- [ ] Read receipts
- [ ] Message reactions
- [ ] Push notifications
- [ ] Voice messages
- [ ] Group creation
- [ ] User profiles with avatars

## Database Schema

```sql
chat_users:
- id (UUID, Primary Key)
- username (TEXT, Unique)
- created_at (TIMESTAMP)
- is_online (BOOLEAN)
- last_seen (TIMESTAMP)

private_messages:
- id (UUID, Primary Key)
- sender_id (FK → chat_users)
- receiver_id (FK → chat_users)
- content (TEXT)
- created_at (TIMESTAMP)
- is_read (BOOLEAN)
```

## Screenshots Flow

1. **Splash Screen** → Animated logo + loading
2. **Username Setup** → One-time registration
3. **Chat List** → Group + Users list
4. **Group Chat** → Multi-user messaging
5. **Private Chat** → 1-on-1 conversations

## License

MIT License

## Repository

🔗 [GitHub - distributed_chat](https://github.com/sahil00016/distributed_chat)

---

**Built with ❤️ using Python, Flutter & Supabase**
