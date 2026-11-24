-- Casama Migration: Household Bills & Shared Payments Schema
-- Provides tracking, assignments, reminders, and split payments for dorm bills

-- 1. Create bills table
CREATE TABLE IF NOT EXISTS bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN (
        'electricity', 'water', 'internet', 'appliance',
        'rent', 'association_dues', 'gas', 'maintenance_fee', 'other'
    )),
    custom_category_name TEXT,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    deadline TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid', 'paid', 'overdue')),
    responsible_member TEXT,
    notes TEXT,
    reminder_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    reminder_timing TEXT NOT NULL DEFAULT 'one_day_before' CHECK (reminder_timing IN (
        'on_due_date', 'one_day_before', 'three_days_before', 'one_week_before'
    )),
    recipient_type TEXT NOT NULL DEFAULT 'all_members' CHECK (recipient_type IN (
        'all_members', 'specific_members'
    )),
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_by_name TEXT,
    paid_at TIMESTAMPTZ,
    paid_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    paid_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_bills_household ON bills(household_id);
CREATE INDEX IF NOT EXISTS idx_bills_deadline ON bills(deadline);
CREATE INDEX IF NOT EXISTS idx_bills_status ON bills(status);

-- Enable Row Level Security (RLS)
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;

-- Household RLS Policies (Idempotent: Drop if exists before re-creating)
DROP POLICY IF EXISTS "Household members can view bills" ON bills;
CREATE POLICY "Household members can view bills"
ON bills FOR SELECT TO authenticated
USING (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can insert bills" ON bills;
CREATE POLICY "Household members can insert bills"
ON bills FOR INSERT TO authenticated
WITH CHECK (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can update bills" ON bills;
CREATE POLICY "Household members can update bills"
ON bills FOR UPDATE TO authenticated
USING (is_household_member(household_id))
WITH CHECK (is_household_member(household_id));

DROP POLICY IF EXISTS "Household members can delete bills" ON bills;
CREATE POLICY "Household members can delete bills"
ON bills FOR DELETE TO authenticated
USING (is_household_member(household_id));

-- Realtime Replication (Idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'bills'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE bills;
    END IF;
END;
$$;
