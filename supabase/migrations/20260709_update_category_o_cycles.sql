-- Update Category O products with cycle information
UPDATE public.investment_types
SET 
  cycle_days = 7,
  total_cycles = 3
WHERE category = 'O';

-- Verify the update
SELECT name, category, cycle_days, total_cycles, price, daily_return, total_return, duration
FROM public.investment_types
WHERE category = 'O'
ORDER BY price;
