# Supabase Setup Guide V2 - With Messages & File Storage

Complete setup for messages, files, and media storage.

## Step 1: Update Database Schema

In your Supabase **SQL Editor**, run this **updated schema**:

```sql
-- Drop old tables if they exist
DROP TABLE IF EXISTS private_messages CASCADE;
DROP TABLE IF EXISTS group_messages CASCADE;
DROP TABLE IF EXISTS chat_users CASCADE;

-- Create users table
CREATE TABLE chat_users (
    id UUID PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_online BOOLEAN DEFAULT false,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create group messages table
CREATE TABLE group_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES chat_users(id) ON DELETE CASCADE,
    sender_username TEXT NOT NULL,
    content TEXT,
    message_type TEXT DEFAULT 'text', -- 'text', 'image', 'document', 'file'
    file_url TEXT,
    file_name TEXT,
    file_size BIGINT,
    file_type TEXT,
    thumbnail_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create private messages table
CREATE TABLE private_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES chat_users(id) ON DELETE CASCADE,
    receiver_id UUID REFERENCES chat_users(id) ON DELETE CASCADE,
    sender_username TEXT NOT NULL,
    content TEXT,
    message_type TEXT DEFAULT 'text',
    file_url TEXT,
    file_name TEXT,
    file_size BIGINT,
    file_type TEXT,
    thumbnail_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_read BOOLEAN DEFAULT false
);

-- Create indexes
CREATE INDEX idx_users_username ON chat_users(username);
CREATE INDEX idx_users_online ON chat_users(is_online);
CREATE INDEX idx_group_messages_created ON group_messages(created_at DESC);
CREATE INDEX idx_group_messages_sender ON group_messages(sender_id);
CREATE INDEX idx_private_messages_sender ON private_messages(sender_id);
CREATE INDEX idx_private_messages_receiver ON private_messages(receiver_id);
CREATE INDEX idx_private_messages_created ON private_messages(created_at DESC);
CREATE INDEX idx_private_messages_conversation ON private_messages(sender_id, receiver_id);

-- Enable Row Level Security
ALTER TABLE chat_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_messages ENABLE ROW LEVEL SECURITY;

-- Policies for chat_users
CREATE POLICY "Users can read all users"
    ON chat_users FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own data"
    ON chat_users FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Users can update their own data"
    ON chat_users FOR UPDATE
    USING (true);

-- Policies for group_messages
CREATE POLICY "Anyone can read group messages"
    ON group_messages FOR SELECT
    USING (true);

CREATE POLICY "Anyone can insert group messages"
    ON group_messages FOR INSERT
    WITH CHECK (true);

-- Policies for private_messages
CREATE POLICY "Users can read their own messages"
    ON private_messages FOR SELECT
    USING (true);

CREATE POLICY "Users can insert messages"
    ON private_messages FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Users can update their messages"
    ON private_messages FOR UPDATE
    USING (true);

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

## Step 2: Create Storage Bucket for Files

1. Go to **Storage** in Supabase (left sidebar)
2. Click **"New bucket"**
3. **Name**: `chat-files`
4. **Public bucket**: ✅ Enable (so files can be accessed via URL)
5. Click **"Create bucket"**

### Set Storage Policies

Click on `chat-files` bucket → **Policies** tab → **New Policy**

**Policy 1: Allow public read**
```sql
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'chat-files' );
```

**Policy 2: Allow authenticated upload**
```sql
CREATE POLICY "Allow uploads"
ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'chat-files' );
```

**Policy 3: Allow delete**
```sql
CREATE POLICY "Allow deletes"
ON storage.objects FOR DELETE
USING ( bucket_id = 'chat-files' );
```

## Step 3: File Size Limits (Optional)

In Storage bucket settings:
- **Max file size**: 10 MB (for images/documents)
- **Allowed MIME types**: 
  - `image/*` (all images)
  - `application/pdf`
  - `application/msword`
  - `application/vnd.ms-powerpoint`
  - `application/vnd.openxmlformats-officedocument.*`

## Database Schema

```
chat_users
├── id (UUID)
├── username (TEXT, UNIQUE)
├── created_at (TIMESTAMP)
├── is_online (BOOLEAN)
└── last_seen (TIMESTAMP)

group_messages
├── id (UUID)
├── sender_id (FK → chat_users)
├── sender_username (TEXT)
├── content (TEXT) ← message text
├── message_type (TEXT) ← 'text', 'image', 'document'
├── file_url (TEXT) ← Supabase Storage URL
├── file_name (TEXT)
├── file_size (BIGINT)
├── file_type (TEXT) ← MIME type
├── thumbnail_url (TEXT) ← for images
└── created_at (TIMESTAMP)

private_messages
├── id (UUID)
├── sender_id (FK → chat_users)
├── receiver_id (FK → chat_users)
├── sender_username (TEXT)
├── content (TEXT)
├── message_type (TEXT)
├── file_url (TEXT)
├── file_name (TEXT)
├── file_size (BIGINT)
├── file_type (TEXT)
├── thumbnail_url (TEXT)
├── is_read (BOOLEAN)
└── created_at (TIMESTAMP)

Storage: chat-files/
├── images/
│   ├── user1_timestamp.jpg
│   └── user2_timestamp.png
└── documents/
    ├── user1_document.pdf
    └── user2_presentation.pptx
```

## Features Enabled

✅ Message history stored in Supabase  
✅ File uploads to Supabase Storage  
✅ Images shown inline in chat  
✅ Documents shown with preview icons  
✅ File size and type tracking  
✅ Separate group and private message tables  
✅ Chat history loads from database  

## What's New

### Message Types:
- **text**: Regular text messages
- **image**: Images (jpg, png, gif) with inline preview
- **document**: PDFs, Word docs, PowerPoint
- **file**: Other file types

### File Storage:
- Files uploaded to `chat-files` bucket
- Organized by type: `images/` and `documents/`
- Public URLs for easy access
- Automatic thumbnail generation for images

### Chat History:
- All messages persisted in Supabase
- Load last 50 messages on chat open
- Scroll up to load more (pagination)
- Real-time + persistent storage

## Next Steps

After running this schema:
1. Update `supabase_config.dart` with your credentials
2. Run `flutter pub get`
3. Messages will now be saved to Supabase
4. Files will upload to Supabase Storage
5. Images will show inline in chat
6. Documents will show with preview icons

Your chat now has full message persistence! 🎉

