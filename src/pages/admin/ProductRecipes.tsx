import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Plus, Trash2, BookOpen, Search } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

interface ProductCode {
  id: string;
  code: string;
  category_id: string;
}

interface Category {
  id: string;
  name: string;
}

interface RawMaterial {
  id: string;
  name: string;
  unit: string;
}

interface RecipeRow {
  id: string;
  product_code_id: string;
  raw_material_id: string;
  quantity_per_unit: number;
  material_name?: string;
  material_unit?: string;
}

export default function ProductRecipes() {
  const { toast } = useToast();
  const [categories, setCategories] = useState<Category[]>([]);
  const [productCodes, setProductCodes] = useState<ProductCode[]>([]);
  const [rawMaterials, setRawMaterials] = useState<RawMaterial[]>([]);
  const [selectedCategory, setSelectedCategory] = useState("");
  const [selectedProduct, setSelectedProduct] = useState("");
  const [recipes, setRecipes] = useState<RecipeRow[]>([]);
  const [search, setSearch] = useState("");

  // Add recipe form
  const [addMaterialId, setAddMaterialId] = useState("");
  const [addQty, setAddQty] = useState("");

  const fetchBase = async () => {
    const [catRes, codeRes, matRes] = await Promise.all([
      supabase.from("product_categories").select("id, name").eq("status", "active").order("name"),
      supabase.from("product_codes").select("id, code, category_id").eq("status", "active").order("code"),
      supabase.from("raw_materials").select("id, name, unit").eq("status", "active").order("name"),
    ]);
    setCategories(catRes.data ?? []);
    setProductCodes(codeRes.data ?? []);
    setRawMaterials(matRes.data ?? []);
  };

  const fetchRecipes = async (productCodeId: string) => {
    const { data } = await supabase.from("product_recipes").select("*").eq("product_code_id", productCodeId);
    const materialMap = new Map(rawMaterials.map((m) => [m.id, m]));
    setRecipes((data ?? []).map((r: RecipeRow) => ({
      ...r,
      material_name: materialMap.get(r.raw_material_id)?.name ?? "Unknown",
      material_unit: materialMap.get(r.raw_material_id)?.unit ?? "",
    })));
  };

  useEffect(() => { fetchBase(); }, []);

  useEffect(() => {
    if (selectedProduct && rawMaterials.length > 0) {
      fetchRecipes(selectedProduct);
    } else {
      setRecipes([]);
    }
  }, [selectedProduct, rawMaterials]);

  const filteredCodes = selectedCategory
    ? productCodes.filter((p) => p.category_id === selectedCategory)
    : productCodes;

  const searchedCodes = search
    ? filteredCodes.filter((p) => p.code.toLowerCase().includes(search.toLowerCase()))
    : filteredCodes;

  const handleCategoryChange = (catId: string) => {
    setSelectedCategory(catId);
    setSelectedProduct("");
  };

  const addRecipeRow = async () => {
    if (!selectedProduct || !addMaterialId || !addQty) return;
    const { error } = await supabase.from("product_recipes").insert({
      product_code_id: selectedProduct,
      raw_material_id: addMaterialId,
      quantity_per_unit: Number(addQty),
    });
    if (error) {
      if (error.code === "23505") {
        toast({ title: "Already exists", description: "This material is already in the recipe.", variant: "destructive" });
      } else {
        toast({ title: "Error", description: error.message, variant: "destructive" });
      }
      return;
    }
    toast({ title: "Added to recipe" });
    setAddMaterialId("");
    setAddQty("");
    fetchRecipes(selectedProduct);
  };

  const updateQty = async (recipeId: string, newQty: number) => {
    const { error } = await supabase.from("product_recipes").update({ quantity_per_unit: newQty }).eq("id", recipeId);
    if (error) { toast({ title: "Error", description: error.message, variant: "destructive" }); return; }
    fetchRecipes(selectedProduct);
  };

  const removeRecipeRow = async (recipeId: string) => {
    const { error } = await supabase.from("product_recipes").delete().eq("id", recipeId);
    if (error) { toast({ title: "Error", description: error.message, variant: "destructive" }); return; }
    toast({ title: "Removed" });
    fetchRecipes(selectedProduct);
  };

  // Materials not yet in the recipe
  const availableMaterials = rawMaterials.filter(
    (m) => !recipes.some((r) => r.raw_material_id === m.id)
  );

  const selectedProductCode = productCodes.find((p) => p.id === selectedProduct);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Product Recipes (Bill of Materials)</h1>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div>
          <Label>Category</Label>
          <Select value={selectedCategory} onValueChange={handleCategoryChange}>
            <SelectTrigger><SelectValue placeholder="All categories" /></SelectTrigger>
            <SelectContent>
              {categories.map((c) => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}
            </SelectContent>
          </Select>
        </div>
        <div className="md:col-span-2">
          <Label>Product Code</Label>
          <Select value={selectedProduct} onValueChange={setSelectedProduct}>
            <SelectTrigger><SelectValue placeholder="Select a product code" /></SelectTrigger>
            <SelectContent>
              {searchedCodes.map((p) => <SelectItem key={p.id} value={p.id}>{p.code}</SelectItem>)}
            </SelectContent>
          </Select>
        </div>
      </div>

      {selectedProduct && selectedProductCode ? (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <BookOpen className="h-5 w-5" />
              Recipe for: {selectedProductCode.code}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Raw Material</TableHead>
                  <TableHead>Unit</TableHead>
                  <TableHead className="text-right">Qty per Unit Produced</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {recipes.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={4} className="text-center text-muted-foreground py-8">
                      No recipe defined yet. Add raw materials below.
                    </TableCell>
                  </TableRow>
                ) : recipes.map((r) => (
                  <TableRow key={r.id}>
                    <TableCell className="font-medium">{r.material_name}</TableCell>
                    <TableCell>{r.material_unit}</TableCell>
                    <TableCell className="text-right">
                      <Input
                        type="number"
                        min="0"
                        step="0.001"
                        className="w-28 ml-auto text-right"
                        defaultValue={r.quantity_per_unit}
                        onBlur={(e) => {
                          const val = Number(e.target.value);
                          if (val !== r.quantity_per_unit) updateQty(r.id, val);
                        }}
                      />
                    </TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="icon" onClick={() => removeRecipeRow(r.id)}>
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>

            {availableMaterials.length > 0 && (
              <div className="flex gap-2 items-end border-t pt-4">
                <div className="flex-1">
                  <Label>Add Raw Material</Label>
                  <Select value={addMaterialId} onValueChange={setAddMaterialId}>
                    <SelectTrigger><SelectValue placeholder="Select material" /></SelectTrigger>
                    <SelectContent>
                      {availableMaterials.map((m) => <SelectItem key={m.id} value={m.id}>{m.name} ({m.unit})</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
                <div className="w-32">
                  <Label>Qty/Unit</Label>
                  <Input type="number" min="0" step="0.001" value={addQty} onChange={(e) => setAddQty(e.target.value)} placeholder="0" />
                </div>
                <Button onClick={addRecipeRow} className="bg-secondary hover:bg-secondary/90">
                  <Plus className="h-4 w-4 mr-1" />Add
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="py-12 text-center text-muted-foreground">
            Select a product code above to view or define its recipe.
          </CardContent>
        </Card>
      )}
    </div>
  );
}
