-- Verify and fix G products in public.investment_types

-- 1. Check what's in the table for G products
SELECT name, category, price, daily_return, total_return, duration, cycle_days, total_cycles
FROM public.investment_types
WHERE name LIKE 'G-%'
ORDER BY price;

-- 2. Count products by category
SELECT category, COUNT(*) as count
FROM public.investment_types
GROUP BY category
ORDER BY category;

-- 3. Ensure G products have correct category
UPDATE public.investment_types
SET category = 'G'
WHERE (name LIKE 'G-%' OR name IN ('G-1', 'G-3', 'G-6', 'G-12'))
  AND category != 'G';

-- 4. Verify the update
SELECT name, category, price, daily_return, total_return, duration, cycle_days, total_cycles
FROM public.investment_types
WHERE name LIKE 'G-%' OR category = 'G'
ORDER BY price;
