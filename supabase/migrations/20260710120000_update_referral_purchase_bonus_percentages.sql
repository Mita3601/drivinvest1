-- Update referral purchase commission percentages to 20% / 1% / 1%
-- This replaces the previous 20% / 3% / 1% rule.

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
    v_level2_amount := ROUND(p_base_price * 0.01, 2);
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
