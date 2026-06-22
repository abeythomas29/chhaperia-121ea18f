import { supabase } from "@/integrations/supabase/client";

/**
 * Returns currently available finished-product stock for a given product_code_id.
 * available = sum(production_entries.total_quantity)
 *           + sum(slitting_entries.cut_quantity_produced)
 *           + sum(head36_entries.total_quantity)
 *           + sum(slitting_returns.returned_quantity) for reusable returns
 *           - sum(stock_issues.quantity)
 *           - sum(sales.quantity where item_type='finished_product')
 */
export async function getFinishedProductAvailable(productCodeId: string): Promise<number> {
  const [prodRes, slitRes, head36Res, issueRes, saleRes, slitEntryIdsRes] = await Promise.all([
    supabase
      .from("production_entries")
      .select("total_quantity, rolls_count, quantity_per_roll")
      .eq("product_code_id", productCodeId)
      .limit(5000),
    supabase
      .from("slitting_entries")
      .select("cut_quantity_produced, source_quantity")
      .eq("product_code_id", productCodeId)
      .limit(5000),
    (supabase as any)
      .from("head36_entries")
      .select("total_quantity, rolls_produced, length_per_tape_mtr")
      .eq("product_code_id", productCodeId)
      .limit(5000),
    supabase
      .from("stock_issues")
      .select("quantity")
      .eq("product_code_id", productCodeId)
      .limit(5000),
    supabase
      .from("sales")
      .select("quantity")
      .eq("item_type", "finished_product")
      .eq("product_code_id", productCodeId)
      .limit(5000),
    supabase
      .from("slitting_entries")
      .select("id")
      .eq("product_code_id", productCodeId)
      .limit(5000),
  ]);

  const produced = (prodRes.data ?? []).reduce((sum: number, p: any) => {
    const qty = Number(p.total_quantity ?? Number(p.rolls_count) * Number(p.quantity_per_roll));
    return sum + (Number.isFinite(qty) ? qty : 0);
  }, 0);
  const slitProduced = (slitRes.data ?? []).reduce(
    (s: number, r: any) => s + Number(r.cut_quantity_produced ?? 0),
    0,
  );
  const slitConsumed = (slitRes.data ?? []).reduce(
    (s: number, r: any) => s + Number(r.source_quantity ?? 0),
    0,
  );
  const head36 = (head36Res.data ?? []).reduce((s: number, r: any) => {
    const qty = Number(
      r.total_quantity ?? Number(r.rolls_produced) * Number(r.length_per_tape_mtr ?? 0),
    );
    return s + (Number.isFinite(qty) ? qty : 0);
  }, 0);
  const issued = (issueRes.data ?? []).reduce((s: number, i: any) => s + Number(i.quantity ?? 0), 0);
  const sold = (saleRes.data ?? []).reduce((s: number, i: any) => s + Number(i.quantity ?? 0), 0);

  // Reusable material returns flow back into available stock.
  // Wastage returns (return_type = 'wastage') must NOT be added back — when/if
  // that column is introduced on slitting_returns, the filter below will exclude them.
  const slitEntryIds = ((slitEntryIdsRes.data as any[]) ?? []).map((r) => r.id).filter(Boolean);
  let reusableReturned = 0;
  if (slitEntryIds.length > 0) {
    const retRes: any = await (supabase as any)
      .from("slitting_returns")
      .select("returned_quantity, return_type")
      .in("slitting_entry_id", slitEntryIds)
      .limit(5000);
    // If return_type column doesn't exist yet, Supabase returns rows without it (undefined);
    // treat undefined/null as reusable. Only explicit 'wastage' is excluded.
    reusableReturned = ((retRes?.data as any[]) ?? [])
      .filter((r) => (r?.return_type ?? "reusable") !== "wastage")
      .reduce((s: number, r: any) => s + Number(r?.returned_quantity ?? 0), 0);
    if (retRes?.error) {
      // Fallback: if selecting return_type fails (column missing), refetch without it.
      const retRes2: any = await (supabase as any)
        .from("slitting_returns")
        .select("returned_quantity")
        .in("slitting_entry_id", slitEntryIds)
        .limit(5000);
      reusableReturned = ((retRes2?.data as any[]) ?? []).reduce(
        (s: number, r: any) => s + Number(r?.returned_quantity ?? 0),
        0,
      );
    }
  }

  return produced + slitProduced - slitConsumed + head36 + reusableReturned - issued - sold;
}
