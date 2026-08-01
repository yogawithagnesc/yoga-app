-- ============================================================
-- LUMEN — Phase 26 Migration: Fatigue Trend Bug Fix + Recovery Trend (M7-6-5)
-- Run this in Supabase Dashboard → SQL Editor after schema_phase25
--
-- ROOT CAUSE of "Progress Trend shows no data in the past 30 days":
-- schema_phase13's body_fatigue_30day() compares
-- mf->>'feeling' IN ('Sore', 'Pain', 'Injured') — capitalized — but every
-- feeling value written by the app is lowercase (see FEELINGS object in
-- lumen-log-practice-3d.html: relax/feelgood/sweetpain/tight/sore/pain/
-- injured). The comparison could never match, so serious_count was always
-- 0 for every user, every day, since this function shipped. This migration
-- fixes the comparison to lowercase.
--
-- Also adds body_recovery_30day(), a parallel helper counting recovery/
-- treatment activity per day over the same 30-day window, so the Progress
-- Trend chart can plot recovery alongside practice fatigue (M7-6-5b).
--
-- Idempotent — safe to re-run.
-- ============================================================

-- ── Fix: body_fatigue_30day — lowercase feeling comparison ──
CREATE OR REPLACE FUNCTION public.body_fatigue_30day(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_result jsonb := '[]'::jsonb;
  r RECORD;
BEGIN
  FOR r IN
    SELECT
      pl.practice_date AS date,
      COALESCE(
        SUM(
          CASE WHEN lower(mf->>'feeling') IN ('sore', 'pain', 'injured')
            THEN 1 ELSE 0 END
        ),
        0
      ) AS serious_count
    FROM public.practice_logs pl
    CROSS JOIN LATERAL jsonb_array_elements(pl.muscle_feelings) AS mf
    WHERE pl.user_id = p_user_id
      AND pl.practice_date >= CURRENT_DATE - 29
    GROUP BY pl.practice_date
    ORDER BY pl.practice_date ASC
  LOOP
    v_result := v_result || jsonb_build_object(
      'date', r.date,
      'serious_count', r.serious_count
    );
  END LOOP;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.body_fatigue_30day(uuid) TO authenticated;

-- ── New: body_recovery_30day — recovery/treatment activity per day ──
-- Returns [{ date, treatment_count, areas_count }] for the last 30 days.
-- treatment_count = number of recovery_logs sessions that day;
-- areas_count = total muscle areas treated across those sessions that day
-- (a session treating 4 areas contributes more "recovery signal" than one
-- treating a single area — mirrors how body_fatigue_30day counts per-area
-- feelings, not just per-session counts).
CREATE OR REPLACE FUNCTION public.body_recovery_30day(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_result jsonb := '[]'::jsonb;
  r RECORD;
BEGIN
  FOR r IN
    SELECT
      rl.treatment_date AS date,
      COUNT(*) AS treatment_count,
      COALESCE(SUM(jsonb_array_length(rl.areas_treated)), 0) AS areas_count
    FROM public.recovery_logs rl
    WHERE rl.user_id = p_user_id
      AND rl.treatment_date >= CURRENT_DATE - 29
    GROUP BY rl.treatment_date
    ORDER BY rl.treatment_date ASC
  LOOP
    v_result := v_result || jsonb_build_object(
      'date', r.date,
      'treatment_count', r.treatment_count,
      'areas_count', r.areas_count
    );
  END LOOP;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.body_recovery_30day(uuid) TO authenticated;
