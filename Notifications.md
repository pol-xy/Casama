# Casama Notifications & Automated Messaging Architecture

This document describes how in-app notifications (`public.notifications`), automated Group Chat messages (`public.messages`), live Realtime updates, and delete-cleanup work across Casama's Supabase backend and Flutter client.

---

## 1. Architecture Overview

Casama's notification and automated messaging pipeline is driven server-side by PostgreSQL triggers, atomic RPCs, and 1-minute UTC `pg_cron` jobs, paired with live `supabase_realtime` synchronization on the Flutter client:

- **PostgreSQL Triggers & Atomic RPCs:** Domain writes (`parcels`, `parcel_claims`, `maintenance_tasks`, `lost_items`, `found_items`, `housemates_agenda_invitations`, `spin_task_roulette`) generate `public.notifications` rows and automated `public.messages` rows directly inside the database transaction—preventing duplicate client-side inserts.
- **1-Minute UTC `pg_cron` Jobs:** Two scheduled jobs (`casama_housemates_agenda_automations` and `casama_board_automations`) handle time-based reminders, status transitions, and arrival announcements in UTC.
- **Live Realtime Sync (`REPLICA IDENTITY FULL`):**
  - `public.notifications` is published to `supabase_realtime` with `REPLICA IDENTITY FULL` so `DELETE` events include `oldRecord['id']`.
  - `SupabaseRepository` subscribes to dedicated `PostgresChangeEvent.insert`, `PostgresChangeEvent.update`, and unfiltered `PostgresChangeEvent.delete` listeners on `public.notifications` (`lib/data/supabase_repository.dart`) for instant UI updates in `CasamaNotificationBellButton` and `CasamaNotificationsSheet`.
- **Automatic Delete Cleanup:** Deleting any parent entity (parcel, task, lost item, found item, or Housemates Agenda) removes its generated rows in `public.notifications`, which propagate live to connected devices via Realtime `DELETE`.

---

## 2. In-App Notifications (`public.notifications`)

All active notification types are classified by `HouseholdNotificationItem` (`lib/data/models.dart`) and rendered/routed by `CasamaNotificationsSheet` (`lib/shared/widgets/casama_notifications_sheet.dart`). Verbatim `payload['title']` and `payload['message']` are always prioritized when present, with safe per-type fallbacks and graceful filtering of retired legacy types.

### A. `pg_cron`-Driven Notifications (1-Minute UTC Jobs)

#### 1. `casama_housemates_agenda_automations`
| Notification `type` | Trigger Window / Condition | Tracking Flag & Status Transition | Creator vs. Housemate Wording | Destination on Tap |
| --- | --- | --- | --- | --- |
| `housemates_agenda_reminder` | `scheduled_time` is within the upcoming reminder window (`<= now() + interval '1 hour'` and `> now()`) while `status = 'upcoming'` | Sets `reminder_sent = true` | **Creator** (`creator_id`) receives host reminder copy; **housemates** receive invitee reminder copy with RSVP/location context | Group Chat (`/group-chat` or Space if `conversation_id` is a Space) |
| `housemates_agenda_started` | `scheduled_time <= now()` while `status = 'upcoming'` | Transitions `status: 'upcoming' → 'ongoing'`, sets `arrival_handled = true` | Notifies household members that the agenda is starting now | Group Chat (`/group-chat` or Space) |
| *(Status transition only)* | `scheduled_time + interval '2 hours' <= now()` while `status = 'ongoing'` | Transitions `status: 'ongoing' → 'missed'` | — | — |

#### 2. `casama_board_automations`
| Notification `type` | Trigger Window / Condition | Tracking Flag & Status Transition | Creator / Buyer vs. Housemate Wording | Destination on Tap |
| --- | --- | --- | --- | --- |
| `parcel_reminder` | Unclaimed `expected` parcel approaching `expected_arrival` | Sets `reminder_sent` (when applicable) | Alerts housemates/buyer of upcoming delivery window & COD amount if applicable | **Boards → Parcels** |
| `parcel_arrived` | Unclaimed parcel with `status = 'expected'` and `expected_arrival <= now()` | Transitions `status: 'expected' → 'arrived'` | Alerts buyer & housemates that the parcel is **Arriving Now** at the gate/lobby | **Boards → Parcels** |
| `task_due_soon` | Open task approaching `due_date` | Sets `due_reminder_sent = true` | Reminds household members before the deadline | **Boards → Tasks** |
| `task_overdue` | Open task past `due_date <= now()` | Sets `overdue_notified = true` | Alerts household members that the task is overdue | **Boards → Tasks** |

---

### B. User-Interaction-Driven In-App Notifications

#### Parcels (`entity_type = 'parcel'`) → **Boards → Parcels**
| `type` | Trigger / Source | Recipients | Key `payload` Fields | Points Pill |
| --- | --- | --- | --- | --- |
| `parcel_posted` | `parcels` `AFTER INSERT` | Other household members | `entity_id`, `parcel_id`, `actor_id`, `courier`, `cod_amount`, `title`, `message` | — |
| `parcel_claimed` *(legacy: `parcel_received`)* | `parcel_claims` `AFTER INSERT` | Parcel buyer (`buyer_id`) | `entity_id`, `parcel_id`, `actor_id`, `receiver_id`, `receiver_name`, `courier`, `points` (`5` if claimed by housemate, `0` on self-claim), `title`, `message` | `+5 pts` *(when `points > 0`)* |
| `parcel_settled` | `parcel_claims` `AFTER UPDATE` (`settled = true`) | Claiming housemate / buyer | `entity_id`, `parcel_id`, `actor_id`, `courier`, `title`, `message` | — |
| `parcel_cancelled` | `parcels` `AFTER UPDATE` (`status = 'cancelled'`) | Other household members | `entity_id`, `parcel_id`, `actor_id`, `courier`, `title`, `message` | — |

#### Household Tasks & Task Roulette (`entity_type = 'task'`) → **Boards → Tasks**
| `type` | Trigger / Source | Recipients | Key `payload` Fields | Points Pill |
| --- | --- | --- | --- | --- |
| `task_created` | `maintenance_tasks` `AFTER INSERT` | Other household members | `entity_id`, `task_id`, `actor_id`, `task_title`, `title`, `message` | — |
| `task_completed` | `maintenance_tasks` `AFTER UPDATE` (`status = 'done'`) | Task creator / household | `entity_id`, `task_id`, `actor_id`, `task_title`, `points`, `is_self_created`, `title`, `message` | `+<points> pts` *(hidden if `is_self_created` or `points == 0`)* |
| `roulette_chosen` | `spin_task_roulette(p_task_id, p_selected_user_id)` RPC | Chosen housemate (`selected_user_id`) | `entity_id`, `task_id`, `roulette_id`, `spinner_id`, `spinner_name`, `selected_user_id`, `task_title`, `base_points`, `bonus_points` (`4`), `total_points`, `title`, `message` | `+4 bonus pts` *(strictly for chosen housemate; hidden if self-request)* |

> **Task Roulette Bonus & Eligibility Rules:**
> - `spin_task_roulette` excludes `task.created_by` (`'The task creator cannot be chosen by Task Roulette'`), while keeping the spinner and all other household members eligible.
> - Only the chosen housemate (`currentUserId == record.selectedUserId`) receives the `+4` bonus points (`computedPoints + 4`); any other non-creator housemate or non-chosen spinner who completes the task earns `computedPoints` only, and the task creator earns `0 pts`.

#### Lost & Found (`entity_type = 'lost_item'` / `'found_item'`) → **Boards → Items**
| `type` | Trigger / Source | Recipients | Key `payload` Fields | Points Pill |
| --- | --- | --- | --- | --- |
| `lost_item_posted` | `lost_items` `AFTER INSERT` | Other household members | `entity_id`, `lost_item_id`, `actor_id`, `item_title`, `title`, `message` | — |
| `lost_item_find_submitted` | `found_items` `AFTER INSERT` (linked `lost_item_id`) | Lost item poster | `entity_id`, `lost_item_id`, `found_item_id`, `actor_id`, `item_title`, `title`, `message` | — |
| `lost_item_find_accepted` | Match confirmed (`lost_items` / `found_items` resolved) | Finder (`finder_id`) | `entity_id`, `lost_item_id`, `found_item_id`, `actor_id`, `item_title`, `points` (`5`), `title`, `message` | `+5 pts` |
| `lost_item_find_rejected` | Match rejected (`found_items.status = 'rejected'`) | Finder (`finder_id`) | `entity_id`, `lost_item_id`, `found_item_id`, `actor_id`, `item_title`, `title`, `message` | — |
| `lost_item_self_resolved` | Owner marks own lost item resolved | Household / pending finders | `entity_id`, `lost_item_id`, `actor_id`, `item_title`, `title`, `message` | — |
| `found_item_posted` | `found_items` `AFTER INSERT` (standalone) | Other household members | `entity_id`, `found_item_id`, `actor_id`, `item_title`, `title`, `message` | — |
| `found_item_claimed` | Standalone found item claimed | Finder (`finder_id`) | `entity_id`, `found_item_id`, `actor_id`, `item_title`, `points` (`2`), `title`, `message` | `+2 pts` |

#### Housemates Agenda (`entity_type = 'housemates_agenda'`) → **Chat / Group Chat**
| `type` | Trigger / Source | Recipients | Key `payload` Fields | Destination on Tap |
| --- | --- | --- | --- | --- |
| `housemates_agenda_created` | `housemates_agenda_invitations` `AFTER INSERT` | Other household members | `entity_id`, `invitation_id`, `creator_id`, `location`, `title`, `message` | Chat Directory (`/chat`) or Space if `conversation_id` matches |
| `housemates_agenda_resolved` | `housemates_agenda_invitations` `AFTER UPDATE` (`done` / `missed`) | Household members | `entity_id`, `invitation_id`, `creator_id`, `location`, `title`, `message` | Chat Directory (`/chat`) or Space |

*(Legacy `meetup_reminder` payloads remain supported and route to Group Chat.)*

#### Household Updates (`entity_type = 'household'`) → **Home**
| `type` | Trigger / Source | Recipients | Key `payload` Fields | Destination on Tap |
| --- | --- | --- | --- | --- |
| `housemate_joined` | `joinHouseholdByCode` client insert on new `household_members` membership | Other household members | `entity_type`, `actor_id`, `actor_name`, `household_name`, `title`, `message` | **Home** (`/home`) |

---

## 3. Automated Group Chat Messages (`public.messages`)

Automated announcements are inserted directly into the household's Group Chat (`conversations` where `type = 'household'`) with deterministic `client_message_id` keys (`ON CONFLICT (conversation_id, client_message_id) DO NOTHING`) so retries or cron ticks never duplicate messages.

### A. `pg_cron` Auto-Messages
| Event | Deterministic `client_message_id` | Sender (`sender_id`) | Template / Purpose |
| --- | --- | --- | --- |
| **Housemates Agenda Start** (`upcoming → ongoing`) | `housemates_agenda_arrival_<invitation_id>` | `creator_id` | Announces the agenda is starting now at `<location>` |
| **Parcel ETA Arrival** (`expected → arrived`) | `parcel_arrived_<parcel_id>` | `buyer_id` | Roommate-voiced alert that `<courier>` delivery for `<buyer>` is arriving now |

### B. In-App Action Auto-Messages
| Action | Deterministic `client_message_id` | Sender (`sender_id`) | Template / Behavior |
| --- | --- | --- | --- |
| **Lost Item Posted** | `lost_item_posted_<lost_item_id>` | `owner_id` (`reported_by`) | Alerts Group Chat about the newly reported missing item |
| **Standalone Found Item Posted** | `found_item_posted_<found_item_id>` | `finder_id` (`reported_by`) | Alerts Group Chat about an unclaimed found item |
| **Ask the Wheel (Group Chat)** | Client-generated UUID (`const Uuid().v4()`) | Current user (`sendChatMessage`) | Pure chat message (`TaskRouletteMode.chatQuestion`, zero `chore_roulette_records` writes):<br><br>`🎡 Just spun the wheel!`<br>`"<question>"`<br>`👉 Landed on: <winner>! 🎉` *(or `👉 Landed on: me! 😂` when landing on self)* |

---

## 4. Delete Cleanup, Timezone & Idempotency Rules

- **Cascade Delete Cleanup & Realtime `DELETE`:**
  - Deleting a parcel, task, lost item, found item, or Housemates Agenda automatically deletes its associated `public.notifications` rows on the backend.
  - Because `public.notifications` uses `REPLICA IDENTITY FULL`, `SupabaseRepository` receives `PostgresChangeEvent.delete` payloads with `oldRecord['id']` and immediately removes matching rows via `SupabaseRepository.applyNotificationRealtimeDelete` (`lib/data/supabase_repository.dart`).
  - `MockRepository` mirrors this behavior via `_purgeNotificationsForEntity` and `HouseholdNotificationItem.matchesEntity`.
- **Strict UTC Timestamp Handling:**
  - All `timestamptz` fields (`created_at`, `read_at`, `scheduled_time`, `expected_arrival`, `due_date`, `completed_at`) are serialized in UTC ending in `Z` via `toSupabaseUtcIso` / `nowSupabaseUtcIso()` (`lib/core/utils/date_time_utils.dart`) and converted to local device time via `parseSupabaseTimestamp(...).toLocal()` on hydration.
- **Points Deduplication:**
  - `points_ledger` enforces a composite unique constraint `(user_id, action_type, reference_id)` so retries or Realtime refreshes never double-award points.
