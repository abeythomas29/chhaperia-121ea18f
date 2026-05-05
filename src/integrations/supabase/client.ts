import { createClient } from "@supabase/supabase-js";
import type { Database } from "./types";

// Direct connection to original Supabase project (where all data lives)
const SUPABASE_URL = "https://zzbpgwivxvkhabphxjqt.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp6YnBnd2l2eHZraGFiaHB4anF0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwMTAzMTYsImV4cCI6MjA4NzU4NjMxNn0.cIAHZMeMdCN3tadOMwQcbH-tBXXSHaoAFwBGQ4bU7xI";

// Clear stale sessions from a previous backend (e.g. after proxy removal)
const STORAGE_KEY = `sb-${new URL(SUPABASE_URL).hostname.split('.')[0]}-auth-token`;
const storedKeys = Object.keys(localStorage).filter(k => k.startsWith('sb-') && k.endsWith('-auth-token'));
for (const key of storedKeys) {
  if (key !== STORAGE_KEY) {
    localStorage.removeItem(key);
  }
}

export const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: localStorage,
    persistSession: true,
    autoRefreshToken: true,
  },
});
