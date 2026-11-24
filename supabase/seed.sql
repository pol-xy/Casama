-- Casama Mockup Scenario Seed Data
-- Recreates the exact scenario from Casama Mockup Ui.png (Casa 204)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Ensure required columns exist on profiles table
ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS nickname TEXT,
ADD COLUMN IF NOT EXISTS age INT CHECK (age IS NULL OR (age >= 10 AND age <= 120)),
ADD COLUMN IF NOT EXISTS has_consented_terms BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS has_completed_onboarding BOOLEAN DEFAULT FALSE;

-- Ensure foreign key constraint does not block seed mock housemates in hosted Supabase
ALTER TABLE IF EXISTS profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

-- 1. Fixed UUIDs for reproducibility
DO $$
DECLARE
    v_household_id UUID := 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
    v_user_jp UUID := '11111111-1111-1111-1111-111111111111';
    v_user_maria UUID := '22222222-2222-2222-2222-222222222222';
    v_user_alex UUID := '33333333-3333-3333-3333-333333333333';
    v_user_ria UUID := '44444444-4444-4444-4444-444444444444';

    v_conv_group UUID := 'c0000000-0000-0000-0000-000000000001';
    v_conv_maria UUID := 'c0000000-0000-0000-0000-000000000002';
    v_conv_alex UUID := 'c0000000-0000-0000-0000-000000000003';
    v_conv_ria UUID := 'c0000000-0000-0000-0000-000000000004';

    v_parcel_shopee UUID := 'd0000000-0000-0000-0000-000000000001';
    v_parcel_lazada UUID := 'd0000000-0000-0000-0000-000000000002';

    v_meetup UUID := 'e0000000-0000-0000-0000-000000000001';
BEGIN
    -- 1.1 Create Auth Users first so profiles foreign key references succeed
    INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token
    ) VALUES
    (
        v_user_jp,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'jp@casama.app',
        crypt('password123', gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Jon Paul Berana","handle":"@jpberana"}'::jsonb,
        NOW(),
        NOW(),
        '',
        ''
    ),
    (
        v_user_maria,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'maria@casama.app',
        crypt('password123', gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Maria Santos","handle":"@maria"}'::jsonb,
        NOW(),
        NOW(),
        '',
        ''
    ),
    (
        v_user_alex,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'alex@casama.app',
        crypt('password123', gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Alex Rivera","handle":"@alex"}'::jsonb,
        NOW(),
        NOW(),
        '',
        ''
    ),
    (
        v_user_ria,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'ria@casama.app',
        crypt('password123', gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"full_name":"Ria Garcia","handle":"@ria"}'::jsonb,
        NOW(),
        NOW(),
        '',
        ''
    )
    ON CONFLICT (id) DO NOTHING;

    -- 1.2 Seed auth.identities so Supabase GoTrue recognizes email logins
    BEGIN
        INSERT INTO auth.identities (
            id,
            user_id,
            identity_data,
            provider,
            provider_id,
            last_sign_in_at,
            created_at,
            updated_at
        ) VALUES
        (
            v_user_jp,
            v_user_jp,
            format('{"sub":"%s","email":"%s"}', v_user_jp::text, 'jp@casama.app')::jsonb,
            'email',
            'jp@casama.app',
            NOW(),
            NOW(),
            NOW()
        ),
        (
            v_user_maria,
            v_user_maria,
            format('{"sub":"%s","email":"%s"}', v_user_maria::text, 'maria@casama.app')::jsonb,
            'email',
            'maria@casama.app',
            NOW(),
            NOW(),
            NOW()
        ),
        (
            v_user_alex,
            v_user_alex,
            format('{"sub":"%s","email":"%s"}', v_user_alex::text, 'alex@casama.app')::jsonb,
            'email',
            'alex@casama.app',
            NOW(),
            NOW(),
            NOW()
        ),
        (
            v_user_ria,
            v_user_ria,
            format('{"sub":"%s","email":"%s"}', v_user_ria::text, 'ria@casama.app')::jsonb,
            'email',
            'ria@casama.app',
            NOW(),
            NOW(),
            NOW()
        )
        ON CONFLICT DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 2. Create Mock Profiles
    INSERT INTO profiles (id, display_name, handle, avatar_url, full_name, nickname, age, has_consented_terms, has_completed_onboarding)
    VALUES
        (v_user_jp, 'Jon Paul Berana', '@jpberana', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80', 'Jon Paul Berana', 'JP', 21, true, true),
        (v_user_maria, 'Maria Santos', '@maria', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80', 'Maria Santos', 'Maria', 22, true, true),
        (v_user_alex, 'Alex Rivera', '@alex', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80', 'Alex Rivera', 'Alex', 20, true, true),
        (v_user_ria, 'Ria Garcia', '@ria', 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=200&q=80', 'Ria Garcia', 'Ria', 21, true, true)
    ON CONFLICT (id) DO UPDATE
    SET display_name = EXCLUDED.display_name,
        handle = EXCLUDED.handle,
        avatar_url = EXCLUDED.avatar_url,
        full_name = EXCLUDED.full_name,
        nickname = EXCLUDED.nickname,
        age = EXCLUDED.age,
        has_consented_terms = EXCLUDED.has_consented_terms,
        has_completed_onboarding = EXCLUDED.has_completed_onboarding;

    -- 3. Create Household Casa 204
    INSERT INTO households (id, name, invite_code, created_by)
    VALUES (v_household_id, 'Casa 204', 'CASA204', v_user_jp)
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, invite_code = EXCLUDED.invite_code;

    -- 4. Assign Members
    INSERT INTO household_members (household_id, user_id, role)
    VALUES
        (v_household_id, v_user_jp, 'owner'),
        (v_household_id, v_user_maria, 'member'),
        (v_household_id, v_user_alex, 'member'),
        (v_household_id, v_user_ria, 'member')
    ON CONFLICT (household_id, user_id) DO NOTHING;

    -- 5. Seed Presence (Mockup Screen 2: JP=Home, Maria=Home, Alex=Out, Ria=Home)
    INSERT INTO presence_events (household_id, user_id, is_home, note)
    VALUES
        (v_household_id, v_user_jp, true, 'Studying'),
        (v_household_id, v_user_maria, true, 'In living room'),
        (v_household_id, v_user_alex, false, 'At class until 5 PM'),
        (v_household_id, v_user_ria, true, 'Resting');

    -- 6. Seed Parcels (Mockup Screen 3)
    INSERT INTO parcels (id, household_id, buyer_id, courier, expected_arrival, payment_type, cod_amount, notes, status)
    VALUES
        (v_parcel_shopee, v_household_id, v_user_maria, 'Shopee', NOW() + INTERVAL '2 hours', 'cod', 350.00, 'Fragile - Handle with care!', 'expected'),
        (v_parcel_lazada, v_household_id, v_user_alex, 'Lazada', NOW() + INTERVAL '3 days', 'paid', NULL, 'For group use', 'expected')
    ON CONFLICT (id) DO NOTHING;

    -- Roommate availability for Shopee parcel
    INSERT INTO parcel_availability (household_id, parcel_id, user_id, is_available)
    VALUES
        (v_household_id, v_parcel_shopee, v_user_jp, true),
        (v_household_id, v_parcel_shopee, v_user_alex, false),
        (v_household_id, v_parcel_shopee, v_user_ria, true)
    ON CONFLICT (parcel_id, user_id) DO NOTHING;

    -- 7. Seed Lost & Found Items (Mockup Screen 4)
    INSERT INTO items (household_id, type, title, description, status, reported_by)
    VALUES
        (v_household_id, 'lost', 'Lost AirPods', 'Last seen in the study area.', 'open', v_user_jp),
        (v_household_id, 'found', 'Found Backpack', 'Unclaimed in common area.', 'unclaimed', v_user_maria);

    -- 8. Seed Maintenance Tasks (Mockup Screen 5)
    INSERT INTO maintenance_tasks (household_id, title, category, urgency, status, assignee_id, created_by)
    VALUES
        (v_household_id, 'Leaking Faucet', 'landlord', 'urgent', 'open', v_user_alex, v_user_jp),
        (v_household_id, 'Buy Drinking Water', 'restock', 'medium', 'open', v_user_jp, v_user_maria),
        (v_household_id, 'Defrost Freezer', 'diy', 'low', 'open', v_user_ria, v_user_alex);

    -- 9. Seed Good Kasama Points Ledger (JP has 120 pts in Mockup Screen 9)
    INSERT INTO points_ledger (household_id, user_id, action_type, points, reference_id)
    VALUES
        (v_household_id, v_user_jp, 'seed_historical_1', 50, gen_random_uuid()),
        (v_household_id, v_user_jp, 'seed_historical_2', 40, gen_random_uuid()),
        (v_household_id, v_user_jp, 'seed_historical_3', 30, gen_random_uuid()),
        (v_household_id, v_user_maria, 'seed_maria_1', 85, gen_random_uuid()),
        (v_household_id, v_user_alex, 'seed_alex_1', 65, gen_random_uuid()),
        (v_household_id, v_user_ria, 'seed_ria_1', 55, gen_random_uuid())
    ON CONFLICT (user_id, action_type, reference_id) DO NOTHING;

    -- 10. Seed Casama Connect (Mockup Screens 6 & 7)
    INSERT INTO conversations (id, household_id, type, name)
    VALUES
        (v_conv_group, v_household_id, 'group', 'Casa 204'),
        (v_conv_maria, v_household_id, 'direct', 'Maria'),
        (v_conv_alex, v_household_id, 'direct', 'Alex'),
        (v_conv_ria, v_household_id, 'direct', 'Ria')
    ON CONFLICT (id) DO NOTHING;

    -- Add members to group
    INSERT INTO conversation_members (conversation_id, user_id)
    VALUES
        (v_conv_group, v_user_jp),
        (v_conv_group, v_user_maria),
        (v_conv_group, v_user_alex),
        (v_conv_group, v_user_ria),
        (v_conv_maria, v_user_jp),
        (v_conv_maria, v_user_maria),
        (v_conv_alex, v_user_jp),
        (v_conv_alex, v_user_alex),
        (v_conv_ria, v_user_jp),
        (v_conv_ria, v_user_ria)
    ON CONFLICT (conversation_id, user_id) DO NOTHING;

    -- Seed Group Chat Messages
    INSERT INTO messages (conversation_id, sender_id, content, client_message_id)
    VALUES
        (v_conv_group, v_user_maria, 'Hey everyone! Who''s available to receive my parcel tomorrow?', 'seed_msg_1'),
        (v_conv_group, v_user_jp, 'I''m available after 2 PM! I can receive it. 😊', 'seed_msg_2'),
        (v_conv_group, v_user_alex, 'Thanks! Just let us know when it arrives.', 'seed_msg_3')
    ON CONFLICT (conversation_id, client_message_id) DO NOTHING;

    -- Seed Direct Messages
    INSERT INTO messages (conversation_id, sender_id, content, client_message_id)
    VALUES
        (v_conv_maria, v_user_jp, 'Got it! 👍', 'seed_dm_m1'),
        (v_conv_alex, v_user_alex, 'See you later!', 'seed_dm_a1'),
        (v_conv_ria, v_user_ria, 'Sent a photo 📷', 'seed_dm_r1')
    ON CONFLICT (conversation_id, client_message_id) DO NOTHING;

    -- 11. Seed Meet-up Invitation (Screen 7 & 8)
    INSERT INTO meet_up_invitations (id, conversation_id, creator_id, activity, location, scheduled_time)
    VALUES (v_meetup, v_conv_group, v_user_jp, 'Study Session 🎓', 'Dorm Common Area', NOW() + INTERVAL '5 hours')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO meet_up_responses (invitation_id, user_id, response)
    VALUES
        (v_meetup, v_user_jp, 'going'),
        (v_meetup, v_user_maria, 'going'),
        (v_meetup, v_user_alex, 'maybe'),
        (v_meetup, v_user_ria, 'going')
    ON CONFLICT (invitation_id, user_id) DO NOTHING;

    -- 12. Seed Activity / Notifications
    INSERT INTO notifications (household_id, user_id, type, payload)
    VALUES
        (v_household_id, v_user_jp, 'parcel_expected', '{"message": "Your parcel is expected today at 4 PM!"}'::jsonb);

    -- 13. Seed Household Bills & Payments (Screen: Bills & Payments)
    INSERT INTO bills (
        id, household_id, title, category, amount, deadline, status,
        reminder_enabled, reminder_timing, recipient_type, responsible_member, created_by, created_by_name, notes
    ) VALUES
    (
        'b0000000-0000-0000-0000-000000000001',
        v_household_id,
        'Meralco Electricity Bill',
        'electricity',
        2450.00,
        NOW() + INTERVAL '5 days',
        'unpaid',
        true,
        'one_day_before',
        'all_members',
        'Maria Santos',
        v_user_jp,
        'Jon Paul Berana',
        'Includes AC usage for November'
    ),
    (
        'b0000000-0000-0000-0000-000000000002',
        v_household_id,
        'Maynilad Water Bill',
        'water',
        680.00,
        NOW() + INTERVAL '8 days',
        'unpaid',
        true,
        'one_day_before',
        'all_members',
        'Alex Rivera',
        v_user_jp,
        'Jon Paul Berana',
        'Main line water consumption'
    ),
    (
        'b0000000-0000-0000-0000-000000000003',
        v_household_id,
        'Converge Fiber Internet',
        'internet',
        1500.00,
        NOW() - INTERVAL '2 days',
        'paid',
        true,
        'one_day_before',
        'all_members',
        'Jon Paul Berana',
        v_user_jp,
        'Jon Paul Berana',
        'Settled on time via GCash'
    )
    ON CONFLICT (id) DO NOTHING;

    -- 14. Seed Chore Roulette History
    INSERT INTO chore_roulette_records (
        id, household_id, chore_title, assigned_user_id, assigned_user_name,
        spun_by_user_id, spun_by_name, is_personal_mode, status, created_at, completed_at
    ) VALUES
    (
        'f0000000-0000-0000-0000-000000000001',
        v_household_id,
        'Clean Kitchen Sink',
        v_user_alex,
        'Alex Rivera',
        v_user_jp,
        'Jon Paul Berana',
        false,
        'pending',
        NOW() - INTERVAL '1 day',
        NULL
    ),
    (
        'f0000000-0000-0000-0000-000000000002',
        v_household_id,
        'Take Out Garbage',
        v_user_jp,
        'Jon Paul Berana',
        v_user_jp,
        'Jon Paul Berana',
        true,
        'completed',
        NOW() - INTERVAL '2 days',
        NOW() - INTERVAL '2 days' + INTERVAL '30 minutes'
    )
    ON CONFLICT (id) DO NOTHING;

END;
$$;

