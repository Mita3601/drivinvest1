-- Safe migration: backup G products and related investments, then delete them
-- Backups are idempotent: they will not duplicate rows on repeated runs.

-- 1) Ensure backup tables exist (structure only)
CREATE TABLE IF NOT EXISTS public.investment_types_backup_delete_g (LIKE public.investment_types INCLUDING ALL);
CREATE TABLE IF NOT EXISTS public.investments_backup_delete_g (LIKE public.investments INCLUDING ALL);

-- 2) Insert backups (only rows that are not already backed up)
INSERT INTO public.investment_types_backup_delete_g
SELECT it.*
FROM public.investment_types it
WHERE (it.category = 'G' OR it.name LIKE 'G-%')
  AND NOT EXISTS (
    SELECT 1 FROM public.investment_types_backup_delete_g b WHERE b.id = it.id
  );

INSERT INTO public.investments_backup_delete_g
SELECT i.*
FROM public.investments i
JOIN public.investment_types it ON it.id = i.type_id
WHERE (it.category = 'G' OR it.name LIKE 'G-%')
  AND NOT EXISTS (
    SELECT 1 FROM public.investments_backup_delete_g b WHERE b.id = i.id
  );

-- 3) Transactional delete: remove investments referencing G types, then remove G types
BEGIN;

DELETE FROM public.investments
WHERE type_id IN (
  SELECT id FROM public.investment_types WHERE category = 'G' OR name LIKE 'G-%'
);

DELETE FROM public.investment_types
WHERE category = 'G' OR name LIKE 'G-%';

COMMIT;

-- Notes:
-- - This migration preserves deleted rows in *_backup_delete_g tables (including PKs).
-- - If you prefer to only mark products as "deleted" (soft-delete), modify to update a flag instead.
