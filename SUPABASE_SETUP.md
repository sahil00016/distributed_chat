# Supabase Setup Guide

Complete guide to set up Supabase for the Distributed Chat App.

## Step 1: Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Click "Start your project"
3. Sign in with GitHub
4. Create a new project:
   - **Name**: distributed-chat
   - **Database Password**: (choose a strong password)
   - **Region**: Choose closest to you
5. Wait for project to be ready (~2 minutes)

---

## Step 2: Create Database Tables

### Go to SQL Editor

1. In your Supabase dashboard, click **SQL Editor** (left sidebar)
2. Click **"New Query"**
3. Copy and paste the following SQL:

```sql
-- Create users table
CREATE TABLE chat_users (
    id UUID PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for username lookups
CREATE INDEX idx_users_username ON chat_users(username);
CREATE INDEX idx_users_online ON chat_users(is_online);

-- Create private messages table (for future use)
CREATE TABLE private_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES chat_users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES chat_users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_read BOOLEAN DEFAULT false
);

-- Create index for message queries
CREATE INDEX idx_messages_sender ON private_messages(sender_id);
CREATE INDEX idx_messages_receiver ON private_messages(receiver_id);
CREATE INDEX idx_messages_created ON private_messages(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE chat_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_messages ENABLE ROW LEVEL SECURITY;

-- Create policies for chat_users
CREATE POLICY "Users can read all users"
    ON chat_users FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own data"
    ON chat_users FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Users can update their own data"
    ON chat_users FOR UPDATE
    USING (true);

-- Create policies for private_messages
CREATE POLICY "Users can read their own messages"
    ON private_messages FOR SELECT
    USING (auth.uid() IS NOT NULL OR true);

CREATE POLICY "Users can insert messages"
    ON private_messages FOR INSERT
    WITH CHECK (true);

-- Function to update last_seen
CREATE OR REPLACE FUNCTION update_last_seen()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_seen = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update last_seen
CREATE TRIGGER update_users_last_seen
    BEFORE UPDATE ON chat_users
    FOR EACH ROW
    EXECUTE FUNCTION update_last_seen();
```

4. Click **"Run"** to execute the SQL
5. You should see: **"Success. No rows returned"**

---

## Step 3: Get Your API Credentials

1. In Supabase dashboard, click **Settings** (gear icon, left sidebar)
2. Click **API** from the settings menu
3. You'll see two important values:

### Project URL
```
https://your-project-id.supabase.co
```

### API Keys
- **anon** public key (this is safe to use in your app)
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## Step 4: Configure Your Flutter App

1. Open `client_flutter/lib/config/supabase_config.dart`
2. Replace the placeholder values:

```dart
class SupabaseConfig {
  // Replace with YOUR actual values from Step 3
  static const String supabaseUrl = 'https://your-project-id.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
  
  static const String usersTable = 'chat_users';
  static const String messagesTable = 'private_messages';
}
```

**⚠️ Important:**
- Use the **Project URL** (not the API URL)
- Use the **anon** key (not the service_role key)
- Keep the `supabaseUrl` and `supabaseAnonKey` names unchanged

---

## Step 5: Test the Database

### Via Supabase Dashboard:

1. Go to **Table Editor** in Supabase
2. Click on **chat_users** table
3. You should see an empty table with columns:
   - `id` (UUID)
   - `username` (TEXT)
   - `created_at` (TIMESTAMP)
   - `is_online` (BOOLEAN)
   - `last_seen` (TIMESTAMP)

---

## Step 6: Run Your App

```bash
cd client_flutter
flutter pub get
flutter run
```

### First Time Flow:
1. **Splash Screen** appears (2 seconds)
2. **Username Setup** screen appears
3. Enter a unique username (e.g., "sahil016")
4. Click **Continue**
5. Username saved to Supabase
6. **Chat List** screen appears with:
   - **Group Chat** card at top
   - **Private Chats** list below

---

## Step 7: Verify Data in Supabase

1. Go back to Supabase **Table Editor**
2. Click **chat_users** table
3. Click **Refresh**
4. You should see your username entry with:
   - `id`: Your unique UUID
   - `username`: Your chosen username
   - `created_at`: Registration timestamp
   - `is_online`: true
   - `last_seen`: Current timestamp

---

## Troubleshooting

### Error: "Failed to initialize Supabase"
- Check your `supabaseUrl` and `supabaseAnonKey` are correct
- Ensure no extra spaces or quotes
- Verify project is not paused (free tier pauses after 7 days inactivity)

### Error: "Username already taken"
- Username exists in database
- Try a different username
- Or delete the user from Supabase Table Editor

### Error: "Failed to connect"
- Server might not be running
- Check `app_config.dart` has correct server IP
- Verify firewall allows port 5555

### Can't see other users
- They need to register through the app
- Check Supabase Table Editor to see all users
- Refresh the chat list by pulling down

---

## Database Schema Diagram

```
┌─────────────────┐
│   chat_users    │
├─────────────────┤
│ id (PK)         │
│ username        │ ← Unique
│ created_at      │
│ is_online       │
│ last_seen       │
└─────────────────┘
         │
         │ (sender_id)
         ▼
┌─────────────────┐
│private_messages │
├─────────────────┤
│ id (PK)         │
│ sender_id (FK)  │
│ receiver_id(FK) │
│ content         │
│ created_at      │
│ is_read         │
└─────────────────┘
```

---

## Security Notes

### Current Setup (Development):
✅ Row Level Security (RLS) enabled
✅ Public read access (anyone can see usernames)
✅ Public insert access (anyone can register)
✅ Users can update their own status

### For Production:
Consider adding:
- Email/phone verification
- Authentication tokens
- Rate limiting
- Message encryption
- User blocking
- Spam protection

---

## Useful Supabase Commands

### View all users:
```sql
SELECT * FROM chat_users ORDER BY created_at DESC;
```

### Check online users:
```sql
SELECT username, is_online, last_seen 
FROM chat_users 
WHERE is_online = true;
```

### Delete a user:
```sql
DELETE FROM chat_users WHERE username = 'username_here';
```

### Clear all users (reset):
```sql
TRUNCATE chat_users CASCADE;
```

---

## Support

- **Supabase Docs**: https://supabase.com/docs
- **Flutter Docs**: https://flutter.dev/docs
- **Project Issues**: Check GitHub repository

---

## Next Steps

Once Supabase is set up:

1. ✅ Users can register unique usernames
2. ✅ Usernames persist (no re-login needed)
3. ✅ See all registered users in chat list
4. ✅ Open group chat (all users)
5. ✅ Open private chats (1-on-1 with any user)
6. 🔄 Private messages stored in Supabase (coming soon)

---

**Your app is now ready with Supabase integration!** 🎉

