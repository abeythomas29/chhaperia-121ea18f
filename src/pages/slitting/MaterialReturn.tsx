import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { Loader2, PackageOpen } from "lucide-react";
import { UNIT_OPTIONS } from "@/lib/units";
import { format } from "date-fns";
import { queueOfflineEntry, isNetworkError } from "@/lib/offlineSync";

interface SlittingRow {
  id: string;
  date: string;
  source_quantity: number;
  cut_quantity_produced: number;
  unit: string;
  thickness_mm: number | null;
  notes: string | null;
  product_codes: { code: string } | null;
}

interface ReturnGroup {
  key: string;
  ids: string[];
  firstId: string;
  date: string;
  productCode: string;
  unit: string;
  thickness_mm: number | null;
  issued: number;
  produced: number;
  count: number;
}

function buildGroups(rows: SlittingRow[]): ReturnGroup[] {
  const sigOf = (r: SlittingRow) =>
    `${r.date}|${r.product_codes?.code ?? ""}|${r.unit}|${r.thickness_mm ?? ""}`;
  const sourceTag = (r: SlittingRow) => {
    const m = r.notes?.match(/Source:\s*([^|\n]+)/);
    return m ? m[1].trim() : null;
  };

  // Phase 1: group by Source: tag when present
  const tagged = new Map<string, SlittingRow[]>();
  const untagged: SlittingRow[] = [];
  for (const r of rows) {
    const tag = sourceTag(r);
    if (tag) {
      const k = `${sigOf(r)}|${tag}`;
      if (!tagged.has(k)) tagged.set(k, []);
      tagged.get(k)!.push(r);
    } else {
      untagged.push(r);
    }
  }

  // Phase 2: for untagged rows, attach zero-source rows to nearest same-sig row with source > 0.
  // Rows arrive newest-first; within the same date keep stable order.
  const bySig = new Map<string, SlittingRow[]>();
  for (const r of untagged) {
    const k = sigOf(r);
    if (!bySig.has(k)) bySig.set(k, []);
    bySig.get(k)!.push(r);
  }

  const result: ReturnGroup[] = [];
  const pushGroup = (key: string, items: SlittingRow[]) => {
    if (!items.length) return;
    const anchor = items.find((i) => Number(i.source_quantity) > 0) ?? items[0];
    result.push({
      key,
      ids: items.map((i) => i.id),
      firstId: anchor.id,
      date: anchor.date,
      productCode: anchor.product_codes?.code ?? "—",
      unit: anchor.unit,
      thickness_mm: anchor.thickness_mm,
      issued: items.reduce((s, i) => s + Number(i.source_quantity ?? 0), 0),
      produced: items.reduce((s, i) => s + Number(i.cut_quantity_produced ?? 0), 0),
      count: items.length,
    });
  };

  tagged.forEach((items, k) => pushGroup(k, items));

  bySig.forEach((list, k) => {
    // Build buckets: each bucket starts at a source>0 row; zero rows attach to current bucket.
    const buckets: SlittingRow[][] = [];
    for (const r of list) {
      if (Number(r.source_quantity) > 0 || buckets.length === 0) {
        buckets.push([r]);
      } else {
        buckets[buckets.length - 1].push(r);
      }
    }
    buckets.forEach((items, i) => pushGroup(`${k}#${i}`, items));
  });

  result.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));
  return result;
}

export default function MaterialReturn() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [entries, setEntries] = useState<SlittingRow[]>([]);
  const [returns, setReturns] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({ group_key: "", returned_quantity: "", unit: "meters", notes: "" });

  const load = async () => {
    if (!user) return;

    // Drop legacy cache keys
    localStorage.removeItem("cache_mr_slitting_entries");
    localStorage.removeItem("cache_mr_slitting_entries_v2");

    // Instantly load from localStorage cache
    const cachedEntries = localStorage.getItem("cache_mr_slitting_entries_v3");
    const cachedReturns = localStorage.getItem("cache_mr_returns");
    if (cachedEntries) {
      try {
        setEntries(JSON.parse(cachedEntries));
        setLoading(false);
      } catch (e) {
        console.error("Error parsing cached slitting entries", e);
      }
    }
    if (cachedReturns) {
      try {
        setReturns(JSON.parse(cachedReturns));
      } catch (e) {
        console.error("Error parsing cached returns sums", e);
      }
    }

    try {
      const { data: entryData, error: entryErr } = await supabase
        .from("slitting_entries")
        .select("id, date, source_quantity, cut_quantity_produced, unit, thickness_mm, notes, product_codes(code)")
        .order("date", { ascending: false })
        .limit(300);

      if (entryErr) {
        console.error("slitting_entries query error", entryErr);
        toast({ title: "Could not load slitting entries", description: entryErr.message, variant: "destructive" });
      } else {
        const newEntries = (entryData as unknown as SlittingRow[]) ?? [];
        setEntries(newEntries);
        localStorage.setItem("cache_mr_slitting_entries_v3", JSON.stringify(newEntries));
      }

      const { data: retData } = await supabase
        .from("slitting_returns" as any)
        .select("slitting_entry_id, returned_quantity")
        .limit(2000);
      const sums: Record<string, number> = {};
      ((retData as any[]) ?? []).forEach((r) => {
        sums[r.slitting_entry_id] = (sums[r.slitting_entry_id] ?? 0) + Number(r.returned_quantity ?? 0);
      });
      setReturns(sums);
      localStorage.setItem("cache_mr_returns", JSON.stringify(sums));
    } catch (err) {
      console.error("Error querying material return online", err);
      toast({ title: "Error loading data", description: String((err as any)?.message ?? err), variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [user]);

  const groups = buildGroups(entries);
  const selected = groups.find((g) => g.key === form.group_key);
  const alreadyReturned = selected ? selected.ids.reduce((s, id) => s + (returns[id] ?? 0), 0) : 0;
  const newReturn = parseFloat(form.returned_quantity) || 0;
  const totalReturned = alreadyReturned + newReturn;
  const issued = selected ? selected.issued : 0;
  const produced = selected ? selected.produced : 0;
  const wastage = selected ? issued - produced - totalReturned : 0;
  const matched = selected && Math.abs(wastage) < 0.01;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !selected || !newReturn) {
      toast({ title: "Missing fields", description: "Select an entry and enter returned quantity.", variant: "destructive" });
      return;
    }
    setSubmitting(true);

    const payload = {
      slitting_entry_id: selected.firstId,
      returned_quantity: newReturn,
      unit: form.unit,
      notes: form.notes || null,
      returned_by: user.id,
    };

    let error = null;
    let isQueuedOffline = false;

    if (!navigator.onLine) {
      queueOfflineEntry("slitting_returns", payload);
      isQueuedOffline = true;
    } else {
      try {
        const res = await supabase.from("slitting_returns" as any).insert(payload as any);
        error = res.error;
      } catch (err) {
        error = err;
      }

      if (error) {
        if (isNetworkError(error)) {
          queueOfflineEntry("slitting_returns", payload);
          isQueuedOffline = true;
        } else {
          toast({ title: "Error", description: error.message || String(error), variant: "destructive" });
          setSubmitting(false);
          return;
        }
      }
    }

    if (!isQueuedOffline) {
      toast({ title: "Return recorded" });
    }
    setForm({ group_key: "", returned_quantity: "", unit: "meters", notes: "" });
    setSubmitting(false);
    await load();
  };

  if (loading) return <div className="flex justify-center py-12"><Loader2 className="h-8 w-8 animate-spin text-primary" /></div>;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2"><PackageOpen className="h-5 w-5" /> Material Return Entry</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label>Select Slitting Entry *</Label>
            <Select value={form.group_key} onValueChange={(v) => setForm({ ...form, group_key: v })}>
              <SelectTrigger><SelectValue placeholder="Choose a slitting source" /></SelectTrigger>
              <SelectContent>
                {groups.map((g) => (
                  <SelectItem key={g.key} value={g.key}>
                    {format(new Date(g.date), "dd/MM/yy")} — {g.productCode} — {g.issued.toLocaleString()} {g.unit}
                    {g.thickness_mm != null ? ` — ${g.thickness_mm}mm` : ""}
                    {g.count > 1 ? ` — ${g.count} cuts merged` : ""}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {selected && (
            <div className="rounded-lg border p-3 space-y-2 text-sm">
              <div className="grid grid-cols-2 gap-2">
                <div><span className="text-muted-foreground">Issued (before production): </span><b>{issued.toLocaleString()} {selected.unit}</b></div>
                <div><span className="text-muted-foreground">Produced: </span><b>{produced.toLocaleString()}</b></div>
                <div><span className="text-muted-foreground">Already Returned: </span><b>{alreadyReturned.toLocaleString()}</b></div>
                <div><span className="text-muted-foreground">New Return: </span><b>{newReturn.toLocaleString()}</b></div>
              </div>
              <div className={`rounded-md p-2 text-center font-semibold ${matched ? "bg-green-500/10 text-green-700" : "bg-destructive/10 text-destructive"}`}>
                {matched
                  ? "✓ Matched — No wastage (Issued = Produced + Returned)"
                  : `Wastage = ${wastage.toLocaleString(undefined, { maximumFractionDigits: 2 })} ${selected.unit} (Issued − Produced − Returned)`}
              </div>
            </div>
          )}

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label>Returned Quantity *</Label>
              <Input type="number" step="any" value={form.returned_quantity}
                onChange={(e) => setForm({ ...form, returned_quantity: e.target.value })} required />
            </div>
            <div className="space-y-2">
              <Label>Unit</Label>
              <Select value={form.unit} onValueChange={(v) => setForm({ ...form, unit: v })}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {UNIT_OPTIONS.map((u) => <SelectItem key={u.value} value={u.value}>{u.label}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="space-y-2">
            <Label>Notes</Label>
            <Input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} />
          </div>

          <Button type="submit" className="w-full bg-secondary hover:bg-secondary/90 text-secondary-foreground" disabled={submitting}>
            {submitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            Save Return
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
