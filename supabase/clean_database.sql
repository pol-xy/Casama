-- Casama Clean-Up Script
-- Removes all mock/demo seed data from Supabase so all sections start completely fresh.
-- Run this in the Supabase SQL Editor.

-- 1. Truncate all feature tables with CASCADE to preserve schemas and foreign key structure
TRUNCATE TABLE quick_snap_comments CASCADE;
TRUNCATE TABLE quick_snap_reactions CASCADE;
TRUNCATE TABLE quick_snap_recipients CASCADE;
TRUNCATE TABLE quick_snaps CASCADE;
TRUNCATE TABLE chore_roulette_records CASCADE;
TRUNCATE TABLE bills CASCADE;
TRUNCATE TABLE messages CASCADE;
TRUNCATE TABLE conversation_members CASCADE;
TRUNCATE TABLE conversations CASCADE;
TRUNCATE TABLE item_responses CASCADE;
TRUNCATE TABLE items CASCADE;
TRUNCATE TABLE parcels CASCADE;
TRUNCATE TABLE maintenance_tasks CASCADE;
TRUNCATE TABLE meet_up_responses CASCADE;
TRUNCATE TABLE meet_up_invitations CASCADE;
TRUNCATE TABLE presence_events CASCADE;
TRUNCATE TABLE points_ledger CASCADE;
TRUNCATE TABLE household_invitations CASCADE;
TRUNCATE TABLE household_members CASCADE;
TRUNCATE TABLE households CASCADE;

-- 2. Remove mock demo accounts (preserves any real accounts you created)
DELETE FROM profiles 
WHERE id IN (
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444'
) OR handle IN ('@jp', '@maria', '@alex', '@ria');

DELETE FROM auth.users 
WHERE email IN (
    'jp@casama.app',
    'maria@casama.app',
    'alex@casama.app',
    'ria@casama.app'
);
