-- Ensure profiles with an existing Category O investment are marked as having purchased Category O

UPDATE public.profiles p
SET has_purchased_category_o = true
FROM public.investments i
JOIN public.investment_types t ON t.id = i.type_id
WHERE p.user_id = i.user_id
  AND t.category = 'O'
  AND p.has_purchased_category_o = false;

-- Verify results
SELECT p.user_id, p.has_purchased_category_o, COUNT(i.id) AS o_investments
FROM public.profiles p
LEFT JOIN public.investments i ON i.user_id = p.user_id
JOIN public.investment_types t ON t.id = i.type_id AND t.category = 'O'
GROUP BY p.user_id, p.has_purchased_category_o
HAVING COUNT(i.id) > 0;
