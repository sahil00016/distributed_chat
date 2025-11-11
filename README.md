# Distributed Chat Application with File Sharing

Full-stack distributed chat system with a **Python TCP socket backend**, a **Flutter client**, and **Supabase** for persistent storage. Chat in real time, share documents/images, see unread counts, and manage chats across multiple devices.

---

## ✨ Highlights

### Backend (Python)
- Multi-client TCP socket server (100 concurrent clients)
- Real-time JSON messaging & binary file streaming
- Works locally or when deployed to Railway/other VPS providers
- Environment-driven host/port configuration (`HOST`, `PORT`)

### Client (Flutter)
- Animated splash screen and one-time username registration
- Supabase-backed authentication with offline persistence
- Chat list with **group** & **private** conversations
- Unread badges, online presence, smart bubble grouping
- Inline image previews, document cards, and full-screen viewer
- **Multi-select delete** for your own messages (group/private)
- Cross-platform (Android, iOS, Windows, web)

### Supabase (PostgreSQL + Storage)
- `chat_users`, `group_messages`, `private_messages` tables
- Policies for inserts/selects/updates/deletes and unread tracking
- Supabase Storage bucket for shared files (images/docs)
- Functions to compute unread counts per user/conversation

---

## 🗂  Tech Stack

| Layer          | Technology |
|----------------|------------|
| Backend        | Python 3.x (sockets, threading)
| Client         | Flutter / Dart with Material Design 3
| Database       | Supabase (PostgreSQL + Storage)
| Transport      | TCP/IP (JSON + binary streams)
| Auth/Storage   | Supabase + shared preferences

---

## 🚀 Quick Start

### 1. Set up Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. Run the SQL from [`SUPABASE_UNREAD_AND_GROUPS.sql`](SUPABASE_UNREAD_AND_GROUPS.sql) (includes tables, policies, unread helpers, storage rules)
3. Create a public bucket `chat-files`
4. Copy the **Project URL** and **anon key**
5. Update `client_flutter/lib/config/supabase_config.dart`

> Need a guided setup? See [`SUPABASE_SETUP_V2.md`](SUPABASE_SETUP_V2.md).

### 2. Deploy the Socket Server (Railway example)

1. Connect the repo in [Railway](https://railway.app/)
2. In the service settings set:
   - **Root Directory:** `server`
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `python server.py`
3. Deploy and note the log message `Listening on 0.0.0.0:<port>`
4. Enable **TCP Proxy** and map the internal port (e.g. `8080`)
5. Railway will show a public endpoint such as `maglev.proxy.rlwy.net:50159`

> Any TCP-friendly host works (VPS, Fly.io, Render private service). Just expose the socket port.

### 3. Configure the Flutter Client

Update `client_flutter/lib/config/app_config.dart`:
```dart
class AppConfig {
  static const String defaultHost = 'maglev.proxy.rlwy.net';
  static const int defaultPort = 50159;
  static const String appName = 'Distributed Chat';
  static const int minUsernameLength = 3;
}
```
(Replace host/port with your deployment.)

### 4. Build & Share the APK

```bash
cd client_flutter
flutter clean
flutter pub get
flutter build apk --release
```

APK path: `client_flutter/build/app/outputs/flutter-apk/app-release.apk`

Share the APK (WhatsApp, Drive, etc.). Users must allow “Install from unknown sources”.

### 5. Run on Desktop or Emulator

```bash
flutter run -d <device>
```
(
Make sure the socket host is reachable; for local testing use `127.0.0.1`/`localhost`.)

---

## 📱 App Flow

```
Splash Screen → Username Setup → Chat List
                                ├─ Group Chat (all users)
                                └─ Private Chats (individual users)
```

- **Splash Screen** – animation + auto-login check
- **Username Setup** – Supabase uniqueness, stored locally
- **Chat List** – group + private cards, unread counters, pull-to-refresh, logout
- **Chat Screen** – inline media, message selection, multi-delete, unread updates

---

## 🔐 Message Deletion & Unread Tracking
- Long-press your own message, multi-select, tap delete (deletes in Supabase & UI)
- Supabase functions (`get_unread_private_count`, `get_unread_group_count`) power unread badges
- Policies in `SUPABASE_UNREAD_AND_GROUPS.sql` allow deletes/reads/inserts for public access

---

## 📁 Project Structure

```
DPC_PROJECT/
├── server/
│   ├── server.py          # Threaded TCP server
│   └── config.py          # HOST/PORT via env vars
├── client_flutter/
│   ├── lib/
│   │   ├── config/        # app + Supabase config
│   │   ├── models/        # Message, User, Group
│   │   ├── services/      # Socket + Supabase helpers
│   │   ├── screens/       # UI screens
│   │   └── widgets/       # Message bubbles, drawers, etc.
│   └── pubspec.yaml
├── README.md
├── SUPABASE_SETUP_V2.md
└── SUPABASE_UNREAD_AND_GROUPS.sql
```

---

## 🛠 Configuration Summary

### Server (`server/config.py`)
```python
HOST = os.getenv('HOST', '0.0.0.0')
PORT = int(os.getenv('PORT', '5555'))
MAX_CLIENTS = 100
```

### Client (`client_flutter/lib/config/app_config.dart`)
```dart
static const String defaultHost = 'maglev.proxy.rlwy.net';
static const int defaultPort = 50159;
```

### Supabase (`client_flutter/lib/config/supabase_config.dart`)
```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

---

## 🧰 Troubleshooting

### Cannot connect / “SocketException”
- Confirm Railway service is running and grab the **TCP proxy** host/port
- Ensure the APK uses the updated `AppConfig` values
- Check Supabase credentials (supabase_config.dart)
- If running locally: open firewall port, use your machine’s LAN IP

### Supabase errors
- Re-run `SUPABASE_UNREAD_AND_GROUPS.sql` to ensure tables/policies exist
- Confirm `chat-files` storage bucket is public
- Validate anon key & URL match the project

### Flutter build issues
- Run `flutter clean && flutter pub get`
- Confirm `flutter doctor` has no critical issues
- Ensure Android NDK version in `android/app/build.gradle.kts` matches your SDK

---

## 📦 Sharing the App
- Build release APK (`flutter build apk --release`)
- Send `app-release.apk` via WhatsApp/Drive/email
- Receiver enables “Install from unknown sources” and installs
- Both parties can chat from anywhere (Railway-hosted socket + Supabase backend)

---

## 🛣 Roadmap / Ideas
- Typing indicators & read receipts
- Push notifications
- Voice messages
- Enhanced admin tooling & audit logs

---

## 📄 License
MIT License

---

Built with ❤️ using Python, Flutter, and Supabase. Enjoy your distributed chat! 🚀
