-- Casama Migration: Supabase Storage Buckets & Policies
-- Sets up public storage buckets for avatars, quicksnaps, item photos, and brand assets.

-- 1. Create public storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('avatars', 'avatars', true),
    ('quicksnaps', 'quicksnaps', true),
    ('items', 'items', true),
    ('item_photos', 'item_photos', true),
    ('brand_assets', 'brand_assets', true)
ON CONFLICT (id) DO NOTHING;

-- 2. RLS Policies for Storage Objects (Idempotent: Drop if exists before re-creating)
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
