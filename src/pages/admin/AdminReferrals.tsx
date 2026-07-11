import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Skeleton } from "@/components/ui/skeleton";
import { AdminSearchBar } from "@/components/admin/AdminSearchBar";
import { useMemo, useState } from "react";

const formatCFA = (n: number) => n.toLocaleString("fr-FR");

const AdminReferrals = () => {
  const [search, setSearch] = useState("");

  const { data: profiles, isLoading } = useQuery({
    queryKey: ["admin_referral_tree"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("profiles")
        .select("id, user_id, full_name, email, referral_code, referred_by");
      if (error) throw error;
      return data || [];
    },
  });

  // Récupère tous les montants investis, regroupés par user_id
  const { data: investMap } = useQuery({
    queryKey: ["admin_investments_map"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("investments")
        .select("user_id, amount_invested");
      if (error) throw error;

      const map = new Map<string, number>();
      (data || []).forEach((inv: any) => {
        map.set(
          inv.user_id,
          (map.get(inv.user_id) || 0) + Number(inv.amount_invested || 0),
        );
      });
      return map;
    },
  });

  const nameOf = (p: any) => p.full_name || p.email?.split("@")[0] || "—";
  const depositOf = (p: any) => investMap?.get(p.user_id) || 0;

  const tree = useMemo(() => {
    if (!profiles) return [];
    const byParent = new Map<string, any[]>();
    profiles.forEach((p: any) => {
      if (p.referred_by) {
        const arr = byParent.get(p.referred_by) || [];
        arr.push(p);
        byParent.set(p.referred_by, arr);
      }
    });

    const sumDeposits = (items: any[]) =>
      items.reduce((sum: number, item: any) => sum + depositOf(item), 0);

    return profiles
      .map((parent: any) => {
        const l1 = byParent.get(parent.id) || [];
        const l2 = l1.flatMap((c) => byParent.get(c.id) || []);
        const l3 = l2.flatMap((c) => byParent.get(c.id) || []);
        const l1Deposits = sumDeposits(l1);
        const l2Deposits = sumDeposits(l2);
        const l3Deposits = sumDeposits(l3);
        return {
          parent,
          l1,
          l2,
          l3,
          total: l1.length + l2.length + l3.length,
          levelDeposits: {
            l1: l1Deposits,
            l2: l2Deposits,
            l3: l3Deposits,
            total: l1Deposits + l2Deposits + l3Deposits,
          },
        };
      })
      .filter((r) => r.total > 0)
      .sort((a, b) => b.levelDeposits.total - a.levelDeposits.total);
  }, [profiles, investMap]);

  if (isLoading)
    return (
      <div className="space-y-3">
        {Array.from({ length: 5 }).map((_, i) => (
          <Skeleton key={i} className="h-24 rounded-xl" />
        ))}
      </div>
    );

  const filtered = tree.filter((r) => {
    const q = search.toLowerCase();
    return (
      nameOf(r.parent).toLowerCase().includes(q) ||
      r.parent.email?.toLowerCase().includes(q) ||
      r.parent.referral_code?.toLowerCase().includes(q)
    );
  });

  const totalFilleuls = filtered.reduce((sum, item) => sum + item.total, 0);
  const totalDeposits = filtered.reduce(
    (sum, item) => sum + item.levelDeposits.total,
    0,
  );

  const renderLevel = (title: string, items: any[], deposits: number) => (
    <div className="rounded-3xl bg-background border border-border p-4">
      <div className="flex items-center justify-between gap-4">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-muted-foreground">
            {title}
          </p>
          <p className="text-sm font-semibold text-foreground mt-1">
            {items.length} filleuls
          </p>
        </div>
        <p className="text-xs text-muted-foreground">{formatCFA(deposits)} F</p>
      </div>
      {items.length ? (
        <div className="mt-4 space-y-2">
          {items.map((item: any) => (
            <div
              key={item.id}
              className="flex items-center justify-between gap-3 rounded-2xl bg-secondary border border-border p-3"
            >
              <div className="min-w-0">
                <p className="text-sm font-medium text-foreground truncate">
                  {nameOf(item)}
                </p>
                <p className="text-[11px] text-muted-foreground truncate">
                  {item.email || "—"}
                </p>
              </div>
              <span className="text-xs font-semibold text-foreground">
                {formatCFA(depositOf(item))} F
              </span>
            </div>
          ))}
        </div>
      ) : (
        <p className="mt-4 text-xs text-muted-foreground">
          Aucun filleul pour ce niveau.
        </p>
      )}
    </div>
  );

  return (
    <div className="space-y-4">
      <AdminSearchBar
        value={search}
        onChange={setSearch}
        placeholder="Rechercher par nom ou email..."
      />

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-muted-foreground text-xs">
          {filtered.length} / {tree.length} parrains actifs
        </p>
        <div className="flex flex-wrap gap-2">
          <span className="rounded-full bg-primary/10 px-3 py-1 text-xs font-semibold text-primary">
            {totalFilleuls} filleuls
          </span>
          <span className="rounded-full bg-success/10 px-3 py-1 text-xs font-semibold text-success">
            {formatCFA(totalDeposits)} F dépôts
          </span>
        </div>
      </div>

      <div className="space-y-4">
        {filtered.map(({ parent, l1, l2, l3, total, levelDeposits }: any) => (
          <div
            key={parent.id}
            className="rounded-3xl border border-border bg-secondary p-5 shadow-sm"
          >
            <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div className="min-w-0">
                <p className="text-base font-bold text-foreground">
                  {nameOf(parent)}
                </p>
                <p className="text-xs text-muted-foreground mt-1 truncate">
                  {parent.email || "—"}
                </p>
                <p className="text-[11px] text-muted-foreground mt-2">
                  Code parrain: {parent.referral_code}
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <span className="rounded-full bg-primary/15 px-3 py-1 text-[11px] font-semibold text-primary">
                  {total} filleuls
                </span>
                <span className="rounded-full bg-success/15 px-3 py-1 text-[11px] font-semibold text-success">
                  {formatCFA(levelDeposits.total)} F dépôts
                </span>
              </div>
            </div>

            <div className="mt-5 grid gap-3">
              {renderLevel("LEV1", l1, levelDeposits.l1)}
              {renderLevel("LEV2", l2, levelDeposits.l2)}
              {renderLevel("LEV3", l3, levelDeposits.l3)}
            </div>
          </div>
        ))}
      </div>

      {filtered.length === 0 && (
        <p className="text-center text-sm text-muted-foreground py-8">
          Aucun parrain trouvé
        </p>
      )}
    </div>
  );
};

export default AdminReferrals;
