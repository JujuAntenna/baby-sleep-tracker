-- ============================================================================
-- Baby Sleep Tracker v2 — Supabase Database Schema
-- ============================================================================
--
-- HOW TO RUN THIS:
--
-- 1. Go to your Supabase project dashboard: https://app.supabase.com
-- 2. Navigate to SQL Editor (left sidebar)
-- 3. Click "New query"
-- 4. Paste this entire file into the editor
-- 5. Click "Run" (or Cmd/Ctrl + Enter)
--
-- This script is idempotent-safe for first run. If you need to re-run,
-- drop the tables first (in reverse order) or use a fresh project.
--
-- Prerequisites:
--   - Supabase project with Auth enabled
--   - No existing tables with these names
--
-- ============================================================================


-- ============================================================================
-- 1. BABIES TABLE
-- Each authenticated user can track one or more babies.
-- ============================================================================

CREATE TABLE babies (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name        TEXT        NOT NULL,
    birth_date  DATE,                              -- nullable; user may not know exact date
    emoji       TEXT        DEFAULT '👶',
    created_at  TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE babies IS 'Babies tracked by each user. A user can have multiple babies.';


-- ============================================================================
-- 2. SLEEP_LOGS TABLE
-- Core data: each row is one sleep session (nap or night sleep).
-- end_time = NULL means the baby is currently sleeping.
-- ============================================================================

CREATE TABLE sleep_logs (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_id     UUID        NOT NULL REFERENCES babies(id) ON DELETE CASCADE,
    user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    start_time  TIMESTAMPTZ NOT NULL,
    end_time    TIMESTAMPTZ,                       -- NULL = currently sleeping
    type        TEXT        NOT NULL CHECK (type IN ('nap', 'night')),
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE sleep_logs IS 'Sleep sessions. end_time is NULL while the baby is still sleeping.';
COMMENT ON COLUMN sleep_logs.type IS 'Either ''nap'' or ''night''.';


-- ============================================================================
-- 3. SETTINGS TABLE
-- Per-baby, per-user preferences (schedule, language, etc.)
-- ============================================================================

CREATE TABLE settings (
    id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_id         UUID    NOT NULL REFERENCES babies(id) ON DELETE CASCADE,
    user_id         UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    morning_wake    TIME    DEFAULT '07:30',
    bedtime         TIME    DEFAULT '19:00',
    baby_age_months INTEGER DEFAULT 7,
    language        TEXT    DEFAULT 'en',

    UNIQUE (baby_id, user_id)
);

COMMENT ON TABLE settings IS 'Per-baby per-user preferences. One row per baby+user combination.';


-- ============================================================================
-- 4. RATINGS TABLE
-- Daily quality rating for each baby's sleep day (1–5 stars).
-- ============================================================================

CREATE TABLE ratings (
    id       UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    baby_id  UUID    NOT NULL REFERENCES babies(id) ON DELETE CASCADE,
    user_id  UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date     DATE    NOT NULL,
    score    INTEGER NOT NULL CHECK (score >= 1 AND score <= 5),

    UNIQUE (baby_id, date)
);

COMMENT ON TABLE ratings IS 'Daily sleep quality rating (1–5) per baby.';


-- ============================================================================
-- 5. INVITES TABLE
-- Optional invite code system for controlled signups.
-- ============================================================================

CREATE TABLE invites (
    code        TEXT        PRIMARY KEY,
    created_by  UUID        REFERENCES auth.users(id),   -- nullable (could be seeded)
    used_by     UUID        REFERENCES auth.users(id),   -- nullable until claimed
    created_at  TIMESTAMPTZ DEFAULT now(),
    used_at     TIMESTAMPTZ                              -- set when claimed
);

COMMENT ON TABLE invites IS 'Invite codes for controlled signups. used_by/used_at are set when claimed.';


-- ============================================================================
-- 6. INDEXES
-- ============================================================================

-- Fast lookups for "all sleep logs for a baby, ordered by time"
CREATE INDEX idx_sleep_logs_baby_start ON sleep_logs (baby_id, start_time);

-- Fast lookups for "all sleep logs by a user"
CREATE INDEX idx_sleep_logs_user ON sleep_logs (user_id);


-- ============================================================================
-- 7. TRIGGER: auto-update updated_at on sleep_logs
-- ============================================================================

-- Generic trigger function — sets updated_at to now() on every UPDATE
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sleep_logs_updated_at
    BEFORE UPDATE ON sleep_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();


-- ============================================================================
-- 8. ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on every table
ALTER TABLE babies     ENABLE ROW LEVEL SECURITY;
ALTER TABLE sleep_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE invites    ENABLE ROW LEVEL SECURITY;


-- --------------------------------------------------------------------------
-- BABIES policies — users can only access their own babies
-- --------------------------------------------------------------------------

CREATE POLICY "babies_select_own"
    ON babies FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "babies_insert_own"
    ON babies FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "babies_update_own"
    ON babies FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "babies_delete_own"
    ON babies FOR DELETE
    USING (user_id = auth.uid());


-- --------------------------------------------------------------------------
-- SLEEP_LOGS policies — users can only access their own logs
-- --------------------------------------------------------------------------

CREATE POLICY "sleep_logs_select_own"
    ON sleep_logs FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "sleep_logs_insert_own"
    ON sleep_logs FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "sleep_logs_update_own"
    ON sleep_logs FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "sleep_logs_delete_own"
    ON sleep_logs FOR DELETE
    USING (user_id = auth.uid());


-- --------------------------------------------------------------------------
-- SETTINGS policies — users can only access their own settings
-- --------------------------------------------------------------------------

CREATE POLICY "settings_select_own"
    ON settings FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "settings_insert_own"
    ON settings FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "settings_update_own"
    ON settings FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "settings_delete_own"
    ON settings FOR DELETE
    USING (user_id = auth.uid());


-- --------------------------------------------------------------------------
-- RATINGS policies — users can only access their own ratings
-- --------------------------------------------------------------------------

CREATE POLICY "ratings_select_own"
    ON ratings FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "ratings_insert_own"
    ON ratings FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "ratings_update_own"
    ON ratings FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "ratings_delete_own"
    ON ratings FOR DELETE
    USING (user_id = auth.uid());


-- --------------------------------------------------------------------------
-- INVITES policies
--   - Anyone authenticated can SELECT unused invites (to validate a code)
--   - Only authenticated users can UPDATE an invite (to claim it)
--   - INSERT/DELETE are admin-only (no policy = denied by RLS)
-- --------------------------------------------------------------------------

CREATE POLICY "invites_select_unused"
    ON invites FOR SELECT
    USING (used_by IS NULL);

CREATE POLICY "invites_update_claim"
    ON invites FOR UPDATE
    USING (used_by IS NULL)                        -- can only claim unclaimed codes
    WITH CHECK (used_by = auth.uid());             -- can only set used_by to yourself


-- ============================================================================
-- DONE! 🎉
-- Your schema is ready. Next steps:
--   1. Enable Email/Password auth (or any provider) in Supabase Auth settings
--   2. Connect your frontend with the Supabase JS client
--   3. Start tracking sleep! 😴
-- ============================================================================
