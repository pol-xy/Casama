-- Casama Migration: QuickSnap Locket Schema
-- Provides spontaneous camera moment sharing, reactions, comments, and streaks among housemates.

-- 1. Create quick_snaps table
CREATE TABLE IF NOT EXISTS quick_snaps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    creator_name TEXT NOT NULL,
    creator_avatar TEXT,
    image_url TEXT NOT NULL,
    caption TEXT,
    recipient_type TEXT NOT NULL DEFAULT 'everyone' CHECK (recipient_type IN ('everyone', 'selected_friends')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- 2. Create quick_snap_recipients table (for selected friends)
CREATE TABLE IF NOT EXISTS quick_snap_recipients (
    snap_id UUID NOT NULL REFERENCES quick_snaps(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    PRIMARY KEY (snap_id, user_id)
);

-- 3. Create quick_snap_reactions table
CREATE TABLE IF NOT EXISTS quick_snap_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    snap_id UUID NOT NULL REFERENCES quick_snaps(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (snap_id, user_id, emoji)
);

-- 4. Create quick_snap_comments table
CREATE TABLE IF NOT EXISTS quick_snap_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    snap_id UUID NOT NULL REFERENCES quick_snaps(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    user_avatar TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_quicksnaps_household ON quick_snaps(household_id);
CREATE INDEX IF NOT EXISTS idx_quicksnaps_created_at ON quick_snaps(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_quicksnap_reactions_snap ON quick_snap_reactions(snap_id);
CREATE INDEX IF NOT EXISTS idx_quicksnap_comments_snap ON quick_snap_comments(snap_id);

-- Enable Row Level Security (RLS)
ALTER TABLE quick_snaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_snap_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_snap_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_snap_comments ENABLE ROW LEVEL SECURITY;

-- QuickSnaps RLS Policies (Idempotent: Drop if exists before re-creating)
DROP POLICY IF EXISTS "Household members can view accessible quicksnaps" ON quick_snaps;
CREATE POLICY "Household members can view accessible quicksnaps"
ON quick_snaps FOR SELECT TO authenticated
USING (
    is_household_member(household_id) AND (
        recipient_type = 'everyone' OR
        creator_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM quick_snap_recipients qsr
            WHERE qsr.snap_id = id AND qsr.user_id = auth.uid()
        )
    )
);

DROP POLICY IF EXISTS "Household members can create quicksnaps" ON quick_snaps;
CREATE POLICY "Household members can create quicksnaps"
ON quick_snaps FOR INSERT TO authenticated
WITH CHECK (is_household_member(household_id) AND auth.uid() = creator_id);

DROP POLICY IF EXISTS "Creators can delete their quicksnaps" ON quick_snaps;
CREATE POLICY "Creators can delete their quicksnaps"
ON quick_snaps FOR DELETE TO authenticated
USING (auth.uid() = creator_id);

-- Recipients RLS Policies
DROP POLICY IF EXISTS "Household members can view snap recipients" ON quick_snap_recipients;
CREATE POLICY "Household members can view snap recipients"
ON quick_snap_recipients FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM quick_snaps qs WHERE qs.id = snap_id AND is_household_member(qs.household_id)));

DROP POLICY IF EXISTS "Snap creators can insert snap recipients" ON quick_snap_recipients;
CREATE POLICY "Snap creators can insert snap recipients"
ON quick_snap_recipients FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM quick_snaps qs WHERE qs.id = snap_id AND qs.creator_id = auth.uid()));

-- Reactions RLS Policies
DROP POLICY IF EXISTS "Household members can view snap reactions" ON quick_snap_reactions;
CREATE POLICY "Household members can view snap reactions"
ON quick_snap_reactions FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM quick_snaps qs WHERE qs.id = snap_id AND is_household_member(qs.household_id)));

DROP POLICY IF EXISTS "Users can add snap reactions" ON quick_snap_reactions;
CREATE POLICY "Users can add snap reactions"
ON quick_snap_reactions FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Comments RLS Policies
DROP POLICY IF EXISTS "Household members can view snap comments" ON quick_snap_comments;
CREATE POLICY "Household members can view snap comments"
ON quick_snap_comments FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM quick_snaps qs WHERE qs.id = snap_id AND is_household_member(qs.household_id)));

DROP POLICY IF EXISTS "Users can add snap comments" ON quick_snap_comments;
CREATE POLICY "Users can add snap comments"
ON quick_snap_comments FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Realtime Replication (Idempotent)
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY['quick_snaps', 'quick_snap_reactions', 'quick_snap_comments'])
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime' AND tablename = tbl
        ) THEN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I;', tbl);
        END IF;
    END LOOP;
END;
$$;
