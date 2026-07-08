import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";

interface CanPurchaseResult {
  allowed: boolean;
  reason: string;
}

export const useCanPurchaseProduct = (productTypeId: string | null) => {
  const { user } = useAuth();

  const { data, isLoading, error } = useQuery({
    queryKey: ["can_purchase_product", user?.id, productTypeId],
    queryFn: async () => {
      if (!user?.id || !productTypeId) return null;

      const { data, error } = await supabase.rpc("can_purchase_product", {
        p_user_id: user.id,
        p_type_id: productTypeId,
      });

      if (error) throw error;
      return data as CanPurchaseResult;
    },
    enabled: !!user?.id && !!productTypeId,
  });

  return {
    canPurchase: data?.allowed ?? false,
    reason: data?.reason ?? "",
    isLoading,
    error,
  };
};

export const useHasPurchasedCategoryO = () => {
  const { user } = useAuth();

  const { data, isLoading } = useQuery({
    queryKey: ["has_purchased_category_o", user?.id],
    queryFn: async () => {
      if (!user?.id) return false;

      const { data, error } = await supabase
        .from("profiles")
        .select("has_purchased_category_o")
        .eq("user_id", user.id)
        .single();

      if (error) return false;
      return data?.has_purchased_category_o ?? false;
    },
    enabled: !!user?.id,
  });

  return { hasPurchasedO: data ?? false, isLoading };
};
