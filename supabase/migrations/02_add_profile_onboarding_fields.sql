-- Migration: Add optional profile fields & onboarding tracking
-- Supports Full Name, Nickname, Age, and Onboarding Consent state

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS nickname TEXT,
ADD COLUMN IF NOT EXISTS age INT CHECK (age IS NULL OR (age >= 10 AND age <= 120)),
ADD COLUMN IF NOT EXISTS has_consented_terms BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS has_completed_onboarding BOOLEAN DEFAULT FALSE;

-- Document comments
COMMENT ON COLUMN profiles.full_name IS 'Optional full legal or preferred name';
COMMENT ON COLUMN profiles.nickname IS 'Optional short nickname used for greetings and chats';
COMMENT ON COLUMN profiles.age IS 'Optional user age for household matching';
COMMENT ON COLUMN profiles.has_consented_terms IS 'Records user agreement to Terms and Privacy Policy';
COMMENT ON COLUMN profiles.has_completed_onboarding IS 'Tracks completion of initial walkthrough';

