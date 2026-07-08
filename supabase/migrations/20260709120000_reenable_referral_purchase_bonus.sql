-- Re-enable referral purchase bonuses for first-time P/G purchases only.
-- O products remain excluded.

CREATE TABLE IF NOT EXISTS public.referral_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  referee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  level INTEGER NOT NULL CHECK (level IN (1, 2, 3)),
  amount NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_referral_rewards_referrer ON public.referral_rewards(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_referee ON public.referral_rewards(referee_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_level ON public.referral_rewards(level);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_created ON public.referral_rewards(created_at);

ALTER TABLE public.referral_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own rewards" ON public.referral_rewards;
CREATE POLICY "Users can view their own rewards"
  ON public.referral_rewards FOR SELECT
  USING (referrer_id = (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

CREATE OR REPLACE FUNCTION public.apply_referral_purchase_bonus(p_user_id uuid, p_base_price numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_referee_profile_id uuid;
  v_referee_is_promoter boolean;
  v_level1_profile_id uuid;
  v_level1_amount numeric;
  v_level2_profile_id uuid;
  v_level2_amount numeric;
  v_level3_profile_id uuid;
  v_level3_amount numeric;
BEGIN
  IF p_user_id IS NULL OR p_base_price IS NULL OR p_base_price <= 0 THEN
    RETURN;
  END IF;

  SELECT id, is_promoter INTO v_referee_profile_id, v_referee_is_promoter
  FROM public.profiles
  WHERE user_id = p_user_id
  LIMIT 1;

  IF v_referee_profile_id IS NULL OR v_referee_is_promoter THEN
    RETURN;
  END IF;

  SELECT referred_by INTO v_level1_profile_id
  FROM public.profiles
  WHERE user_id = p_user_id
  LIMIT 1;

  IF v_level1_profile_id IS NULL THEN
    RETURN;
  END IF;

  v_level1_amount := ROUND(p_base_price * 0.20, 2);
  PERFORM set_config('app.internal_call', 'true', false);
  UPDATE public.profiles
  SET balance = balance + v_level1_amount
  WHERE id = v_level1_profile_id;

  INSERT INTO public.referral_rewards (referrer_id, referee_id, level, amount)
  VALUES (v_level1_profile_id, v_referee_profile_id, 1, v_level1_amount);

  SELECT referred_by INTO v_level2_profile_id
  FROM public.profiles
  WHERE id = v_level1_profile_id
  LIMIT 1;

  IF v_level2_profile_id IS NOT NULL THEN
    v_level2_amount := ROUND(p_base_price * 0.03, 2);
    PERFORM set_config('app.internal_call', 'true', false);
    UPDATE public.profiles
    SET balance = balance + v_level2_amount
    WHERE id = v_level2_profile_id;

    INSERT INTO public.referral_rewards (referrer_id, referee_id, level, amount)
    VALUES (v_level2_profile_id, v_referee_profile_id, 2, v_level2_amount);
  END IF;

  IF v_level2_profile_id IS NOT NULL THEN
    SELECT referred_by INTO v_level3_profile_id
    FROM public.profiles
    WHERE id = v_level2_profile_id
    LIMIT 1;

    IF v_level3_profile_id IS NOT NULL THEN
      v_level3_amount := ROUND(p_base_price * 0.01, 2);
      PERFORM set_config('app.internal_call', 'true', false);
      UPDATE public.profiles
      SET balance = balance + v_level3_amount
      WHERE id = v_level3_profile_id;

      INSERT INTO public.referral_rewards (referrer_id, referee_id, level, amount)
      VALUES (v_level3_profile_id, v_referee_profile_id, 3, v_level3_amount);
    END IF;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.apply_referral_purchase_bonus(uuid, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.buy_investment(p_type_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $function$
DECLARE
  v_user_id UUID;
  v_price NUMERIC;
  v_yield NUMERIC;
  v_cycle_days INTEGER;
  v_total_cycles INTEGER;
  v_total_days INTEGER;
  v_base_price NUMERIC;
  v_is_frozen BOOLEAN;
  v_category TEXT;
  v_balance NUMERIC;
  v_has_prior BOOLEAN;
  v_inv_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Non authentifié');
  END IF;

  SELECT price, daily_return, COALESCE(cycle_days, 1), COALESCE(total_cycles, duration),
         COALESCE(referral_base_price, price), COALESCE(is_frozen, false), COALESCE(category, 'P')
    INTO v_price, v_yield, v_cycle_days, v_total_cycles, v_base_price, v_is_frozen, v_category
  FROM public.investment_types
  WHERE id = p_type_id;

  IF v_price IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Produit introuvable');
  END IF;

  IF v_is_frozen THEN
    RETURN json_build_object('success', false, 'error', 'Produit gelé');
  END IF;

  SELECT balance INTO v_balance FROM public.profiles WHERE user_id = v_user_id;
  IF v_balance < v_price THEN
    RETURN json_build_object('success', false, 'error', 'Solde insuffisant', 'required', v_price, 'balance', v_balance);
  END IF;

  v_total_days := v_cycle_days * v_total_cycles;

  SELECT EXISTS(SELECT 1 FROM public.investments WHERE user_id = v_user_id) INTO v_has_prior;

  IF v_category != 'O' AND NOT v_has_prior THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Vous devez d''abord acheter le produit de 25000 F avant de pouvoir acheter un autre produit.'
    );
  END IF;

  PERFORM set_config('app.internal_call', 'true', false);
  UPDATE public.profiles SET balance = balance - v_price WHERE user_id = v_user_id;

  IF v_category IN ('P', 'G') THEN
    PERFORM public.apply_referral_purchase_bonus(v_user_id, v_base_price);
  END IF;

  INSERT INTO public.investments (
    user_id, type_id, amount_invested, daily_yield, start_date, last_reward_date, end_date
  )
  VALUES (
    v_user_id, p_type_id, v_price, v_yield, now(), now(), now() + (v_total_days || ' days')::interval
  )
  RETURNING id INTO v_inv_id;

  IF v_category = 'O' THEN
    UPDATE public.profiles
    SET has_purchased_category_o = true
    WHERE user_id = v_user_id
      AND has_purchased_category_o = false;
  END IF;

  RETURN json_build_object('success', true, 'investment_id', v_inv_id, 'paid', v_price);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.buy_investment(uuid) TO authenticated;
