-- Backup and ensure G products match desired values
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'investment_types_backup_20260709'
  ) THEN
    EXECUTE 'CREATE TABLE public.investment_types_backup_20260709 AS TABLE public.investment_types';
  END IF;
END$$;

BEGIN;

-- Update existing G entries if present (match given specs)
UPDATE public.investment_types
SET price = 16000,
    daily_return = 4000,
    total_return = 28000,
    duration = 49,
    cycle_days = 7,
    total_cycles = 7,
    category = 'G',
    is_starter = false,
    tag = NULL,
    referral_base_price = 16000
WHERE name = 'G-1';

UPDATE public.investment_types
SET price = 32000,
    daily_return = 8500,
    total_return = 59500,
    duration = 49,
    cycle_days = 7,
    total_cycles = 7,
    category = 'G',
    is_starter = false,
    tag = NULL,
    referral_base_price = 32000
WHERE name = 'G-3';

UPDATE public.investment_types
SET price = 62000,
    daily_return = 17000,
    total_return = 136000,
    duration = 56,
    cycle_days = 7,
    total_cycles = 8,
    category = 'G',
    is_starter = false,
    tag = NULL,
    referral_base_price = 62000
WHERE name = 'G-6';

UPDATE public.investment_types
SET price = 125000,
    daily_return = 36500,
    total_return = 292000,
    duration = 56,
    cycle_days = 7,
    total_cycles = 8,
    category = 'G',
    is_starter = false,
    tag = NULL,
    referral_base_price = 125000
WHERE name = 'G-12';

-- Insert any missing G products
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

-- Granting execute not required for this migration file
