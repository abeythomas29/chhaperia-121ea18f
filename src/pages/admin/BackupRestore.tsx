import { useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";
import { Download, Upload, Loader2, Shield, CheckCircle, AlertTriangle } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Input } from "@/components/ui/input";

export default function BackupRestore() {
  const { isSuperAdmin } = useAuth();
  const { toast } = useToast();
  const [downloading, setDownloading] = useState(false);
  const [restoring, setRestoring] = useState(false);
  const [restoreResult, setRestoreResult] = useState<Record<string, { inserted: number; errors: string[] }> | null>(null);

  const handleBackup = async () => {
    setDownloading(true);
    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;

      const projectId = import.meta.env.VITE_SUPABASE_PROJECT_ID;
      const res = await fetch(
        `https://${projectId}.supabase.co/functions/v1/backup-data`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        }
      );

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.error || "Backup failed");
      }

      const backupData = await res.json();
      const blob = new Blob([JSON.stringify(backupData, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `backup_${new Date().toISOString().split("T")[0]}.json`;
      a.click();
      URL.revokeObjectURL(url);

      toast({ title: "Backup downloaded successfully" });
    } catch (err: any) {
      toast({ title: "Backup failed", description: err.message, variant: "destructive" });
    } finally {
      setDownloading(false);
    }
  };

  const handleRestore = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setRestoring(true);
    setRestoreResult(null);

    try {
      const text = await file.text();
      const backupData = JSON.parse(text);

      if (!backupData.tables || !backupData.version) {
        throw new Error("Invalid backup file format");
      }

      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData.session?.access_token;

      const projectId = import.meta.env.VITE_SUPABASE_PROJECT_ID;
      const res = await fetch(
        `https://${projectId}.supabase.co/functions/v1/restore-data`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ tables: backupData.tables }),
        }
      );

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.error || "Restore failed");
      }

      const result = await res.json();
      setRestoreResult(result.results);
      toast({ title: "Data restored successfully" });
    } catch (err: any) {
      toast({ title: "Restore failed", description: err.message, variant: "destructive" });
    } finally {
      setRestoring(false);
      e.target.value = "";
    }
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-foreground">Backup & Restore</h1>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Backup Card */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Download className="h-5 w-5 text-primary" />
              Download Backup
            </CardTitle>
            <CardDescription>
              Export all data (clients, products, production entries, stock issues, users) as a JSON file.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button onClick={handleBackup} disabled={downloading} className="w-full">
              {downloading ? (
                <><Loader2 className="h-4 w-4 animate-spin" /> Downloading...</>
              ) : (
                <><Download className="h-4 w-4" /> Download Full Backup</>
              )}
            </Button>
          </CardContent>
        </Card>

        {/* Restore Card */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Upload className="h-5 w-5 text-primary" />
              Restore from Backup
            </CardTitle>
            <CardDescription>
              Upload a previously downloaded backup file to restore data. Existing records will be updated.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            {!isSuperAdmin ? (
              <Alert>
                <Shield className="h-4 w-4" />
                <AlertTitle>Super Admin Required</AlertTitle>
                <AlertDescription>Only super admins can restore data.</AlertDescription>
              </Alert>
            ) : (
              <>
                <label className="block">
                  <Input
                    type="file"
                    accept=".json"
                    onChange={handleRestore}
                    disabled={restoring}
                    className="cursor-pointer"
                  />
                </label>
                {restoring && (
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Loader2 className="h-4 w-4 animate-spin" /> Restoring data...
                  </div>
                )}
              </>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Restore Results */}
      {restoreResult && (
        <Card>
          <CardHeader>
            <CardTitle>Restore Results</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {Object.entries(restoreResult).map(([table, result]) => (
                <div key={table} className="flex items-center justify-between rounded-md border p-3">
                  <span className="font-medium">{table.replace(/_/g, " ")}</span>
                  <div className="flex items-center gap-2">
                    {result.errors.length > 0 ? (
                      <span className="flex items-center gap-1 text-sm text-destructive">
                        <AlertTriangle className="h-4 w-4" /> {result.errors.length} error(s)
                      </span>
                    ) : (
                      <span className="flex items-center gap-1 text-sm text-green-600">
                        <CheckCircle className="h-4 w-4" /> {result.inserted} rows
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
