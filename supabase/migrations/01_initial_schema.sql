-- Casama Master Schema Migration
-- Initial Schema & Row Level Security (RLS) Engine

-- 1. Profiles (Public user profiles tied to auth.users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    handle TEXT UNIQUE,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Households (Shared living spaces)
CREATE TABLE IF NOT EXISTS households (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    invite_code TEXT NOT NULL UNIQUE,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Household Members (User-to-household association)
CREATE TABLE IF NOT EXISTS household_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(household_id, user_id)
);

-- 4. Presence Events (History & current status derivation)
CREATE TABLE IF NOT EXISTS presence_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    is_home BOOLEAN NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Parcels (Delivery coordination)
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

-- 6. Parcel Availability (Roommate availability responses)
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

-- 7. Parcel Claims & COD Settlement
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

-- 8. Lost & Found Items
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

-- 9. Item Responses (Pings and comments)
CREATE TABLE IF NOT EXISTS item_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    response_type TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Maintenance & Restock Tasks
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

-- 11. Good Kasama Points Ledger (Auditable, idempotent points tracking)
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

-- 12. Casama Connect: Conversations
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

-- 13. Meet-up Invitations & Responses
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

-- 14. Notifications & In-App Activity Feed
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================================================
-- HELPER FUNCTIONS & ROW LEVEL SECURITY (RLS)
-- =========================================================================

-- Helper to check if current authenticated user belongs to the given household
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

-- Helper to check if current user is member of a conversation
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

-- Enable RLS on all tables
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
ALTER TABLE points_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE meet_up_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE meet_up_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 1. Profiles RLS
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON profiles;
CREATE POLICY "Profiles are viewable by authenticated users"
ON profiles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
CREATE POLICY "Users can insert their own profile"
ON profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
CREATE POLICY "Users can update their own profile"
ON profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

-- 2. Households RLS
DROP POLICY IF EXISTS "Users can view households they belong to" ON households;
CREATE POLICY "Users can view households they belong to"
ON households FOR SELECT TO authenticated
USING (is_household_member(id) OR created_by = auth.uid());

DROP POLICY IF EXISTS "Users can create a household" ON households;
CREATE POLICY "Users can create a household"
ON households FOR INSERT TO authenticated
WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS "Owners can update their household" ON households;
CREATE POLICY "Owners can update their household"
ON households FOR UPDATE TO authenticated
USING (created_by = auth.uid());

-- 3. Household Members RLS
DROP POLICY IF EXISTS "Members can view household roster" ON household_members;
CREATE POLICY "Members can view household roster"
ON household_members FOR SELECT TO authenticated
USING (is_household_member(household_id) OR user_id = auth.uid());

DROP POLICY IF EXISTS "Users can join households" ON household_members;
CREATE POLICY "Users can join households"
ON household_members FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

-- 4. Household-Scoped Tables (Standard Isolation)
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'presence_events', 'parcels', 'parcel_availability', 'parcel_claims',
            'items', 'item_responses', 'maintenance_tasks', 'points_ledger',
            'conversations', 'notifications'
        ])
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "%s_household_access" ON %I;', tbl, tbl);
        EXECUTE format('
            CREATE POLICY "%s_household_access"
            ON %I FOR ALL TO authenticated
            USING (is_household_member(household_id))
            WITH CHECK (is_household_member(household_id));
        ', tbl, tbl);
    END LOOP;
END;
$$;

-- 5. Casama Connect Specific RLS
DROP POLICY IF EXISTS "Members view their conversation memberships" ON conversation_members;
CREATE POLICY "Members view their conversation memberships"
ON conversation_members FOR SELECT TO authenticated
USING (is_conversation_member(conversation_id) OR user_id = auth.uid());

DROP POLICY IF EXISTS "Members can join permitted conversations" ON conversation_members;
CREATE POLICY "Members can join permitted conversations"
ON conversation_members FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Messages accessible to conversation members" ON messages;
CREATE POLICY "Messages accessible to conversation members"
ON messages FOR ALL TO authenticated
USING (is_conversation_member(conversation_id))
WITH CHECK (is_conversation_member(conversation_id) AND sender_id = auth.uid());

DROP POLICY IF EXISTS "Meet-up invitations viewable by conversation members" ON meet_up_invitations;
CREATE POLICY "Meet-up invitations viewable by conversation members"
ON meet_up_invitations FOR ALL TO authenticated
USING (is_conversation_member(conversation_id))
WITH CHECK (is_conversation_member(conversation_id) AND creator_id = auth.uid());

DROP POLICY IF EXISTS "Meet-up responses accessible by invitation participants" ON meet_up_responses;
CREATE POLICY "Meet-up responses accessible by invitation participants"
ON meet_up_responses FOR ALL TO authenticated
USING (EXISTS (
    SELECT 1 FROM meet_up_invitations m
    WHERE m.id = invitation_id AND is_conversation_member(m.conversation_id)
))
WITH CHECK (user_id = auth.uid());

-- =========================================================================
-- ATOMIC STORED PROCEDURES (RPC)
-- =========================================================================

-- Atomic parcel receipt: updates parcel, inserts claim, adds points (+5)
CREATE OR REPLACE FUNCTION confirm_parcel_receipt(
    p_parcel_id UUID,
    p_receiver_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_household_id UUID;
    v_payment_type TEXT;
    v_cod_amount NUMERIC(10, 2);
    v_buyer_id UUID;
BEGIN
    -- Validate and fetch parcel
    SELECT household_id, payment_type, cod_amount, buyer_id
    INTO v_household_id, v_payment_type, v_cod_amount, v_buyer_id
    FROM parcels
    WHERE id = p_parcel_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Parcel not found';
    END IF;

    -- Update parcel status
    UPDATE parcels
    SET status = 'received'
    WHERE id = p_parcel_id;

    -- Insert claim
    INSERT INTO parcel_claims (household_id, parcel_id, receiver_id, amount_owed, settled)
    VALUES (
        v_household_id,
        p_parcel_id,
        p_receiver_id,
        CASE WHEN v_payment_type = 'cod' THEN v_cod_amount ELSE NULL END,
        CASE WHEN v_payment_type = 'paid' THEN TRUE ELSE FALSE END
    );

    -- Award points (+5)
    INSERT INTO points_ledger (household_id, user_id, action_type, points, reference_id)
    VALUES (v_household_id, p_receiver_id, 'parcel_received', 5, p_parcel_id)
    ON CONFLICT (user_id, action_type, reference_id) DO NOTHING;

    -- Notify household buyer
    INSERT INTO notifications (household_id, user_id, type, payload)
    VALUES (
        v_household_id,
        v_buyer_id,
        'parcel_received',
        jsonb_build_object(
            'parcel_id', p_parcel_id,
            'receiver_id', p_receiver_id,
            'cod_amount', v_cod_amount
        )
    );

    RETURN jsonb_build_object('success', true, 'points_awarded', 5);
END;
$$;

-- Atomic task completion: updates task and awards points (+5 for DIY/Landlord, +2 for Restock)
CREATE OR REPLACE FUNCTION complete_maintenance_task(
    p_task_id UUID,
    p_completed_by UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_household_id UUID;
    v_category TEXT;
    v_points INT;
BEGIN
    SELECT household_id, category
    INTO v_household_id, v_category
    FROM maintenance_tasks
    WHERE id = p_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Task not found';
    END IF;

    v_points := CASE WHEN v_category = 'restock' THEN 2 ELSE 5 END;

    UPDATE maintenance_tasks
    SET status = 'done',
        completed_by = p_completed_by,
        completed_at = NOW()
    WHERE id = p_task_id;

    INSERT INTO points_ledger (household_id, user_id, action_type, points, reference_id)
    VALUES (v_household_id, p_completed_by, 'task_completed', v_points, p_task_id)
    ON CONFLICT (user_id, action_type, reference_id) DO NOTHING;

    RETURN jsonb_build_object('success', true, 'points_awarded', v_points);
END;
$$;

-- Atomic found item return: marks returned and awards finder +3 points
CREATE OR REPLACE FUNCTION confirm_item_return(
    p_item_id UUID,
    p_finder_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_household_id UUID;
BEGIN
    SELECT household_id
    INTO v_household_id
    FROM items
    WHERE id = p_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Item not found';
    END IF;

    UPDATE items
    SET status = 'returned'
    WHERE id = p_item_id;

    INSERT INTO points_ledger (household_id, user_id, action_type, points, reference_id)
    VALUES (v_household_id, p_finder_id, 'item_returned', 3, p_item_id)
    ON CONFLICT (user_id, action_type, reference_id) DO NOTHING;

    RETURN jsonb_build_object('success', true, 'points_awarded', 3);
END;
$$;

-- =========================================================================
-- REALTIME REPLICATION PUBLICATION (Idempotent)
-- =========================================================================
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'presence_events', 'parcels', 'parcel_availability', 'maintenance_tasks',
            'messages', 'meet_up_invitations', 'meet_up_responses', 'notifications'
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

-- =========================================================================
-- STORAGE BUCKETS
-- =========================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('avatars', 'avatars', true),
    ('item_photos', 'item_photos', true),
    ('brand_assets', 'brand_assets', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public Avatar Access" ON storage.objects;
DROP POLICY IF EXISTS "Public avatar access" ON storage.objects;
CREATE POLICY "Public Avatar Access"
ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
CREATE POLICY "Authenticated users can upload avatars"
ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Public Item Photos Access" ON storage.objects;
DROP POLICY IF EXISTS "Public item photos access" ON storage.objects;
CREATE POLICY "Public Item Photos Access"
ON storage.objects FOR SELECT USING (bucket_id = 'item_photos');

DROP POLICY IF EXISTS "Authenticated users can upload item photos" ON storage.objects;
CREATE POLICY "Authenticated users can upload item photos"
ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'item_photos');

