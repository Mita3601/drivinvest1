-- Migration: Ensure G products exist with correct category in public.investment_types

BEGIN;

-- 1. First, ensure all G products have category = 'G' (fix any that are NULL or wrong)
UPDATE public.investment_types
SET category = 'G'
WHERE (name LIKE 'G-%' OR name IN ('G-1', 'G-3', 'G-6', 'G-12'))
  AND (category IS NULL OR category != 'G');

-- 2. Insert missing G products (if they don't exist)
INSERT INTO public.investment_types (name, price, daily_return, total_return, duration, cycle_days, total_cycles, category, is_starter, tag, referral_base_price)
SELECT 'G-1', 16000, 4000, 28000, 49, 7, 7, 'G', false, NULL, 16000
WHERE NOT EXISTS (SELECT 1 FROM public.investment_types WHERE name = 'G-1');

INSERT INTO public.investment_types (name, price, daily_return, total_return, duration, cycle_days, total_cycles, category, is_starter, tag, referral_base_price)
SELECT 'G-3', 32000, 8500, 59500, 49, 7, 7, 'G', false, NULL, 32000
WHERE NOT EXISTS (SELECT 1 FROM public.investment_types WHERE name = 'G-3');

INSERT INTO public.investment_types (name, price, daily_return, total_return, duration, cycle_days, total_cycles, category, is_starter, tag, referral_base_price)
SELECT 'G-6', 62000, 17000, 136000, 56, 7, 8, 'G', false, NULL, 62000
WHERE NOT EXISTS (SELECT 1 FROM public.investment_types WHERE name = 'G-6');

INSERT INTO public.investment_types (name, price, daily_return, total_return, duration, cycle_days, total_cycles, category, is_starter, tag, referral_base_price)
SELECT 'G-12', 125000, 36500, 292000, 56, 7, 8, 'G', false, NULL, 125000
WHERE NOT EXISTS (SELECT 1 FROM public.investment_types WHERE name = 'G-12');

COMMIT;
