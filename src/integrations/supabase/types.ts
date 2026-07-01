export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.4"
  }
  public: {
    Tables: {
      company_clients: {
        Row: {
          created_at: string
          id: string
          name: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      head36_entries: {
        Row: {
          created_at: string
          date: string
          gsm: number | null
          id: string
          length_per_tape_mtr: number | null
          notes: string | null
          operator_id: string
          product_code_id: string | null
          roll_width_mm: number | null
          rolls_produced: number
          rolls_taken: number
          slitting_entry_id: string | null
          stock_issue_id: string | null
          thickness_mm: number | null
          total_quantity: number | null
          unit: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          date?: string
          gsm?: number | null
          id?: string
          length_per_tape_mtr?: number | null
          notes?: string | null
          operator_id: string
          product_code_id?: string | null
          roll_width_mm?: number | null
          rolls_produced?: number
          rolls_taken?: number
          slitting_entry_id?: string | null
          stock_issue_id?: string | null
          thickness_mm?: number | null
          total_quantity?: number | null
          unit?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          date?: string
          gsm?: number | null
          id?: string
          length_per_tape_mtr?: number | null
          notes?: string | null
          operator_id?: string
          product_code_id?: string | null
          roll_width_mm?: number | null
          rolls_produced?: number
          rolls_taken?: number
          slitting_entry_id?: string | null
          stock_issue_id?: string | null
          thickness_mm?: number | null
          total_quantity?: number | null
          unit?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "head36_entries_stock_issue_id_fkey"
            columns: ["stock_issue_id"]
            isOneToOne: false
            referencedRelation: "stock_issues"
            referencedColumns: ["id"]
          },
        ]
      }
      product_categories: {
        Row: {
          created_at: string
          id: string
          name: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      product_codes: {
        Row: {
          category_id: string
          code: string
          created_at: string
          id: string
          status: string
          updated_at: string
        }
        Insert: {
          category_id: string
          code: string
          created_at?: string
          id?: string
          status?: string
          updated_at?: string
        }
        Update: {
          category_id?: string
          code?: string
          created_at?: string
          id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_codes_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "product_categories"
            referencedColumns: ["id"]
          },
        ]
      }
      product_recipes: {
        Row: {
          created_at: string
          id: string
          product_code_id: string
          quantity_per_unit: number
          raw_material_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          product_code_id: string
          quantity_per_unit?: number
          raw_material_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          product_code_id?: string
          quantity_per_unit?: number
          raw_material_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_recipes_product_code_id_fkey"
            columns: ["product_code_id"]
            isOneToOne: false
            referencedRelation: "product_codes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_recipes_raw_material_id_fkey"
            columns: ["raw_material_id"]
            isOneToOne: false
            referencedRelation: "raw_materials"
            referencedColumns: ["id"]
          },
        ]
      }
      production_entries: {
        Row: {
          client_id: string | null
          created_at: string
          date: string
          elongation: number | null
          gsm: number | null
          id: string
          lab_report_included: boolean | null
          notes: string | null
          product_code_id: string
          quantity_per_roll: number
          raw_material_included: boolean | null
          rolls_count: number
          source_gsm: number | null
          source_product_code_id: string | null
          source_quantity: number | null
          source_raw_material_id: string | null
          source_thickness_mm: number | null
          source_unit: string | null
          surface_resistance: number | null
          swelling_height: number | null
          swelling_speed: number | null
          tensile_strength: number | null
          thickness_mm: number | null
          total_quantity: number | null
          unit: string
          updated_at: string
          worker_id: string
        }
        Insert: {
          client_id?: string | null
          created_at?: string
          date?: string
          elongation?: number | null
          gsm?: number | null
          id?: string
          lab_report_included?: boolean | null
          notes?: string | null
          product_code_id: string
          quantity_per_roll: number
          raw_material_included?: boolean | null
          rolls_count: number
          source_gsm?: number | null
          source_product_code_id?: string | null
          source_quantity?: number | null
          source_raw_material_id?: string | null
          source_thickness_mm?: number | null
          source_unit?: string | null
          surface_resistance?: number | null
          swelling_height?: number | null
          swelling_speed?: number | null
          tensile_strength?: number | null
          thickness_mm?: number | null
          total_quantity?: number | null
          unit?: string
          updated_at?: string
          worker_id: string
        }
        Update: {
          client_id?: string | null
          created_at?: string
          date?: string
          elongation?: number | null
          gsm?: number | null
          id?: string
          lab_report_included?: boolean | null
          notes?: string | null
          product_code_id?: string
          quantity_per_roll?: number
          raw_material_included?: boolean | null
          rolls_count?: number
          source_gsm?: number | null
          source_product_code_id?: string | null
          source_quantity?: number | null
          source_raw_material_id?: string | null
          source_thickness_mm?: number | null
          source_unit?: string | null
          surface_resistance?: number | null
          swelling_height?: number | null
          swelling_speed?: number | null
          tensile_strength?: number | null
          thickness_mm?: number | null
          total_quantity?: number | null
          unit?: string
          updated_at?: string
          worker_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "production_entries_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "company_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "production_entries_product_code_id_fkey"
            columns: ["product_code_id"]
            isOneToOne: false
            referencedRelation: "product_codes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "production_entries_worker_id_profiles_fkey"
            columns: ["worker_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          employee_id: string
          id: string
          name: string
          requested_department: Database["public"]["Enums"]["signup_department"]
          status: string
          updated_at: string
          user_id: string
          username: string
        }
        Insert: {
          created_at?: string
          employee_id: string
          id?: string
          name: string
          requested_department?: Database["public"]["Enums"]["signup_department"]
          status?: string
          updated_at?: string
          user_id: string
          username: string
        }
        Update: {
          created_at?: string
          employee_id?: string
          id?: string
          name?: string
          requested_department?: Database["public"]["Enums"]["signup_department"]
          status?: string
          updated_at?: string
          user_id?: string
          username?: string
        }
        Relationships: []
      }
      raw_material_stock_entries: {
        Row: {
          added_by: string
          created_at: string
          date: string
          entry_kind: string
          entry_type: string
          gsm: number | null
          id: string
          issue_quantity: number | null
          issue_quantity_kg: number | null
          issue_unit: string | null
          issued_to_user_id: string | null
          lot_number: string | null
          notes: string | null
          pallets: number | null
          quantity: number
          raw_material_id: string
          supplier: string | null
          thickness_mm: number | null
        }
        Insert: {
          added_by: string
          created_at?: string
          date?: string
          entry_kind?: string
          entry_type?: string
          gsm?: number | null
          id?: string
          issue_quantity?: number | null
          issue_quantity_kg?: number | null
          issue_unit?: string | null
          issued_to_user_id?: string | null
          lot_number?: string | null
          notes?: string | null
          pallets?: number | null
          quantity?: number
          raw_material_id: string
          supplier?: string | null
          thickness_mm?: number | null
        }
        Update: {
          added_by?: string
          created_at?: string
          date?: string
          entry_kind?: string
          entry_type?: string
          gsm?: number | null
          id?: string
          issue_quantity?: number | null
          issue_quantity_kg?: number | null
          issue_unit?: string | null
          issued_to_user_id?: string | null
          lot_number?: string | null
          notes?: string | null
          pallets?: number | null
          quantity?: number
          raw_material_id?: string
          supplier?: string | null
          thickness_mm?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "raw_material_stock_entries_added_by_fkey"
            columns: ["added_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "raw_material_stock_entries_issued_to_user_fk"
            columns: ["issued_to_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "raw_material_stock_entries_raw_material_id_fkey"
            columns: ["raw_material_id"]
            isOneToOne: false
            referencedRelation: "raw_materials"
            referencedColumns: ["id"]
          },
        ]
      }
      raw_material_usage: {
        Row: {
          created_at: string
          id: string
          production_entry_id: string
          quantity_used: number
          raw_material_id: string
          stock_issue_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          production_entry_id: string
          quantity_used?: number
          raw_material_id: string
          stock_issue_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          production_entry_id?: string
          quantity_used?: number
          raw_material_id?: string
          stock_issue_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "raw_material_usage_production_entry_id_fkey"
            columns: ["production_entry_id"]
            isOneToOne: false
            referencedRelation: "production_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "raw_material_usage_raw_material_id_fkey"
            columns: ["raw_material_id"]
            isOneToOne: false
            referencedRelation: "raw_materials"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "raw_material_usage_stock_issue_id_fkey"
            columns: ["stock_issue_id"]
            isOneToOne: false
            referencedRelation: "stock_issues"
            referencedColumns: ["id"]
          },
        ]
      }
      raw_materials: {
        Row: {
          created_at: string
          current_stock: number
          id: string
          name: string
          status: string
          unit: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          current_stock?: number
          id?: string
          name: string
          status?: string
          unit?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          current_stock?: number
          id?: string
          name?: string
          status?: string
          unit?: string
          updated_at?: string
        }
        Relationships: []
      }
      sales: {
        Row: {
          client_id: string | null
          client_name: string | null
          created_at: string
          date: string
          id: string
          item_type: string
          notes: string | null
          price_per_unit: number
          product_code_id: string | null
          quantity: number
          raw_material_id: string | null
          sold_by: string
          thickness_mm: number | null
          total_amount: number | null
          unit: string
          updated_at: string
        }
        Insert: {
          client_id?: string | null
          client_name?: string | null
          created_at?: string
          date?: string
          id?: string
          item_type: string
          notes?: string | null
          price_per_unit?: number
          product_code_id?: string | null
          quantity: number
          raw_material_id?: string | null
          sold_by: string
          thickness_mm?: number | null
          total_amount?: number | null
          unit?: string
          updated_at?: string
        }
        Update: {
          client_id?: string | null
          client_name?: string | null
          created_at?: string
          date?: string
          id?: string
          item_type?: string
          notes?: string | null
          price_per_unit?: number
          product_code_id?: string | null
          quantity?: number
          raw_material_id?: string | null
          sold_by?: string
          thickness_mm?: number | null
          total_amount?: number | null
          unit?: string
          updated_at?: string
        }
        Relationships: []
      }
      slitting_entries: {
        Row: {
          client_id: string | null
          created_at: string
          cut_quantity_produced: number
          cut_width_mm: number
          date: string
          gsm: number | null
          id: string
          notes: string | null
          product_code_id: string
          remaining_returned: number
          slitting_manager_id: string
          source_gsm: number | null
          source_product_code_id: string | null
          source_quantity: number
          source_raw_material_id: string | null
          source_thickness_mm: number | null
          source_unit: string | null
          stock_issue_id: string | null
          thickness_mm: number | null
          unit: string
          updated_at: string
        }
        Insert: {
          client_id?: string | null
          created_at?: string
          cut_quantity_produced: number
          cut_width_mm: number
          date?: string
          gsm?: number | null
          id?: string
          notes?: string | null
          product_code_id: string
          remaining_returned?: number
          slitting_manager_id: string
          source_gsm?: number | null
          source_product_code_id?: string | null
          source_quantity: number
          source_raw_material_id?: string | null
          source_thickness_mm?: number | null
          source_unit?: string | null
          stock_issue_id?: string | null
          thickness_mm?: number | null
          unit?: string
          updated_at?: string
        }
        Update: {
          client_id?: string | null
          created_at?: string
          cut_quantity_produced?: number
          cut_width_mm?: number
          date?: string
          gsm?: number | null
          id?: string
          notes?: string | null
          product_code_id?: string
          remaining_returned?: number
          slitting_manager_id?: string
          source_gsm?: number | null
          source_product_code_id?: string | null
          source_quantity?: number
          source_raw_material_id?: string | null
          source_thickness_mm?: number | null
          source_unit?: string | null
          stock_issue_id?: string | null
          thickness_mm?: number | null
          unit?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "slitting_entries_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "company_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "slitting_entries_product_code_id_fkey"
            columns: ["product_code_id"]
            isOneToOne: false
            referencedRelation: "product_codes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "slitting_entries_slitting_manager_id_fkey"
            columns: ["slitting_manager_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "slitting_entries_stock_issue_id_fkey"
            columns: ["stock_issue_id"]
            isOneToOne: false
            referencedRelation: "stock_issues"
            referencedColumns: ["id"]
          },
        ]
      }
      slitting_returns: {
        Row: {
          created_at: string
          date: string
          id: string
          location: string | null
          notes: string | null
          return_type: string | null
          returned_by: string
          returned_quantity: number
          slitting_entry_id: string
          unit: string
          updated_at: string
          wastage_quantity: number | null
        }
        Insert: {
          created_at?: string
          date?: string
          id?: string
          location?: string | null
          notes?: string | null
          return_type?: string | null
          returned_by: string
          returned_quantity?: number
          slitting_entry_id: string
          unit?: string
          updated_at?: string
          wastage_quantity?: number | null
        }
        Update: {
          created_at?: string
          date?: string
          id?: string
          location?: string | null
          notes?: string | null
          return_type?: string | null
          returned_by?: string
          returned_quantity?: number
          slitting_entry_id?: string
          unit?: string
          updated_at?: string
          wastage_quantity?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "slitting_returns_slitting_entry_id_fkey"
            columns: ["slitting_entry_id"]
            isOneToOne: false
            referencedRelation: "slitting_entries"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_issues: {
        Row: {
          client_id: string | null
          created_at: string
          date: string
          gsm: number | null
          id: string
          issue_quantity: number | null
          issue_quantity_kg: number | null
          issue_quantity_sqm: number | null
          issue_type: string | null
          issue_unit: string | null
          issued_by: string
          issued_to_user_id: string | null
          lot_number: string | null
          notes: string | null
          product_code: string | null
          product_code_id: string | null
          quantity: number
          raw_material_id: string | null
          recipient_type: string | null
          recipient_user_id: string | null
          thickness_mm: number | null
          unit: string
          updated_at: string
        }
        Insert: {
          client_id?: string | null
          created_at?: string
          date?: string
          gsm?: number | null
          id?: string
          issue_quantity?: number | null
          issue_quantity_kg?: number | null
          issue_quantity_sqm?: number | null
          issue_type?: string | null
          issue_unit?: string | null
          issued_by: string
          issued_to_user_id?: string | null
          lot_number?: string | null
          notes?: string | null
          product_code?: string | null
          product_code_id?: string | null
          quantity: number
          raw_material_id?: string | null
          recipient_type?: string | null
          recipient_user_id?: string | null
          thickness_mm?: number | null
          unit?: string
          updated_at?: string
        }
        Update: {
          client_id?: string | null
          created_at?: string
          date?: string
          gsm?: number | null
          id?: string
          issue_quantity?: number | null
          issue_quantity_kg?: number | null
          issue_quantity_sqm?: number | null
          issue_type?: string | null
          issue_unit?: string | null
          issued_by?: string
          issued_to_user_id?: string | null
          lot_number?: string | null
          notes?: string | null
          product_code?: string | null
          product_code_id?: string | null
          quantity?: number
          raw_material_id?: string | null
          recipient_type?: string | null
          recipient_user_id?: string | null
          thickness_mm?: number | null
          unit?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_issues_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "company_clients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_issues_issued_by_profiles_fkey"
            columns: ["issued_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "stock_issues_issued_to_user_id_fkey"
            columns: ["issued_to_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "stock_issues_product_code_id_fkey"
            columns: ["product_code_id"]
            isOneToOne: false
            referencedRelation: "product_codes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_issues_raw_material_id_fkey"
            columns: ["raw_material_id"]
            isOneToOne: false
            referencedRelation: "raw_materials"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_issues_recipient_user_id_fkey"
            columns: ["recipient_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: string
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_list_users: {
        Args: never
        Returns: {
          employee_id: string
          id: string
          name: string
          requested_department: string
          roles: string[]
          status: string
          user_id: string
          username: string
        }[]
      }
      get_user_role: { Args: { _user_id: string }; Returns: string }
      has_role: { Args: { _role: string; _user_id: string }; Returns: boolean }
      is_admin: { Args: { _user_id: string }; Returns: boolean }
      list_36_head_source_slitting_entries: {
        Args: never
        Returns: {
          client_id: string
          client_name: string
          cut_width_mm: number
          date: string
          display_name: string
          gsm: number
          issue_type: string
          lot_no: string
          notes: string
          primary_consumed_in_slitting: number
          primary_issued_quantity: number
          primary_pending_quantity: number
          product_code_id: string
          secondary_consumed_36_head_kg: number
          secondary_consumed_36_head_sqm: number
          secondary_consumed_in_36_head: number
          secondary_pending_kg: number
          secondary_pending_quantity: number
          secondary_pending_sqm: number
          secondary_pending_unit: string
          secondary_slitting_produced_kg: number
          secondary_slitting_produced_quantity: number
          secondary_slitting_produced_sqm: number
          slitting_entry_id: string
          stock_issue_id: string
          thickness_mm: number
          unit: string
        }[]
      }
      list_manager_issued_materials: {
        Args: { include_closed?: boolean }
        Returns: {
          consumed_quantity: number
          display_name: string
          gsm: number
          issue_date: string
          issue_type: string
          issued_quantity: number
          lot_no: string
          notes: string
          pending_kg: number
          pending_quantity: number
          pending_sqm: number
          product_code: string
          product_code_id: string
          raw_material_id: string
          raw_material_name: string
          returned_quantity: number
          stock_issue_id: string
          thickness_mm: number
          unit: string
          wastage_quantity: number
        }[]
      }
      list_production_manager_recipients: {
        Args: never
        Returns: {
          name: string
          user_id: string
        }[]
      }
      list_slitting_issued_materials: {
        Args: never
        Returns: {
          consumed_quantity: number
          display_name: string
          gsm: number
          issue_type: string
          issued_quantity: number
          lot_no: string
          notes: string
          product_code: string
          product_code_id: string
          raw_material_id: string
          raw_material_name: string
          remaining_quantity: number
          stock_issue_id: string
          thickness_mm: number
          unit: string
        }[]
      }
      list_stock_issues: {
        Args: never
        Returns: {
          client_id: string
          client_name: string
          created_at: string
          date: string
          gsm: number
          id: string
          issue_type: string
          issued_by: string
          issued_by_name: string
          notes: string
          product_code: string
          product_code_id: string
          quantity: number
          raw_material_id: string
          raw_material_name: string
          recipient_name: string
          recipient_type: string
          recipient_user_id: string
          thickness_mm: number
          unit: string
        }[]
      }
    }
    Enums: {
      signup_department: "worker" | "inventory_manager" | "slitting_manager"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      signup_department: ["worker", "inventory_manager", "slitting_manager"],
    },
  },
} as const
