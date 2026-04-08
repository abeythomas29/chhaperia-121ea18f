import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Plus, CheckCircle, Loader2, AlertTriangle } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { format } from "date-fns";

interface RecipeItem {
  raw_material_id: string;
  material_name: string;
  material_unit: string;
  quantity_per_unit: number;
  current_stock: number;
  actual_used: string; // form input string
}

export default function ProductionEntry() {
  const { user } = useAuth();
  const { toast } = useToast();

  const [productCodes, setProductCodes] = useState<{ id: string; code: string; category_id: string }[]>([]);
  const [categories, setCategories] = useState<{ id: string; name: string }[]>([]);
  const [clients, setClients] = useState<{ id: string; name: string }[]>([]);

  const [selectedCategory, setSelectedCategory] = useState("");
  const [form, setForm] = useState({
    date: format(new Date(), "yyyy-MM-dd"),
    product_code_id: "",
    client_id: "",
    rolls_count: "",
    quantity_per_roll: "",
    unit: "meters",
    thickness_mm: "",
  });

  const [newProductCode, setNewProductCode] = useState("");
  const [newProductCat, setNewProductCat] = useState("");
  const [newCategoryName, setNewCategoryName] = useState("");
  const [newClientName, setNewClientName] = useState("");
  const [productDialogOpen, setProductDialogOpen] = useState(false);
  const [clientDialogOpen, setClientDialogOpen] = useState(false);
  const [categoryDialogOpen, setCategoryDialogOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  // Raw material recipe state
  const [recipeItems, setRecipeItems] = useState<RecipeItem[]>([]);
  const [loadingRecipe, setLoadingRecipe] = useState(false);

  const fetchData = async () => {
    const [codesRes, catsRes, clientsRes] = await Promise.all([
      supabase.from("product_codes").select("id, code, category_id").eq("status", "active").order("code"),
      supabase.from("product_categories").select("id, name").eq("status", "active").order("name"),
      supabase.from("company_clients").select("id, name").eq("status", "active").order("name"),
    ]);
    setProductCodes(codesRes.data ?? []);
    setCategories(catsRes.data ?? []);
    setClients(clientsRes.data ?? []);
  };

  useEffect(() => { fetchData(); }, []);

  // Load recipe when product code changes
  useEffect(() => {
    if (!form.product_code_id) { setRecipeItems([]); return; }
    const loadRecipe = async () => {
      setLoadingRecipe(true);
      const { data: recipes } = await supabase
        .from("product_recipes")
        .select("raw_material_id, quantity_per_unit")
        .eq("product_code_id", form.product_code_id);

      if (!recipes || recipes.length === 0) {
        setRecipeItems([]);
        setLoadingRecipe(false);
        return;
      }

      const materialIds = recipes.map((r: { raw_material_id: string }) => r.raw_material_id);
      const { data: materials } = await supabase
        .from("raw_materials")
        .select("id, name, unit, current_stock")
        .in("id", materialIds);

      const materialMap = new Map((materials ?? []).map((m: { id: string; name: string; unit: string; current_stock: number }) => [m.id, m]));

      setRecipeItems(recipes.map((r: { raw_material_id: string; quantity_per_unit: number }) => {
        const mat = materialMap.get(r.raw_material_id);
        return {
          raw_material_id: r.raw_material_id,
          material_name: mat?.name ?? "Unknown",
          material_unit: mat?.unit ?? "",
          quantity_per_unit: r.quantity_per_unit,
          current_stock: mat?.current_stock ?? 0,
          actual_used: "", // will be auto-calculated
        };
      }));
      setLoadingRecipe(false);
    };
    loadRecipe();
  }, [form.product_code_id]);

  // Auto-calculate expected usage when total quantity changes
  const totalQuantity = (Number(form.rolls_count) || 0) * (Number(form.quantity_per_roll) || 0);

  useEffect(() => {
    if (recipeItems.length === 0) return;
    setRecipeItems((prev) =>
      prev.map((item) => ({
        ...item,
        actual_used: totalQuantity > 0
          ? (item.quantity_per_unit * totalQuantity).toFixed(3)
          : "",
      }))
    );
  }, [totalQuantity, form.product_code_id]);

  const filteredProductCodes = selectedCategory
    ? productCodes.filter((p) => p.category_id === selectedCategory)
    : productCodes;

  const handleCategoryChange = (catId: string) => {
    setSelectedCategory(catId);
    if (form.product_code_id) {
      const current = productCodes.find((p) => p.id === form.product_code_id);
      if (current && current.category_id !== catId) {
        setForm((f) => ({ ...f, product_code_id: "" }));
      }
    }
  };

  const updateRecipeActual = (index: number, value: string) => {
    setRecipeItems((prev) => prev.map((item, i) => i === index ? { ...item, actual_used: value } : item));
  };

  const hasStockWarning = recipeItems.some(
    (item) => Number(item.actual_used) > item.current_stock
  );

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !form.product_code_id || !form.rolls_count || !form.quantity_per_roll) return;
    setSubmitting(true);

    const insertPayload: Record<string, unknown> = {
      product_code_id: form.product_code_id,
      date: form.date,
      worker_id: user.id,
      rolls_count: Number(form.rolls_count),
      quantity_per_roll: Number(form.quantity_per_roll),
      unit: form.unit,
    };
    if (form.thickness_mm) {
      insertPayload.thickness_mm = Number(form.thickness_mm);
    }

    const { data: entry, error } = await supabase
      .from("production_entries")
      .insert(insertPayload as any)
      .select("id")
      .single();

    if (error) {
      toast({ title: "Error", description: error.message, variant: "destructive" });
      setSubmitting(false);
      return;
    }

    // Insert raw material usage rows
    const usageRows = recipeItems
      .filter((item) => Number(item.actual_used) > 0)
      .map((item) => ({
        production_entry_id: entry.id,
        raw_material_id: item.raw_material_id,
        quantity_used: Number(item.actual_used),
      }));

    if (usageRows.length > 0) {
      const { error: usageError } = await supabase.from("raw_material_usage").insert(usageRows);
      if (usageError) {
        toast({ title: "Warning", description: "Production saved but raw material usage failed: " + usageError.message, variant: "destructive" });
      }
    }

    setSubmitted(true);
    setTimeout(() => {
      setForm({ date: format(new Date(), "yyyy-MM-dd"), product_code_id: "", client_id: "", rolls_count: "", quantity_per_roll: "", unit: "meters", thickness_mm: "" });
      setSelectedCategory("");
      setRecipeItems([]);
      setSubmitted(false);
    }, 2000);
    setSubmitting(false);
  };

  const addCategory = async () => {
    if (!newCategoryName.trim()) return;
    const { data, error } = await supabase.from("product_categories").insert({ name: newCategoryName.trim() }).select().single();
    if (error) { toast({ title: "Error", description: error.message, variant: "destructive" }); return; }
    toast({ title: "Category added" });
    setCategoryDialogOpen(false);
    setNewCategoryName("");
    await fetchData();
    if (data) { setNewProductCat(data.id); setSelectedCategory(data.id); }
  };

  const addProductCode = async () => {
    if (!newProductCode.trim() || !newProductCat) return;
    const { data, error } = await supabase.from("product_codes").insert({ code: newProductCode.trim(), category_id: newProductCat }).select().single();
    if (error) { toast({ title: "Error", description: error.message, variant: "destructive" }); return; }
    toast({ title: "Product code added" });
    setProductDialogOpen(false);
    setNewProductCode("");
    setNewProductCat("");
    await fetchData();
    if (data) { setSelectedCategory(data.category_id); setForm((f) => ({ ...f, product_code_id: data.id })); }
  };

  const addClient = async () => {
    if (!newClientName.trim()) return;
    const { data, error } = await supabase.from("company_clients").insert({ name: newClientName.trim() }).select().single();
    if (error) { toast({ title: "Error", description: error.message, variant: "destructive" }); return; }
    toast({ title: "Client added" });
    setClientDialogOpen(false);
    setNewClientName("");
    await fetchData();
    if (data) setForm((f) => ({ ...f, client_id: data.id }));
  };

  if (submitted) {
    return (
      <Card className="max-w-lg mx-auto mt-8">
        <CardContent className="flex flex-col items-center py-12">
          <CheckCircle className="h-16 w-16 text-secondary mb-4" />
          <h2 className="text-xl font-bold">Entry Submitted!</h2>
          <p className="text-muted-foreground mt-1">Production entry recorded successfully.</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="max-w-lg mx-auto">
      <CardHeader>
        <CardTitle>New Production Entry</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <Label>Date</Label>
            <Input type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} />
          </div>

          <div>
            <div className="flex items-center justify-between mb-1">
              <Label>Category</Label>
              <Dialog open={categoryDialogOpen} onOpenChange={setCategoryDialogOpen}>
                <DialogTrigger asChild>
                  <Button type="button" variant="ghost" size="sm" className="h-6 text-xs text-secondary"><Plus className="h-3 w-3 mr-1" /> Add New</Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogHeader><DialogTitle>Add Product Category</DialogTitle></DialogHeader>
                  <div className="space-y-4">
                    <div><Label>Category Name</Label><Input value={newCategoryName} onChange={(e) => setNewCategoryName(e.target.value)} placeholder="e.g. Semiconductor Woven Water Blocking Tape" /></div>
                    <Button type="button" onClick={addCategory} className="w-full bg-secondary hover:bg-secondary/90">Add</Button>
                  </div>
                </DialogContent>
              </Dialog>
            </div>
            <Select value={selectedCategory} onValueChange={handleCategoryChange}>
              <SelectTrigger><SelectValue placeholder="Select a category" /></SelectTrigger>
              <SelectContent>{categories.map((c) => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}</SelectContent>
            </Select>
          </div>

          <div>
            <div className="flex items-center justify-between mb-1">
              <Label>Product Code</Label>
              <Dialog open={productDialogOpen} onOpenChange={setProductDialogOpen}>
                <DialogTrigger asChild>
                  <Button type="button" variant="ghost" size="sm" className="h-6 text-xs text-secondary"><Plus className="h-3 w-3 mr-1" /> Add New</Button>
                </DialogTrigger>
                <DialogContent>
                  <DialogHeader><DialogTitle>Add Product Code</DialogTitle></DialogHeader>
                  <div className="space-y-4">
                    <div>
                      <Label>Category</Label>
                      <Select value={newProductCat} onValueChange={setNewProductCat}>
                        <SelectTrigger><SelectValue placeholder="Select category" /></SelectTrigger>
                        <SelectContent>{categories.map((c) => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}</SelectContent>
                      </Select>
                    </div>
                    <div><Label>Code</Label><Input value={newProductCode} onChange={(e) => setNewProductCode(e.target.value)} placeholder="e.g. CHSCWWBT 18" /></div>
                    <Button type="button" onClick={addProductCode} className="w-full bg-secondary hover:bg-secondary/90">Add</Button>
                  </div>
                </DialogContent>
              </Dialog>
            </div>
            <Select value={form.product_code_id} onValueChange={(v) => setForm({ ...form, product_code_id: v })}>
              <SelectTrigger><SelectValue placeholder={selectedCategory ? "Select product code" : "Select a category first"} /></SelectTrigger>
              <SelectContent>
                {filteredProductCodes.length === 0 ? (
                  <div className="px-2 py-4 text-sm text-muted-foreground text-center">
                    {selectedCategory ? "No products in this category" : "Select a category first"}
                  </div>
                ) : (
                  filteredProductCodes.map((p) => <SelectItem key={p.id} value={p.id}>{p.code}</SelectItem>)
                )}
              </SelectContent>
            </Select>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <Label>Number of Rolls</Label>
              <Input type="number" min="0" step="0.01" value={form.rolls_count} onChange={(e) => setForm({ ...form, rolls_count: e.target.value })} placeholder="0" />
            </div>
            <div>
              <Label>Quantity per Roll</Label>
              <Input type="number" min="0" step="0.01" value={form.quantity_per_roll} onChange={(e) => setForm({ ...form, quantity_per_roll: e.target.value })} placeholder="0" />
            </div>
          </div>

          <div>
            <Label>Thickness (mm)</Label>
            <Input type="number" min="0" step="0.01" value={form.thickness_mm} onChange={(e) => setForm({ ...form, thickness_mm: e.target.value })} placeholder="e.g. 0.25" />
          </div>

          <div>
            <Label>Unit</Label>
            <Select value={form.unit} onValueChange={(v) => setForm({ ...form, unit: v })}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="meters">Meters</SelectItem>
                <SelectItem value="kg">Kilograms (kg)</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="bg-muted rounded-lg p-4 text-center">
            <p className="text-sm text-muted-foreground">Total Quantity</p>
            <p className="text-3xl font-bold text-primary">{totalQuantity.toLocaleString()} <span className="text-lg font-normal text-muted-foreground">{form.unit}</span></p>
          </div>

          {/* Raw Material Usage Section */}
          {loadingRecipe ? (
            <div className="flex items-center justify-center py-4">
              <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
              <span className="ml-2 text-sm text-muted-foreground">Loading recipe...</span>
            </div>
          ) : recipeItems.length > 0 ? (
            <Card className="border-secondary/30">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-semibold">Raw Material Usage</CardTitle>
              </CardHeader>
              <CardContent className="space-y-2">
                {recipeItems.map((item, idx) => {
                  const actual = Number(item.actual_used) || 0;
                  const overStock = actual > item.current_stock;
                  return (
                    <div key={item.raw_material_id} className="flex items-center gap-3 py-1">
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium truncate">{item.material_name}</p>
                        <p className="text-xs text-muted-foreground">
                          Stock: {item.current_stock.toLocaleString()} {item.material_unit}
                        </p>
                      </div>
                      <div className="w-28 flex items-center gap-1">
                        <Input
                          type="number"
                          min="0"
                          step="0.001"
                          className={`text-right text-sm h-8 ${overStock ? "border-destructive" : ""}`}
                          value={item.actual_used}
                          onChange={(e) => updateRecipeActual(idx, e.target.value)}
                        />
                      </div>
                      <span className="text-xs text-muted-foreground w-10">{item.material_unit}</span>
                      {overStock && <AlertTriangle className="h-4 w-4 text-destructive shrink-0" />}
                    </div>
                  );
                })}
                {hasStockWarning && (
                  <p className="text-xs text-destructive flex items-center gap-1 mt-1">
                    <AlertTriangle className="h-3 w-3" />
                    Some materials exceed available stock
                  </p>
                )}
              </CardContent>
            </Card>
          ) : form.product_code_id ? (
            <p className="text-xs text-muted-foreground text-center">No recipe defined for this product.</p>
          ) : null}

          <Button type="submit" disabled={submitting} className="w-full bg-secondary hover:bg-secondary/90 text-lg py-6">
            {submitting ? <Loader2 className="mr-2 h-5 w-5 animate-spin" /> : null}
            Submit Entry
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
