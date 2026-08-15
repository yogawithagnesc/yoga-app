-- ============================================================
-- LUMEN — Phase 30 Migration: Enforce Role Column (NOT NULL)
-- Run this in Supabase Dashboard → SQL Editor after schema_phase29
--
-- RATIONALE: The `role` column on `profiles` should never be NULL.
-- Users must select a role (student/teacher/studio) during signup.
-- This migration (1) assigns any lingering NULL roles to 'student'
-- as a safe default, and (2) adds a NOT NULL constraint to prevent
-- future NULL values.
--
-- Idempotent — safe to re-run.
-- ============================================================

-- Fix any existing NULL roles (assign to 'student' as safe default)
UPDATE public.profiles
SET role = 'student'
WHERE role IS NULL;

-- Add NOT NULL constraint to role column
ALTER TABLE public.profiles
ALTER COLUMN role SET NOT NULL;

-- Optional: Add a default for the constraint (in case of edge cases)
-- ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'student';
