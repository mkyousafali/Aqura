-- ============================================================
-- Migration: Remove AI Marketing Feature
-- Date: 2026-05-17
-- Description: Drops all tables, triggers, functions, policies,
--              indexes, storage bucket, and sidebar button that
--              belong exclusively to the AI Marketing feature.
--              Tables shared with other features are NOT touched.
-- Rollback: Restore from backup or re-run the original
--           20260423_ai_marketing_schema.sql migration.
-- ============================================================

-- ── STEP 1: Remove sidebar button entry ─────────────────────
DELETE FROM public.sidebar_buttons WHERE button_code = 'AI_MARKETING';

-- ── STEP 2: Drop child tables first (FK deps) ────────────────

-- ai_marketing_file_products → references ai_marketing_files
DROP TABLE IF EXISTS public.ai_marketing_file_products CASCADE;

-- ai_marketing_versions → references ai_marketing_files
DROP TABLE IF EXISTS public.ai_marketing_versions CASCADE;

-- ai_marketing_user_prefs → references ai_brand_libraries
DROP TABLE IF EXISTS public.ai_marketing_user_prefs CASCADE;

-- ai_marketing_files → references ai_brand_libraries, ai_music_library
DROP TABLE IF EXISTS public.ai_marketing_files CASCADE;

-- ai_marketing_settings (singleton config table, no FK deps)
DROP TABLE IF EXISTS public.ai_marketing_settings CASCADE;

-- ── STEP 3: Drop AI Marketing brand/queue/music/notification tables ──

-- ai_brand_characters → used only by AIMarketingCreateImage/Vision
DROP TABLE IF EXISTS public.ai_brand_characters CASCADE;

-- ai_generation_queue → used only by AIMarketingDashboard
DROP TABLE IF EXISTS public.ai_generation_queue CASCADE;

-- ai_brand_libraries → used only by AI Marketing components
DROP TABLE IF EXISTS public.ai_brand_libraries CASCADE;

-- ai_music_library → referenced only by ai_marketing_files (now dropped)
DROP TABLE IF EXISTS public.ai_music_library CASCADE;

-- ai_notifications → AI Marketing notification tracking, no other consumers
DROP TABLE IF EXISTS public.ai_notifications CASCADE;

-- ── STEP 4: Drop AI Marketing-specific trigger function ──────
DROP FUNCTION IF EXISTS public._ai_marketing_touch_updated_at() CASCADE;

-- ── STEP 5: Remove storage bucket ───────────────────────────
-- WARNING: This removes all stored files in the bucket.
-- Ensure files are backed up before running in production.
DELETE FROM storage.objects WHERE bucket_id = 'ai-marketing-files';
DELETE FROM storage.buckets WHERE id = 'ai-marketing-files';

-- ── DONE ─────────────────────────────────────────────────────
-- Tables intentionally KEPT (shared with other features):
--   public.ai_chat_guide  → used by AIChatGuide.svelte (Settings feature)
-- ─────────────────────────────────────────────────────────────
