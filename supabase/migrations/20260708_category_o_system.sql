-- Add category column to investment_types
ALTER TABLE public.investment_types
ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'P' CHECK (category IN ('O', 'P', 'Q'));

-- Add has_purchased_category_o to profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS has_purchased_category_o BOOLEAN DEFAULT FALSE;

-- Create index on category for faster queries
CREATE INDEX IF NOT EXISTS idx_investment_types_category
ON public.investment_types(category);

-- Create index on has_purchased_category_o for faster queries
CREATE INDEX IF NOT EXISTS idx_profiles_category_o_purchase
ON public.profiles(has_purchased_category_o);

-- Insert Category O products (if they don't exist)
INSERT INTO public.investment_types (name, price, daily_return, total_return, duration, category, tag)
VALUES
  ('Pack Obligatoire 1', 1000, 0, 3500, 21, 'O', 'Obligatoire'),
  ('Pack Obligatoire 2', 2500, 0, 8750, 21, 'O', 'Obligatoire'),
  ('Pack Obligatoire 3', 3000, 0, 10500, 21, 'O', 'Obligatoire'),
  ('Pack Obligatoire 4', 4000, 0, 14000, 21, 'O', 'Obligatoire'),
  ('Pack Obligatoire 5', 7000, 0, 24500, 21, 'O', 'Obligatoire')
ON CONFLICT DO NOTHING;

-- Function to check if user can purchase a product
CREATE OR REPLACE FUNCTION public.can_purchase_product(p_user_id UUID, p_type_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category TEXT;
  v_has_purchased_o BOOLEAN;
BEGIN
  -- Get the category of the product
  SELECT category INTO v_category
  FROM public.investment_types
  WHERE id = p_type_id;

  IF v_category IS NULL THEN
    RETURN json_build_object('allowed', false, 'reason', 'Produit non trouvé');
  END IF;

  -- If it's a category O product, always allowed
  IF v_category = 'O' THEN
    RETURN json_build_object('allowed', true, 'reason', 'Catégorie O accessible');
  END IF;

  -- For P or Q categories, check if user has purchased O
  SELECT has_purchased_category_o INTO v_has_purchased_o
  FROM public.profiles
  WHERE user_id = p_user_id;

  IF v_has_purchased_o = true THEN
    RETURN json_build_object('allowed', true, 'reason', 'Accès autorisé');
  ELSE
    RETURN json_build_object('allowed', false, 'reason', 'Vous devez d''abord acheter un Pack Obligatoire');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_purchase_product(UUID, UUID) TO authenticated;

-- Function to create investment and update category O flag
CREATE OR REPLACE FUNCTION public.create_investment_with_category_check(
  p_user_id UUID,
  p_type_id UUID
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_can_purchase json;
  v_investment_type RECORD;
  v_new_investment_id UUID;
  v_category TEXT;
BEGIN
  -- First check if user can purchase this product
  SELECT * INTO v_can_purchase FROM json_to_record(public.can_purchase_product(p_user_id, p_type_id)) AS x(allowed BOOLEAN, reason TEXT);

  IF (v_can_purchase).allowed = false THEN
    RETURN json_build_object('success', false, 'error', (v_can_purchase).reason);
  END IF;

  -- Get investment type details
  SELECT * INTO v_investment_type
  FROM public.investment_types
  WHERE id = p_type_id;

  IF v_investment_type.id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Produit non trouvé');
  END IF;

  -- Create the investment
  INSERT INTO public.investments (
    user_id,
    type_id,
    status,
    amount_invested,
    daily_yield,
    start_date,
    end_date,
    last_reward_date
  ) VALUES (
    p_user_id,
    p_type_id,
    'active',
    v_investment_type.price,
    v_investment_type.daily_return,
    now(),
    now() + (v_investment_type.duration || ' days')::INTERVAL,
    now()
  ) RETURNING id INTO v_new_investment_id;

  -- If it's category O, mark user as having purchased O
  IF v_investment_type.category = 'O' THEN
    UPDATE public.profiles
    SET has_purchased_category_o = true
    WHERE user_id = p_user_id
      AND has_purchased_category_o = false;
  END IF;

  RETURN json_build_object(
    'success', true,
    'investment_id', v_new_investment_id,
    'message', 'Investissement créé avec succès'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_investment_with_category_check(UUID, UUID) TO authenticated;

-- Function to update category O products with 250% return (3.5x) after completion
CREATE OR REPLACE FUNCTION public.apply_category_o_reward()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  reward_count INTEGER := 0;
  inv RECORD;
  v_reward NUMERIC;
  v_now TIMESTAMP;
BEGIN
  v_now := now();

  -- Find all completed category O investments that haven't been rewarded yet
  FOR inv IN
    SELECT i.id, i.user_id, i.amount_invested, i.end_date, it.category
    FROM public.investments i
    JOIN public.investment_types it ON i.type_id = it.id
    WHERE it.category = 'O'
      AND i.status = 'active'
      AND i.end_date <= v_now
      AND i.last_reward_date < i.end_date
  LOOP
    -- Calculate reward: amount * 3.5 = amount + (amount * 250%)
    v_reward := inv.amount_invested * 3.5;

    -- Add reward to user balance
    UPDATE public.profiles
    SET balance = balance + v_reward
    WHERE user_id = inv.user_id;

    -- Mark investment as completed
    UPDATE public.investments
    SET status = 'completed', last_reward_date = v_now
    WHERE id = inv.id;

    reward_count := reward_count + 1;
  END LOOP;

  RETURN reward_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_category_o_reward() TO service_role;

-- Update the existing buy_investment function to include category O checks
CREATE OR REPLACE FUNCTION public.buy_investment(p_type_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_price NUMERIC;
  v_daily_return NUMERIC;
  v_duration INTEGER;
  v_category TEXT;
  v_balance NUMERIC;
  v_inv_id UUID;
  v_has_purchased_o BOOLEAN;
  v_is_starter BOOLEAN;
  v_has_starter BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Non authentifié');
  END IF;

  -- Get product details
  SELECT price, daily_return, duration, COALESCE(category, 'P'), COALESCE(is_starter, false)
    INTO v_price, v_daily_return, v_duration, v_category, v_is_starter
  FROM public.investment_types WHERE id = p_type_id;

  IF v_price IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Produit introuvable');
  END IF;

  -- Check starter requirement (existing logic)
  SELECT EXISTS(
    SELECT 1 FROM public.investments i
    JOIN public.investment_types t ON t.id = i.type_id
    WHERE i.user_id = v_user_id AND t.is_starter = true
  ) INTO v_has_starter;

  IF v_is_starter THEN
    IF v_has_starter THEN
      RETURN json_build_object('success', false, 'error', 'Vous avez déjà acheté le Pass Starter.');
    END IF;
  ELSE
    IF NOT v_has_starter THEN
      RETURN json_build_object('success', false, 'error', 'Vous devez d''abord acheter le produit de 25000 F avant de pouvoir acheter un autre produit.');
    END IF;
  END IF;

  -- NEW: Check category O requirement for P and Q products
  IF v_category IN ('P', 'Q') THEN
    SELECT has_purchased_category_o INTO v_has_purchased_o
    FROM public.profiles
    WHERE user_id = v_user_id;

    IF COALESCE(v_has_purchased_o, false) = false THEN
      RETURN json_build_object('success', false, 'error', 'Vous devez d''abord acheter un Pack Obligatoire (Catégorie O) avant d''accéder à ce produit.');
    END IF;
  END IF;

  -- Check balance
  SELECT balance INTO v_balance FROM public.profiles WHERE user_id = v_user_id;
  IF v_balance < v_price THEN
    RETURN json_build_object('success', false, 'error', 'Solde insuffisant', 'required', v_price, 'balance', v_balance);
  END IF;

  -- Deduct price from balance
  UPDATE public.profiles
  SET balance = balance - v_price
  WHERE user_id = v_user_id;

  -- Create investment
  INSERT INTO public.investments (user_id, type_id, status, amount_invested, daily_yield, start_date, end_date, last_reward_date)
  VALUES (v_user_id, p_type_id, 'active', v_price, v_daily_return, now(), now() + (v_duration || ' days')::INTERVAL, now())
  RETURNING id INTO v_inv_id;

  -- NEW: If it's category O, mark user as having purchased O
  IF v_category = 'O' THEN
    UPDATE public.profiles
    SET has_purchased_category_o = true
    WHERE user_id = v_user_id
      AND has_purchased_category_o = false;
  END IF;

  RETURN json_build_object('success', true, 'investment_id', v_inv_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.buy_investment(UUID) TO authenticated;

