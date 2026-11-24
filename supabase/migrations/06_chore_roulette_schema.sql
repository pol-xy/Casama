-- Casama Migration: Chore Roulette Schema
-- Records roulette spins, randomized housemate assignments, and chore completion.

CREATE TABLE IF NOT EXISTS chore_roulette_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    chore_title TEXT NOT NULL,
    assigned_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    assigned_user_name TEXT NOT NULL,
    spun_by_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    spun_by_name TEXT NOT NULL,
    is_personal_mode BOOLEAN NOT NULL DEFAULT FALSE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'swapped')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_chore_roulette_household ON chore_roulette_records(household_id);
CREATE INDEX IF NOT EXISTS idx_chore_roulette_status ON chore_roulette_records(status);

-- Enable Row Level Security (RLS)
ALTER TABLE chore_roulette_records ENABLE ROW LEVEL SECURITY;

-- Household RLS Policies (Idempotent: Drop if exists before re-creating)
DROP POLICY IF EXISTS "Household members can view chore roulette history" ON chore_roulette_records;
CREATE POLICY "Household members can view chore roulette history"
ON chore_roulette_records FOR SELECT TO authenticated
USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can record roulette spins" ON chore_roulette_records;
CREATE POLICY "Household members can record roulette spins"
ON chore_roulette_records FOR INSERT TO authenticated
WITH CHECK (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can update chore roulette completion" ON chore_roulette_records;
CREATE POLICY "Household members can update chore roulette completion"
ON chore_roulette_records FOR UPDATE TO authenticated
USING (is_household_member(household_id))
WITH CHECK (is_household_member(household_id));

-- Realtime Replication (Idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'chore_roulette_records'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE chore_roulette_records;
    END IF;
END;
$$;
