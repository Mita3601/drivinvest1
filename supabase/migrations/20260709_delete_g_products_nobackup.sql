-- Danger: this migration deletes ALL G products and related investments without backup
-- Run only if you are sure. This is irreversible via this script.

BEGIN;

-- Delete investments that reference G-type products
DELETE FROM public.investments
USING public.investment_types t
WHERE public.investments.type_id = t.id
  AND (t.category = 'G' OR t.name LIKE 'G-%');

-- Delete G-type products
DELETE FROM public.investment_types
WHERE category = 'G' OR name LIKE 'G-%';

COMMIT;
