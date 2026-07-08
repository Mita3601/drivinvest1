-- Create function to approve deposit and credit user balance

CREATE OR REPLACE FUNCTION public.approve_deposit_transaction(p_tx_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx RECORD;
  v_user_id UUID;
  v_amount NUMERIC;
BEGIN
  -- Get the transaction
  SELECT id, user_id, amount, status, type
  INTO v_tx
  FROM public.transactions
  WHERE id = p_tx_id AND type = 'deposit';

  IF v_tx.id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Transaction non trouvée ou n''est pas un dépôt');
  END IF;

  IF v_tx.status = 'approved' THEN
    RETURN json_build_object('success', false, 'error', 'Ce dépôt a déjà été approuvé');
  END IF;

  IF v_tx.status = 'rejected' THEN
    RETURN json_build_object('success', false, 'error', 'Ce dépôt a été rejeté et ne peut pas être approuvé');
  END IF;

  v_user_id := v_tx.user_id;
  v_amount := v_tx.amount;

  -- Update transaction status
  UPDATE public.transactions
  SET status = 'approved', updated_at = now()
  WHERE id = p_tx_id;

  -- Credit user balance
  UPDATE public.profiles
  SET balance = balance + v_amount
  WHERE user_id = v_user_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Dépôt approuvé et compte crédité',
    'user_id', v_user_id,
    'amount', v_amount
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.approve_deposit_transaction(UUID) TO authenticated;

-- Function to reject deposit (refund if already credited - optional)
CREATE OR REPLACE FUNCTION public.reject_deposit_transaction(p_tx_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tx RECORD;
BEGIN
  -- Get the transaction
  SELECT id, user_id, amount, status, type
  INTO v_tx
  FROM public.transactions
  WHERE id = p_tx_id AND type = 'deposit';

  IF v_tx.id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Transaction non trouvée');
  END IF;

  IF v_tx.status = 'rejected' THEN
    RETURN json_build_object('success', false, 'error', 'Ce dépôt a déjà été rejeté');
  END IF;

  IF v_tx.status = 'approved' THEN
    RETURN json_build_object('success', false, 'error', 'Ce dépôt a déjà été approuvé - impossible de le rejeter');
  END IF;

  -- Update transaction status
  UPDATE public.transactions
  SET status = 'rejected', updated_at = now()
  WHERE id = p_tx_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Dépôt rejeté'
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.reject_deposit_transaction(UUID) TO authenticated;
