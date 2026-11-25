-- Casama Seed Script (Clean Slate Mode)
-- Ensures database extensions and schema adjustments are in place without inserting mock data.
-- All feature sections will start completely empty for real users.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Ensure profile onboarding columns exist
ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS nickname TEXT,
ADD COLUMN IF NOT EXISTS age INT CHECK (age IS NULL OR (age >= 10 AND age <= 120)),
ADD COLUMN IF NOT EXISTS has_consented_terms BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS has_completed_onboarding BOOLEAN DEFAULT FALSE;
