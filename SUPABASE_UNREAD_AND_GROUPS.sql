-- ============================================
-- UNREAD MESSAGES & CUSTOM GROUPS FEATURE
-- Run this SQL in Supabase SQL Editor
-- ============================================

-- 1. Add unread tracking for group messages
CREATE TABLE IF NOT EXISTS group_message_reads (
    user_id UUID REFERENCES chat_users(id) ON DELETE CASCADE,
    group_id UUID,
    last_read_message_id UUID,
    last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, group_id)
);

-- 2. Create custom groups table
CREATE TABLE IF NOT EXISTS chat_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_by UUID REFERENCES chat_users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_default BOOLEAN DEFAULT false
);

-- 3. Create group members table
CREATE TABLE IF NOT EXISTS group_members (
    group_id UUID REFERENCES chat_groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES chat_users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (group_id, user_id)
);

-- 4. Add group_id to group_messages table
ALTER TABLE group_messages 
ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES chat_groups(id) ON DELETE CASCADE;

-- 5. Create default "Global Chat" group (only if doesn't exist)
INSERT INTO chat_groups (id, name, is_default)
VALUES ('00000000-0000-0000-0000-000000000001', 'Global Chat', true)
ON CONFLICT (id) DO NOTHING;

-- 6. Add all existing users to default group (only if not already members)
INSERT INTO group_members (group_id, user_id)
SELECT '00000000-0000-0000-0000-000000000001', id
FROM chat_users
WHERE NOT EXISTS (
    SELECT 1 FROM group_members 
    WHERE group_id = '00000000-0000-0000-0000-000000000001' 
    AND group_members.user_id = chat_users.id
)
ON CONFLICT DO NOTHING;

-- 7. Update existing messages to belong to default group
UPDATE group_messages 
SET group_id = '00000000-0000-0000-0000-000000000001'
WHERE group_id IS NULL;

-- 8. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_group_message_reads_user ON group_message_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_messages_group ON group_messages(group_id);

-- 9. Enable Row Level Security
ALTER TABLE group_message_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- 10. Create policies (drop first if they exist)
DROP POLICY IF EXISTS "Users can read their own read status" ON group_message_reads;
CREATE POLICY "Users can read their own read status"
    ON group_message_reads FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Users can insert their read status" ON group_message_reads;
CREATE POLICY "Users can insert their read status"
    ON group_message_reads FOR INSERT
    WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their read status" ON group_message_reads;
CREATE POLICY "Users can update their read status"
    ON group_message_reads FOR UPDATE
    USING (true);

DROP POLICY IF EXISTS "Anyone can read groups" ON chat_groups;
CREATE POLICY "Anyone can read groups"
    ON chat_groups FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Users can create groups" ON chat_groups;
CREATE POLICY "Users can create groups"
    ON chat_groups FOR INSERT
    WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can read group members" ON group_members;
CREATE POLICY "Anyone can read group members"
    ON group_members FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Users can join groups" ON group_members;
CREATE POLICY "Users can join groups"
    ON group_members FOR INSERT
    WITH CHECK (true);

-- 11. Function to get unread count for private messages
CREATE OR REPLACE FUNCTION get_unread_private_count(for_user_id UUID, from_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM private_messages
        WHERE receiver_id = for_user_id
          AND sender_id = from_user_id
          AND is_read = false
    );
END;
$$ LANGUAGE plpgsql;

-- 12. Function to get unread count for group messages
CREATE OR REPLACE FUNCTION get_unread_group_count(for_user_id UUID, for_group_id UUID)
RETURNS INTEGER AS $$
DECLARE
    last_read TIMESTAMP WITH TIME ZONE;
    unread_count INTEGER;
BEGIN
    -- Get last read timestamp
    SELECT last_read_at INTO last_read
    FROM group_message_reads
    WHERE user_id = for_user_id AND group_id = for_group_id;
    
    IF last_read IS NULL THEN
        last_read := '1970-01-01'::TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Count messages after last read
    SELECT COUNT(*)::INTEGER INTO unread_count
    FROM group_messages
    WHERE group_id = for_group_id
      AND created_at > last_read
      AND sender_id != for_user_id;
    
    RETURN unread_count;
END;
$$ LANGUAGE plpgsql;

-- Done! Your database now supports:
-- ✅ Unread message tracking
-- ✅ Custom group creation
-- ✅ Group member management
-- ✅ Unread count functions

