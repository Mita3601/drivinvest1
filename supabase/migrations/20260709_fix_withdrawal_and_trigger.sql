-- Fix withdrawal RPC and improve trigger context handling

-- 1. Update trigger to properly handle SECURITY DEFINER functions and app.internal_call context
CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Allow if: user is admin OR account is system-level OR context is marked as internal
  IF public.has_role(auth.uid(), 'admin') 
     OR auth.uid() IS NULL
     OR current_setting('app.internal_call', true) = 'true'
     OR COALESCE(current_setting('app.internal_call', true), 'false') = 'true'
  THEN
    RETURN NEW;
  END IF;
  
  -- Block sensitive field changes for non-admin users
  IF NEW.balance IS DISTINCT FROM OLD.balance
     OR NEW.is_frozen IS DISTINCT FROM OLD.is_frozen
     OR NEW.is_promoter IS DISTINCT FROM OLD.is_promoter
     OR NEW.total_deposited IS DISTINCT FROM OLD.total_deposited
     OR NEW.total_withdrawn IS DISTINCT FROM OLD.total_withdrawn
     OR NEW.referral_code IS DISTINCT FROM OLD.referral_code
     OR NEW.referred_by IS DISTINCT FROM OLD.referred_by
     OR NEW.active_product_discount_pct IS DISTINCT FROM OLD.active_product_discount_pct
     OR NEW.active_deposit_bonus_pct IS DISTINCT FROM OLD.active_deposit_bonus_pct
     OR NEW.user_id IS DISTINCT FROM OLD.user_id
  THEN
    RAISE EXCEPTION 'Modification non autorisée d''un champ sensible du profil';
  END IF;
  RETURN NEW;
END; $$;

-- 2. Recreate the trigger
DROP TRIGGER IF EXISTS trg_protect_profile_sensitive ON public.profiles;
CREATE TRIGGER trg_protect_profile_sensitive
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_profile_sensitive_fields();

-- 3. Update request_withdrawal to properly manage context and check for investments
CREATE OR REPLACE FUNCTION public.request_withdrawal(
  p_amount NUMERIC,
  p_method TEXT,
  p_wallet TEXT,
  p_country TEXT
) RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user UUID := auth.uid();
  v_balance NUMERIC;
  v_frozen BOOLEAN;
  v_min NUMERIC;
  v_fee_pct NUMERIC;
  v_fee NUMERIC;
  v_net NUMERIC;
  v_method TEXT := lower(trim(p_method));
  v_country TEXT := trim(p_country);
  v_investment_count INTEGER;
BEGIN
  IF v_user IS NULL THEN RETURN json_build_object('success', false, 'error', 'Non authentifié'); END IF;

  SELECT balance, is_frozen INTO v_balance, v_frozen FROM public.profiles WHERE user_id = v_user;
  IF v_frozen THEN RETURN json_build_object('success', false, 'error', 'Votre compte est gelé. Contactez le support.'); END IF;

  -- Check if user has at least one active investment
  SELECT COUNT(*) INTO v_investment_count FROM public.investments WHERE user_id = v_user AND status = 'active';
  IF v_investment_count = 0 THEN RETURN json_build_object('success', false, 'error', 'Vous devez posséder au moins un produit actif pour effectuer un retrait.'); END IF;

  SELECT min_withdrawal, withdrawal_fee_percent INTO v_min, v_fee_pct FROM public.app_settings LIMIT 1;
  IF v_balance < v_min THEN RETURN json_build_object('success', false, 'error', 'Solde minimum requis : ' || v_min || ' F'); END IF;
  IF p_amount < v_min THEN RETURN json_build_object('success', false, 'error', 'Retrait minimum : ' || v_min || ' F'); END IF;
  IF p_amount > v_balance THEN RETURN json_build_object('success', false, 'error', 'Solde insuffisant'); END IF;

  IF v_country = 'Cameroun' THEN
    IF NOT (v_method IN ('orange', 'mtn')) THEN RETURN json_build_object('success', false, 'error', 'Opérateur invalide pour Cameroun'); END IF;
  ELSIF v_country = 'CI' THEN
    IF NOT (v_method IN ('wave', 'moov', 'mtn', 'orange')) THEN RETURN json_build_object('success', false, 'error', 'Opérateur invalide pour CI'); END IF;
  ELSIF v_country = 'Benin' THEN
    IF NOT (v_method IN ('orange', 'mtn')) THEN RETURN json_build_object('success', false, 'error', 'Opérateur invalide pour Benin'); END IF;
  ELSE
    RETURN json_build_object('success', false, 'error', 'Pays invalide');
  END IF;

  v_fee := round(p_amount * v_fee_pct / 100);
  v_net := p_amount - v_fee;

  PERFORM set_config('app.internal_call', 'true', false);

  UPDATE public.profiles SET balance = balance - p_amount WHERE user_id = v_user;

  INSERT INTO public.transactions (user_id, amount, type, method, wallet_number, country, fee_amount, net_amount, status)
  VALUES (v_user, p_amount, 'withdrawal', v_method, p_wallet, v_country, v_fee, v_net, 'pending');

  RETURN json_build_object('success', true);
END;
$$;

-- 4. Grant execution permissions to authenticated users
REVOKE EXECUTE ON FUNCTION public.request_withdrawal(numeric, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_withdrawal(numeric, text, text, text) TO authenticated;
