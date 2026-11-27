-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  display_name text NOT NULL,
  handle text UNIQUE,
  avatar_url text,
  created_at timestamp with time zone DEFAULT now(),
  full_name text,
  nickname text,
  has_consented_terms boolean DEFAULT false,
  has_completed_onboarding boolean DEFAULT false,
  birthday date CHECK (birthday IS NULL OR birthday >= '1900-01-01'::date AND birthday <= CURRENT_DATE),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.households (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  invite_code text NOT NULL UNIQUE,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT households_pkey PRIMARY KEY (id),
  CONSTRAINT households_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.household_members (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'member'::text CHECK (role = ANY (ARRAY['owner'::text, 'member'::text])),
  joined_at timestamp with time zone DEFAULT now(),
  CONSTRAINT household_members_pkey PRIMARY KEY (id),
  CONSTRAINT household_members_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT household_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.presence_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  user_id uuid NOT NULL,
  is_home boolean NOT NULL,
  note text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT presence_events_pkey PRIMARY KEY (id),
  CONSTRAINT presence_events_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT presence_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.parcels (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  buyer_id uuid NOT NULL,
  courier text NOT NULL,
  expected_arrival timestamp with time zone NOT NULL,
  payment_type text NOT NULL CHECK (payment_type = ANY (ARRAY['paid'::text, 'cod'::text])),
  cod_amount numeric,
  currency text DEFAULT 'PHP'::text,
  status text NOT NULL DEFAULT 'expected'::text CHECK (status = ANY (ARRAY['expected'::text, 'arrived'::text, 'received'::text, 'cancelled'::text])),
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  reminder_sent boolean NOT NULL DEFAULT false,
  arrival_handled boolean NOT NULL DEFAULT false,
  CONSTRAINT parcels_pkey PRIMARY KEY (id),
  CONSTRAINT parcels_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT parcels_buyer_id_fkey FOREIGN KEY (buyer_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.parcel_availability (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  parcel_id uuid NOT NULL,
  user_id uuid NOT NULL,
  is_available boolean NOT NULL,
  note text,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT parcel_availability_pkey PRIMARY KEY (id),
  CONSTRAINT parcel_availability_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT parcel_availability_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT parcel_availability_parcel_id_fkey FOREIGN KEY (parcel_id) REFERENCES public.parcels(id)
);
CREATE TABLE public.parcel_claims (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  parcel_id uuid NOT NULL UNIQUE,
  receiver_id uuid NOT NULL,
  received_at timestamp with time zone DEFAULT now(),
  amount_owed numeric,
  settled boolean NOT NULL DEFAULT false,
  settled_at timestamp with time zone,
  CONSTRAINT parcel_claims_pkey PRIMARY KEY (id),
  CONSTRAINT parcel_claims_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT parcel_claims_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.profiles(id),
  CONSTRAINT parcel_claims_parcel_id_fkey FOREIGN KEY (parcel_id) REFERENCES public.parcels(id)
);
CREATE TABLE public.maintenance_tasks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  title text NOT NULL,
  category text NOT NULL CHECK (category = ANY (ARRAY['cleaning'::text, 'repair_maintenance'::text, 'restock'::text, 'personal_request'::text])),
  urgency text NOT NULL CHECK (urgency = ANY (ARRAY['low'::text, 'medium'::text, 'urgent'::text])),
  status text NOT NULL DEFAULT 'open'::text CHECK (status = ANY (ARRAY['open'::text, 'in_progress'::text, 'done'::text])),
  created_by uuid NOT NULL,
  completed_by uuid,
  completed_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  description text,
  due_date timestamp with time zone,
  due_reminder_sent boolean NOT NULL DEFAULT false,
  overdue_notified boolean NOT NULL DEFAULT false,
  CONSTRAINT maintenance_tasks_pkey PRIMARY KEY (id),
  CONSTRAINT maintenance_tasks_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT maintenance_tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
  CONSTRAINT maintenance_tasks_completed_by_fkey FOREIGN KEY (completed_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.points_ledger (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  user_id uuid NOT NULL,
  action_type text NOT NULL,
  points integer NOT NULL,
  reference_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT points_ledger_pkey PRIMARY KEY (id),
  CONSTRAINT points_ledger_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT points_ledger_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.conversations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['group'::text, 'direct'::text, 'space'::text])),
  name text,
  created_at timestamp with time zone DEFAULT now(),
  icon text,
  description text,
  created_by uuid,
  CONSTRAINT conversations_pkey PRIMARY KEY (id),
  CONSTRAINT conversations_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT conversations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.conversation_members (
  conversation_id uuid NOT NULL,
  user_id uuid NOT NULL,
  joined_at timestamp with time zone DEFAULT now(),
  CONSTRAINT conversation_members_pkey PRIMARY KEY (conversation_id, user_id),
  CONSTRAINT conversation_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT conversation_members_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  client_message_id text NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now(),
  attachment_url text,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.housemates_agenda_invitations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  creator_id uuid NOT NULL,
  activity text NOT NULL,
  location text NOT NULL,
  scheduled_time timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  status text NOT NULL DEFAULT 'upcoming'::text CHECK (status = ANY (ARRAY['upcoming'::text, 'ongoing'::text, 'done'::text, 'missed'::text])),
  reminder_sent boolean NOT NULL DEFAULT false,
  arrival_handled boolean NOT NULL DEFAULT false,
  CONSTRAINT housemates_agenda_invitations_pkey PRIMARY KEY (id),
  CONSTRAINT meet_up_invitations_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.profiles(id),
  CONSTRAINT meet_up_invitations_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
);
CREATE TABLE public.housemates_agenda_responses (
  invitation_id uuid NOT NULL,
  user_id uuid NOT NULL,
  response text NOT NULL CHECK (response = ANY (ARRAY['going'::text, 'maybe'::text, 'cant_make_it'::text])),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT housemates_agenda_responses_pkey PRIMARY KEY (invitation_id, user_id),
  CONSTRAINT meet_up_responses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT housemates_agenda_responses_invitation_id_fkey FOREIGN KEY (invitation_id) REFERENCES public.housemates_agenda_invitations(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  user_id uuid NOT NULL,
  type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.bills (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  title text NOT NULL,
  category text NOT NULL CHECK (category = ANY (ARRAY['electricity'::text, 'water'::text, 'internet'::text, 'appliance'::text, 'rent'::text, 'association_dues'::text, 'gas'::text, 'maintenance_fee'::text, 'other'::text])),
  custom_category_name text,
  amount numeric NOT NULL CHECK (amount >= 0::numeric),
  deadline timestamp with time zone NOT NULL,
  status text NOT NULL DEFAULT 'unpaid'::text CHECK (status = ANY (ARRAY['unpaid'::text, 'paid'::text, 'overdue'::text])),
  responsible_member text,
  notes text,
  reminder_enabled boolean NOT NULL DEFAULT true,
  reminder_timing text NOT NULL DEFAULT 'one_day_before'::text CHECK (reminder_timing = ANY (ARRAY['on_due_date'::text, 'one_day_before'::text, 'three_days_before'::text, 'one_week_before'::text])),
  recipient_type text NOT NULL DEFAULT 'all_members'::text CHECK (recipient_type = ANY (ARRAY['all_members'::text, 'specific_members'::text])),
  created_by uuid,
  created_by_name text,
  paid_at timestamp with time zone,
  paid_by uuid,
  paid_by_name text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT bills_pkey PRIMARY KEY (id),
  CONSTRAINT bills_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT bills_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
  CONSTRAINT bills_paid_by_fkey FOREIGN KEY (paid_by) REFERENCES public.profiles(id)
);
CREATE TABLE public.quick_snaps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  creator_id uuid NOT NULL,
  creator_name text NOT NULL,
  image_url text NOT NULL,
  caption text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT quick_snaps_pkey PRIMARY KEY (id),
  CONSTRAINT quick_snaps_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT quick_snaps_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.quick_snap_reactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  snap_id uuid NOT NULL,
  user_id uuid NOT NULL,
  user_name text NOT NULL,
  emoji text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  count integer NOT NULL DEFAULT 1 CHECK (count >= 1),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT quick_snap_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT quick_snap_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT quick_snap_reactions_snap_id_fkey FOREIGN KEY (snap_id) REFERENCES public.quick_snaps(id)
);
CREATE TABLE public.quick_snap_comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  snap_id uuid NOT NULL,
  user_id uuid NOT NULL,
  user_name text NOT NULL,
  user_avatar text,
  message text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT quick_snap_comments_pkey PRIMARY KEY (id),
  CONSTRAINT quick_snap_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT quick_snap_comments_snap_id_fkey FOREIGN KEY (snap_id) REFERENCES public.quick_snaps(id)
);
CREATE TABLE public.chore_roulette_records (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  chore_title text,
  selected_user_id uuid,
  selected_user_name text,
  spun_by_user_id uuid,
  spun_by_name text,
  status text NOT NULL DEFAULT 'assigned'::text CHECK (status = ANY (ARRAY['assigned'::text, 'completed'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone,
  task_id uuid UNIQUE,
  bonus_points integer NOT NULL DEFAULT 4 CHECK (bonus_points >= 0),
  CONSTRAINT chore_roulette_records_pkey PRIMARY KEY (id),
  CONSTRAINT chore_roulette_records_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT chore_roulette_records_assigned_user_id_fkey FOREIGN KEY (selected_user_id) REFERENCES public.profiles(id),
  CONSTRAINT chore_roulette_records_spun_by_user_id_fkey FOREIGN KEY (spun_by_user_id) REFERENCES public.profiles(id),
  CONSTRAINT chore_roulette_records_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.maintenance_tasks(id)
);
CREATE TABLE public.conversation_reads (
  conversation_id uuid NOT NULL,
  user_id uuid NOT NULL,
  last_read_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT conversation_reads_pkey PRIMARY KEY (conversation_id, user_id),
  CONSTRAINT conversation_reads_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT conversation_reads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.lost_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  owner_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  last_seen_location text,
  image_url text,
  status text NOT NULL DEFAULT 'open'::text CHECK (status = ANY (ARRAY['open'::text, 'resolved'::text])),
  found_by_id uuid,
  found_at timestamp with time zone,
  returned_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  resolved_found_item_id uuid,
  CONSTRAINT lost_items_pkey PRIMARY KEY (id),
  CONSTRAINT lost_items_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT lost_items_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id),
  CONSTRAINT lost_items_found_by_id_fkey FOREIGN KEY (found_by_id) REFERENCES public.profiles(id),
  CONSTRAINT lost_items_resolved_found_item_id_fkey FOREIGN KEY (resolved_found_item_id) REFERENCES public.found_items(id)
);
CREATE TABLE public.found_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL,
  finder_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  found_location text,
  image_url text,
  status text NOT NULL DEFAULT 'unclaimed'::text,
  claimed_by_id uuid,
  claimed_at timestamp with time zone,
  returned_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  lost_item_id uuid,
  rejected_at timestamp with time zone,
  CONSTRAINT found_items_pkey PRIMARY KEY (id),
  CONSTRAINT found_items_claimed_by_id_fkey FOREIGN KEY (claimed_by_id) REFERENCES public.profiles(id),
  CONSTRAINT found_items_household_id_fkey FOREIGN KEY (household_id) REFERENCES public.households(id),
  CONSTRAINT found_items_finder_id_fkey FOREIGN KEY (finder_id) REFERENCES public.profiles(id),
  CONSTRAINT found_items_lost_item_id_fkey FOREIGN KEY (lost_item_id) REFERENCES public.lost_items(id)
);