-- =========================================================================
-- CASAMA: MASTER SETUP SCRIPT (ALL-IN-ONE)
-- Execute this entire file in Supabase SQL Editor to set up:
-- 1. All Database Tables (Profiles, Households, Parcels, Items, Tasks, Bills, QuickSnaps, Chores, Chat)
-- 2. Auth Trigger (Automatically creates public.profiles when a user signs up)
-- 3. Row Level Security (RLS) Policies (Enforces privacy by household)
-- 4. Supabase Storage Buckets (avatars, quicksnaps, items)
-- =========================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -------------------------------------------------------------------------
-- 1. PROFILES (Public profiles linked to auth.users)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    handle TEXT UNIQUE,
    full_name TEXT,
    nickname TEXT,
    age INT CHECK (age IS NULL OR (age >= 10 AND age <= 120)),
    avatar_url TEXT,
    has_consented_terms BOOLEAN DEFAULT FALSE,
    has_completed_onboarding BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -------------------------------------------------------------------------
-- 2. AUTH-TO-PROFILE TRIGGER (Automatic sync on sign up)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        display_name,
        handle,
        full_name,
        avatar_url,
        has_consented_terms,
        has_completed_onboarding
    )
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
        COALESCE(new.raw_user_meta_data->>'handle', '@' || split_part(new.email, '@', 1)),
        new.raw_user_meta_data->>'full_name',
        new.raw_user_meta_data->>'avatar_url',
        false,
        false
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- -------------------------------------------------------------------------
-- 3. HOUSEHOLDS & MEMBERSHIP
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS households (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    invite_code TEXT NOT NULL UNIQUE,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS household_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(household_id, user_id)
);

-- -------------------------------------------------------------------------
-- 4. PRESENCE EVENTS (Who's Home & Status Notes)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS presence_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    is_home BOOLEAN NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -------------------------------------------------------------------------
-- 5. PARCELS & DELIVERIES (Shopee, Lazada, COD tracking)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS parcels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    courier TEXT NOT NULL,
    expected_arrival TIMESTAMPTZ NOT NULL,
    payment_type TEXT NOT NULL CHECK (payment_type IN ('paid', 'cod')),
    cod_amount NUMERIC(10, 2) CHECK (
        (payment_type = 'cod' AND cod_amount > 0) OR
        (payment_type = 'paid' AND cod_amount IS NULL)
    ),
    currency TEXT DEFAULT 'PHP',
    status TEXT NOT NULL DEFAULT 'expected' CHECK (status IN ('expected', 'arrived', 'received', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS parcel_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    parcel_id UUID NOT NULL REFERENCES parcels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    is_available BOOLEAN NOT NULL,
    note TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(parcel_id, user_id)
);

CREATE TABLE IF NOT EXISTS parcel_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    parcel_id UUID NOT NULL REFERENCES parcels(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    received_at TIMESTAMPTZ DEFAULT NOW(),
    amount_owed NUMERIC(10, 2),
    settled BOOLEAN NOT NULL DEFAULT FALSE,
    settled_at TIMESTAMPTZ
);

-- -------------------------------------------------------------------------
-- 6. LOST & FOUND / SHARED HOUSEWARES
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('lost', 'found', 'shared')),
    title TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    status TEXT NOT NULL CHECK (status IN ('open', 'found', 'unclaimed', 'claimed', 'returned')),
    reported_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS item_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    response_type TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -------------------------------------------------------------------------
-- 7. MAINTENANCE & RESTOCK TASKS
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS maintenance_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('diy', 'landlord', 'restock')),
    urgency TEXT NOT NULL CHECK (urgency IN ('low', 'medium', 'urgent')),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'done')),
    assignee_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    completed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -------------------------------------------------------------------------
-- 8. HOUSEHOLD BILLS & PAYMENTS (Electricity, Water, Internet, Rent, etc.)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN (
        'electricity', 'water', 'internet', 'appliance', 'rent', 'other'
    )),
    custom_category TEXT,
    amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    currency TEXT NOT NULL DEFAULT 'PHP',
    deadline DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid', 'paid', 'overdue')),
    has_reminder BOOLEAN NOT NULL DEFAULT TRUE,
    reminder_timing TEXT NOT NULL DEFAULT '1_day_before' CHECK (reminder_timing IN (
        'on_due_date', '1_day_before', '2_days_before', '3_days_before', '1_week_before'
    )),
    reminder_recipients TEXT NOT NULL DEFAULT 'all_members' CHECK (reminder_recipients IN (
        'only_me', 'all_members', 'selected_members'
    )),
    responsible_member_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    notes TEXT,
    paid_at TIMESTAMPTZ,
    paid_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------------
-- 9. QUICKSNAP LOCKET (Realtime Photo Sharing, Reactions, Comments)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS quick_snaps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    caption TEXT,
    recipient_type TEXT NOT NULL DEFAULT 'everyone' CHECK (recipient_type IN ('everyone', 'selected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS quick_snap_recipients (
    snap_id UUID NOT NULL REFERENCES quick_snaps(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    PRIMARY KEY (snap_id, user_id)
);

CREATE TABLE IF NOT EXISTS quick_snap_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    snap_id UUID NOT NULL REFERENCES quick_snaps(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(snap_id, user_id, emoji)
);

CREATE TABLE IF NOT EXISTS quick_snap_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    snap_id UUID NOT NULL REFERENCES quick_snaps(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------------
-- 10. CHORE ROULETTE (Settler & History)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chore_roulette_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    chore_title TEXT NOT NULL,
    assigned_to UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    spun_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    mode TEXT NOT NULL CHECK (mode IN ('random_dormmate', 'just_for_me')),
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------------------
-- 11. GOOD KASAMA POINTS LEDGER
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS points_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    points INT NOT NULL,
    reference_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, action_type, reference_id)
);

-- -------------------------------------------------------------------------
-- 12. CASAMA CONNECT (Chat, Meet-ups, Notifications)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('group', 'direct')),
    name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS conversation_members (
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    client_message_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(conversation_id, client_message_id)
);

CREATE TABLE IF NOT EXISTS meet_up_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    activity TEXT NOT NULL,
    location TEXT NOT NULL,
    scheduled_time TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS meet_up_responses (
    invitation_id UUID NOT NULL REFERENCES meet_up_invitations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    response TEXT NOT NULL CHECK (response IN ('going', 'maybe', 'cant_make_it')),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (invitation_id, user_id)
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -------------------------------------------------------------------------
-- 13. INDEXES FOR HIGH QUERY PERFORMANCE
-- -------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_bills_household ON bills(household_id);
CREATE INDEX IF NOT EXISTS idx_bills_deadline ON bills(deadline);
CREATE INDEX IF NOT EXISTS idx_bills_status ON bills(status);
CREATE INDEX IF NOT EXISTS idx_quicksnaps_household ON quick_snaps(household_id);
CREATE INDEX IF NOT EXISTS idx_quicksnaps_created_at ON quick_snaps(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reactions_snap ON quick_snap_reactions(snap_id);
CREATE INDEX IF NOT EXISTS idx_comments_snap ON quick_snap_comments(snap_id);
CREATE INDEX IF NOT EXISTS idx_chore_roulette_household ON chore_roulette_records(household_id);

-- -------------------------------------------------------------------------
-- 14. ROW LEVEL SECURITY (RLS) HELPER FUNCTIONS
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_household_member(target_household_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM household_members
        WHERE household_id = target_household_id
          AND user_id = auth.uid()
    );
$$;

CREATE OR REPLACE FUNCTION is_conversation_member(target_conversation_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM conversation_members
        WHERE conversation_id = target_conversation_id
          AND user_id = auth.uid()
    );
$$;

-- -------------------------------------------------------------------------
-- 15. ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
-- -------------------------------------------------------------------------
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE presence_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE parcels ENABLE ROW LEVEL SECURITY;
ALTER TABLE parcel_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE parcel_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_snaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_snap_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_snap_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_snap_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE chore_roulette_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE points_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE meet_up_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE meet_up_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------
-- 16. ROW LEVEL SECURITY (RLS) POLICIES
-- -------------------------------------------------------------------------

-- Profiles
DROP POLICY IF EXISTS "Profiles viewable by authenticated users" ON profiles;
CREATE POLICY "Profiles viewable by authenticated users"
ON profiles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
CREATE POLICY "Users can insert their own profile"
ON profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile"
ON profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Households
DROP POLICY IF EXISTS "Household members can view their household" ON households;
CREATE POLICY "Household members can view their household"
ON households FOR SELECT TO authenticated USING (is_household_member(id));

DROP POLICY IF EXISTS "Users can create households" ON households;
CREATE POLICY "Users can create households"
ON households FOR INSERT TO authenticated WITH CHECK (auth.uid() = created_by);

-- Household Members
DROP POLICY IF EXISTS "Members can view household member list" ON household_members;
CREATE POLICY "Members can view household member list"
ON household_members FOR SELECT TO authenticated USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Users can join households" ON household_members;
CREATE POLICY "Users can join households"
ON household_members FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Presence Events
DROP POLICY IF EXISTS "Household members view presence" ON presence_events;
CREATE POLICY "Household members view presence"
ON presence_events FOR SELECT TO authenticated USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Users record their own presence" ON presence_events;
CREATE POLICY "Users record their own presence"
ON presence_events FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Parcels
DROP POLICY IF EXISTS "Household members can view parcels" ON parcels;
CREATE POLICY "Household members can view parcels"
ON parcels FOR SELECT TO authenticated USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can insert parcels" ON parcels;
CREATE POLICY "Household members can insert parcels"
ON parcels FOR INSERT TO authenticated WITH CHECK (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can update parcels" ON parcels;
CREATE POLICY "Household members can update parcels"
ON parcels FOR UPDATE TO authenticated USING (is_household_member(household_id));

-- Lost & Found
DROP POLICY IF EXISTS "Household members can view items" ON items;
CREATE POLICY "Household members can view items"
ON items FOR SELECT TO authenticated USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can report items" ON items;
CREATE POLICY "Household members can report items"
ON items FOR INSERT TO authenticated WITH CHECK (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can update items" ON items;
CREATE POLICY "Household members can update items"
ON items FOR UPDATE TO authenticated USING (is_household_member(household_id));

-- Tasks
DROP POLICY IF EXISTS "Household members can view tasks" ON maintenance_tasks;
CREATE POLICY "Household members can view tasks"
ON maintenance_tasks FOR SELECT TO authenticated USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can insert tasks" ON maintenance_tasks;
CREATE POLICY "Household members can insert tasks"
ON maintenance_tasks FOR INSERT TO authenticated WITH CHECK (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can update tasks" ON maintenance_tasks;
CREATE POLICY "Household members can update tasks"
ON maintenance_tasks FOR UPDATE TO authenticated USING (is_household_member(household_id));

-- Bills & Payments
DROP POLICY IF EXISTS "Household members can view bills" ON bills;
CREATE POLICY "Household members can view bills"
ON bills FOR SELECT TO authenticated USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can insert bills" ON bills;
CREATE POLICY "Household members can insert bills"
ON bills FOR INSERT TO authenticated WITH CHECK (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can update bills" ON bills;
CREATE POLICY "Household members can update bills"
ON bills FOR UPDATE TO authenticated USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can delete bills" ON bills;
CREATE POLICY "Household members can delete bills"
ON bills FOR DELETE TO authenticated USING (is_household_member(household_id));

-- QuickSnaps
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
ON quick_snaps FOR DELETE TO authenticated USING (auth.uid() = creator_id);

-- QuickSnap Reactions & Comments
DROP POLICY IF EXISTS "Household members can view snap reactions" ON quick_snap_reactions;
CREATE POLICY "Household members can view snap reactions"
ON quick_snap_reactions FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM quick_snaps qs WHERE qs.id = snap_id AND is_household_member(qs.household_id)));

DROP POLICY IF EXISTS "Users can add snap reactions" ON quick_snap_reactions;
CREATE POLICY "Users can add snap reactions"
ON quick_snap_reactions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Household members can view snap comments" ON quick_snap_comments;
CREATE POLICY "Household members can view snap comments"
ON quick_snap_comments FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM quick_snaps qs WHERE qs.id = snap_id AND is_household_member(qs.household_id)));

DROP POLICY IF EXISTS "Users can add snap comments" ON quick_snap_comments;
CREATE POLICY "Users can add snap comments"
ON quick_snap_comments FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Chore Roulette
DROP POLICY IF EXISTS "Household members can view chore roulette history" ON chore_roulette_records;
CREATE POLICY "Household members can view chore roulette history"
ON chore_roulette_records FOR SELECT TO authenticated USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can record roulette spins" ON chore_roulette_records;
CREATE POLICY "Household members can record roulette spins"
ON chore_roulette_records FOR INSERT TO authenticated WITH CHECK (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can update chore roulette completion" ON chore_roulette_records;
CREATE POLICY "Household members can update chore roulette completion"
ON chore_roulette_records FOR UPDATE TO authenticated USING (is_household_member(household_id));

-- Chat Messages & Conversations
DROP POLICY IF EXISTS "Conversation members can view conversations" ON conversations;
CREATE POLICY "Conversation members can view conversations"
ON conversations FOR SELECT TO authenticated USING (is_conversation_member(id));

DROP POLICY IF EXISTS "Conversation members can view messages" ON messages;
CREATE POLICY "Conversation members can view messages"
ON messages FOR SELECT TO authenticated USING (is_conversation_member(conversation_id));

DROP POLICY IF EXISTS "Conversation members can send messages" ON messages;
CREATE POLICY "Conversation members can send messages"
ON messages FOR INSERT TO authenticated
WITH CHECK (is_conversation_member(conversation_id) AND auth.uid() = sender_id);

-- Meet-up Invitations
DROP POLICY IF EXISTS "Conversation members can view meet-ups" ON meet_up_invitations;
CREATE POLICY "Conversation members can view meet-ups"
ON meet_up_invitations FOR SELECT TO authenticated USING (is_conversation_member(conversation_id));

DROP POLICY IF EXISTS "Conversation members can create meet-ups" ON meet_up_invitations;
CREATE POLICY "Conversation members can create meet-ups"
ON meet_up_invitations FOR INSERT TO authenticated
WITH CHECK (is_conversation_member(conversation_id) AND auth.uid() = creator_id);

-- -------------------------------------------------------------------------
-- 17. SUPABASE STORAGE BUCKETS (avatars, quicksnaps, items)
-- -------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('avatars', 'avatars', true),
    ('quicksnaps', 'quicksnaps', true),
    ('items', 'items', true),
    ('item_photos', 'item_photos', true),
    ('brand_assets', 'brand_assets', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public avatar access" ON storage.objects;
DROP POLICY IF EXISTS "Public Avatar Access" ON storage.objects;
CREATE POLICY "Public avatar access"
ON storage.objects FOR SELECT TO authenticated, anon
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
CREATE POLICY "Authenticated users can upload avatars"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Public quicksnaps access" ON storage.objects;
CREATE POLICY "Public quicksnaps access"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'quicksnaps');

DROP POLICY IF EXISTS "Authenticated users can upload quicksnaps" ON storage.objects;
CREATE POLICY "Authenticated users can upload quicksnaps"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'quicksnaps');

DROP POLICY IF EXISTS "Public item photos access" ON storage.objects;
DROP POLICY IF EXISTS "Public Item Photos Access" ON storage.objects;
CREATE POLICY "Public item photos access"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id IN ('items', 'item_photos'));

DROP POLICY IF EXISTS "Authenticated users can upload item photos" ON storage.objects;
CREATE POLICY "Authenticated users can upload item photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id IN ('items', 'item_photos'));

-- -------------------------------------------------------------------------
-- 18. REALTIME REPLICATION PUBLICATION (Idempotent)
-- -------------------------------------------------------------------------
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'presence_events', 'parcels', 'parcel_availability', 'maintenance_tasks',
            'messages', 'meet_up_invitations', 'meet_up_responses', 'notifications',
            'bills', 'quick_snaps', 'quick_snap_reactions', 'quick_snap_comments',
            'chore_roulette_records'
        ])
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
