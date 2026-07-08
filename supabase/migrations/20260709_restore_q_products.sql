-- Re-add missing category Q products after category O migration
INSERT INTO public.investment_types (
  name, price, daily_return, total_return, duration,
  cycle_days, total_cycles, category, is_starter, tag, referral_base_price
)
SELECT * FROM (VALUES
  ('Q-1', 16000, 4000, 28000, 49, 7, 7, 'Q', false, NULL, 16000),
  ('Q-3', 32000, 8500, 59500, 49, 7, 7, 'Q', false, NULL, 32000),
  ('Q-6', 62000, 17000, 136000, 56, 7, 8, 'Q', false, NULL, 62000),
  ('Q-12',125000,36500,292000,56,7,8,'Q',false,NULL,125000)
) AS vals(name, price, daily_return, total_return, duration, cycle_days, total_cycles, category, is_starter, tag, referral_base_price)
WHERE NOT EXISTS (
  SELECT 1 FROM public.investment_types WHERE name = vals.name
);
