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
    PostgrestVersion: "14.18"
  }
  private: {
    Tables: {
      academic_program: {
        Row: {
          academic_program_id: number
          created_at: string
          display_order: number
          is_active: boolean
          program_name: string
          updated_at: string
        }
        Insert: {
          academic_program_id?: never
          created_at?: string
          display_order: number
          is_active?: boolean
          program_name: string
          updated_at?: string
        }
        Update: {
          academic_program_id?: never
          created_at?: string
          display_order?: number
          is_active?: boolean
          program_name?: string
          updated_at?: string
        }
        Relationships: []
      }
      check_in_qr_token: {
        Row: {
          booking_date: string
          check_in_qr_token_id: string
          created_at: string
          expires_at: string
          revoked_at: string | null
          scan_result: string | null
          scanned_at: string | null
          scanned_by_user_id: string | null
          time_block_id: number
          token_hash: string
          user_id: string
        }
        Insert: {
          booking_date: string
          check_in_qr_token_id?: string
          created_at?: string
          expires_at: string
          revoked_at?: string | null
          scan_result?: string | null
          scanned_at?: string | null
          scanned_by_user_id?: string | null
          time_block_id: number
          token_hash: string
          user_id: string
        }
        Update: {
          booking_date?: string
          check_in_qr_token_id?: string
          created_at?: string
          expires_at?: string
          revoked_at?: string | null
          scan_result?: string | null
          scanned_at?: string | null
          scanned_by_user_id?: string | null
          time_block_id?: number
          token_hash?: string
          user_id?: string
        }
        Relationships: []
      }
      exercise_catalog: {
        Row: {
          asset_path: string
          created_at: string
          display_order: number
          equipment: string
          exercise_key: string
          exercise_name: string
          is_active: boolean
          muscle_group: string
          updated_at: string
        }
        Insert: {
          asset_path: string
          created_at?: string
          display_order: number
          equipment: string
          exercise_key: string
          exercise_name: string
          is_active?: boolean
          muscle_group: string
          updated_at?: string
        }
        Update: {
          asset_path?: string
          created_at?: string
          display_order?: number
          equipment?: string
          exercise_key?: string
          exercise_name?: string
          is_active?: boolean
          muscle_group?: string
          updated_at?: string
        }
        Relationships: []
      }
      research_campaign: {
        Row: {
          closes_at: string | null
          consent_text: string
          created_at: string
          created_by_user_id: string
          data_use_notice: string
          opens_at: string | null
          purpose: string
          research_campaign_id: string
          status: Database["private"]["Enums"]["research_campaign_status"]
          title: string
          updated_at: string
        }
        Insert: {
          closes_at?: string | null
          consent_text: string
          created_at?: string
          created_by_user_id: string
          data_use_notice: string
          opens_at?: string | null
          purpose: string
          research_campaign_id?: string
          status?: Database["private"]["Enums"]["research_campaign_status"]
          title: string
          updated_at?: string
        }
        Update: {
          closes_at?: string | null
          consent_text?: string
          created_at?: string
          created_by_user_id?: string
          data_use_notice?: string
          opens_at?: string | null
          purpose?: string
          research_campaign_id?: string
          status?: Database["private"]["Enums"]["research_campaign_status"]
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      research_campaign_question: {
        Row: {
          display_order: number
          is_required: boolean
          question_key: string
          question_snapshot: Json
          research_campaign_id: string
        }
        Insert: {
          display_order: number
          is_required?: boolean
          question_key: string
          question_snapshot: Json
          research_campaign_id: string
        }
        Update: {
          display_order?: number
          is_required?: boolean
          question_key?: string
          question_snapshot?: Json
          research_campaign_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "research_campaign_question_question_key_fkey"
            columns: ["question_key"]
            isOneToOne: false
            referencedRelation: "research_question_catalog"
            referencedColumns: ["question_key"]
          },
          {
            foreignKeyName: "research_campaign_question_research_campaign_id_fkey"
            columns: ["research_campaign_id"]
            isOneToOne: false
            referencedRelation: "research_campaign"
            referencedColumns: ["research_campaign_id"]
          },
        ]
      }
      research_campaign_response: {
        Row: {
          boolean_value: boolean | null
          created_at: string
          date_value: string | null
          decimal_value: number | null
          integer_value: number | null
          option_key: string | null
          question_key: string
          research_campaign_submission_id: string
          text_value: string | null
          updated_at: string
        }
        Insert: {
          boolean_value?: boolean | null
          created_at?: string
          date_value?: string | null
          decimal_value?: number | null
          integer_value?: number | null
          option_key?: string | null
          question_key: string
          research_campaign_submission_id: string
          text_value?: string | null
          updated_at?: string
        }
        Update: {
          boolean_value?: boolean | null
          created_at?: string
          date_value?: string | null
          decimal_value?: number | null
          integer_value?: number | null
          option_key?: string | null
          question_key?: string
          research_campaign_submission_id?: string
          text_value?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "research_campaign_response_question_key_fkey"
            columns: ["question_key"]
            isOneToOne: false
            referencedRelation: "research_question_catalog"
            referencedColumns: ["question_key"]
          },
          {
            foreignKeyName: "research_campaign_response_research_campaign_submission_id_fkey"
            columns: ["research_campaign_submission_id"]
            isOneToOne: false
            referencedRelation: "research_campaign_submission"
            referencedColumns: ["research_campaign_submission_id"]
          },
        ]
      }
      research_campaign_submission: {
        Row: {
          consented_at: string
          created_at: string
          research_campaign_id: string
          research_campaign_submission_id: string
          submitted_at: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          consented_at: string
          created_at?: string
          research_campaign_id: string
          research_campaign_submission_id?: string
          submitted_at?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          consented_at?: string
          created_at?: string
          research_campaign_id?: string
          research_campaign_submission_id?: string
          submitted_at?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "research_campaign_submission_research_campaign_id_fkey"
            columns: ["research_campaign_id"]
            isOneToOne: false
            referencedRelation: "research_campaign"
            referencedColumns: ["research_campaign_id"]
          },
        ]
      }
      research_campaign_target_role: {
        Row: {
          research_campaign_id: string
          target_role: Database["public"]["Enums"]["app_role"]
        }
        Insert: {
          research_campaign_id: string
          target_role: Database["public"]["Enums"]["app_role"]
        }
        Update: {
          research_campaign_id?: string
          target_role?: Database["public"]["Enums"]["app_role"]
        }
        Relationships: [
          {
            foreignKeyName: "research_campaign_target_role_research_campaign_id_fkey"
            columns: ["research_campaign_id"]
            isOneToOne: false
            referencedRelation: "research_campaign"
            referencedColumns: ["research_campaign_id"]
          },
        ]
      }
      research_question_catalog: {
        Row: {
          created_at: string
          display_order: number
          formula_description: string | null
          help_text: string | null
          is_campaign_selectable: boolean
          is_derived: boolean
          prompt: string
          question_key: string
          response_kind: Database["private"]["Enums"]["catalog_response_kind"]
          section_key: string
          sets_preventive_attention: boolean
          source_code: string
          source_revision: number
          updated_at: string
          validation: Json
        }
        Insert: {
          created_at?: string
          display_order?: number
          formula_description?: string | null
          help_text?: string | null
          is_campaign_selectable?: boolean
          is_derived?: boolean
          prompt: string
          question_key: string
          response_kind: Database["private"]["Enums"]["catalog_response_kind"]
          section_key: string
          sets_preventive_attention?: boolean
          source_code: string
          source_revision?: number
          updated_at?: string
          validation?: Json
        }
        Update: {
          created_at?: string
          display_order?: number
          formula_description?: string | null
          help_text?: string | null
          is_campaign_selectable?: boolean
          is_derived?: boolean
          prompt?: string
          question_key?: string
          response_kind?: Database["private"]["Enums"]["catalog_response_kind"]
          section_key?: string
          sets_preventive_attention?: boolean
          source_code?: string
          source_revision?: number
          updated_at?: string
          validation?: Json
        }
        Relationships: []
      }
      research_question_option: {
        Row: {
          display_order: number
          label: string
          option_key: string
          question_key: string
        }
        Insert: {
          display_order: number
          label: string
          option_key: string
          question_key: string
        }
        Update: {
          display_order?: number
          label?: string
          option_key?: string
          question_key?: string
        }
        Relationships: [
          {
            foreignKeyName: "research_question_option_question_key_fkey"
            columns: ["question_key"]
            isOneToOne: false
            referencedRelation: "research_question_catalog"
            referencedColumns: ["question_key"]
          },
        ]
      }
      routine_plan: {
        Row: {
          assigned_at: string | null
          created_at: string
          created_by_user_id: string
          kind: Database["private"]["Enums"]["routine_plan_kind"]
          recipient_user_id: string | null
          routine_plan_id: string
          source_template_id: string | null
          status: Database["private"]["Enums"]["routine_plan_status"]
          title: string
          updated_at: string
          updated_by_user_id: string
        }
        Insert: {
          assigned_at?: string | null
          created_at?: string
          created_by_user_id: string
          kind: Database["private"]["Enums"]["routine_plan_kind"]
          recipient_user_id?: string | null
          routine_plan_id?: string
          source_template_id?: string | null
          status?: Database["private"]["Enums"]["routine_plan_status"]
          title: string
          updated_at?: string
          updated_by_user_id: string
        }
        Update: {
          assigned_at?: string | null
          created_at?: string
          created_by_user_id?: string
          kind?: Database["private"]["Enums"]["routine_plan_kind"]
          recipient_user_id?: string | null
          routine_plan_id?: string
          source_template_id?: string | null
          status?: Database["private"]["Enums"]["routine_plan_status"]
          title?: string
          updated_at?: string
          updated_by_user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "routine_plan_source_template_id_fkey"
            columns: ["source_template_id"]
            isOneToOne: false
            referencedRelation: "routine_plan"
            referencedColumns: ["routine_plan_id"]
          },
        ]
      }
      routine_plan_exercise: {
        Row: {
          created_at: string
          display_order: number
          effective_sets: number
          exercise_key: string
          load_kg: number | null
          observations: string | null
          repetitions_max: number
          repetitions_min: number
          rest_seconds: number | null
          rir: number | null
          routine_plan_exercise_id: string
          routine_plan_id: string
          total_sets: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_order: number
          effective_sets: number
          exercise_key: string
          load_kg?: number | null
          observations?: string | null
          repetitions_max: number
          repetitions_min: number
          rest_seconds?: number | null
          rir?: number | null
          routine_plan_exercise_id?: string
          routine_plan_id: string
          total_sets: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_order?: number
          effective_sets?: number
          exercise_key?: string
          load_kg?: number | null
          observations?: string | null
          repetitions_max?: number
          repetitions_min?: number
          rest_seconds?: number | null
          rir?: number | null
          routine_plan_exercise_id?: string
          routine_plan_id?: string
          total_sets?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "routine_plan_exercise_exercise_key_fkey"
            columns: ["exercise_key"]
            isOneToOne: false
            referencedRelation: "exercise_catalog"
            referencedColumns: ["exercise_key"]
          },
          {
            foreignKeyName: "routine_plan_exercise_routine_plan_id_fkey"
            columns: ["routine_plan_id"]
            isOneToOne: false
            referencedRelation: "routine_plan"
            referencedColumns: ["routine_plan_id"]
          },
        ]
      }
      staff_block_admission_request: {
        Row: {
          booking_date: string
          expires_at: string
          requested_at: string
          staff_block_admission_request_id: string
          time_block_id: number
          user_id: string
        }
        Insert: {
          booking_date: string
          expires_at: string
          requested_at?: string
          staff_block_admission_request_id?: string
          time_block_id: number
          user_id: string
        }
        Update: {
          booking_date?: string
          expires_at?: string
          requested_at?: string
          staff_block_admission_request_id?: string
          time_block_id?: number
          user_id?: string
        }
        Relationships: []
      }
      user_institutional_identity: {
        Row: {
          created_at: string
          institutional_username: string
          last_verified_at: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          institutional_username: string
          last_verified_at?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          institutional_username?: string
          last_verified_at?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_profile_revision: {
        Row: {
          academic_program_id: number | null
          career_entry_year: number | null
          date_of_birth: string | null
          height_cm: number | null
          recorded_at: string
          recorded_by_user_id: string
          reported_sex: Database["private"]["Enums"]["reported_sex"] | null
          user_id: string
          user_profile_revision_id: string
          weight_kg: number | null
        }
        Insert: {
          academic_program_id?: number | null
          career_entry_year?: number | null
          date_of_birth?: string | null
          height_cm?: number | null
          recorded_at?: string
          recorded_by_user_id: string
          reported_sex?: Database["private"]["Enums"]["reported_sex"] | null
          user_id: string
          user_profile_revision_id?: string
          weight_kg?: number | null
        }
        Update: {
          academic_program_id?: number | null
          career_entry_year?: number | null
          date_of_birth?: string | null
          height_cm?: number | null
          recorded_at?: string
          recorded_by_user_id?: string
          reported_sex?: Database["private"]["Enums"]["reported_sex"] | null
          user_id?: string
          user_profile_revision_id?: string
          weight_kg?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "user_profile_revision_academic_program_id_fkey"
            columns: ["academic_program_id"]
            isOneToOne: false
            referencedRelation: "academic_program"
            referencedColumns: ["academic_program_id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      apply_discipline_rules: {
        Args: {
          p_occurred_at: string
          p_source_event_id: string
          p_user_id: string
          p_violation_type: Database["public"]["Enums"]["discipline_violation_type"]
        }
        Returns: undefined
      }
      assert_admin_export_range: {
        Args: { p_end_date: string; p_start_date: string }
        Returns: undefined
      }
      block_ends_at: {
        Args: { p_booking_date: string; p_time_block_id: number }
        Returns: string
      }
      block_starts_at: {
        Args: { p_booking_date: string; p_time_block_id: number }
        Returns: string
      }
      can_receive_booking_availability_topic: {
        Args: { p_topic: string }
        Returns: boolean
      }
      current_active_time_block: {
        Args: { p_checked_at: string }
        Returns: {
          block_ends_at: string
          block_starts_at: string
          booking_date: string
          time_block_id: number
        }[]
      }
      current_streak_weeks: { Args: { p_user_id: string }; Returns: number }
      escape_like_literal: { Args: { p_value: string }; Returns: string }
      finalize_confirmed_booking_after_end: {
        Args: { p_booking_id: string; p_finalization_source: string }
        Returns: boolean
      }
      finalize_ended_confirmed_bookings_for_user: {
        Args: { p_finalization_source: string; p_user_id: string }
        Returns: number
      }
      get_profile_snapshot_at: {
        Args: { p_as_of: string; p_user_id: string }
        Returns: {
          academic_program_name: string
          career_entry_year: number
          date_of_birth: string
          height_cm: number
          reported_sex: string
          weight_kg: number
        }[]
      }
      get_time_block_closure_reason: {
        Args: { p_booking_date: string; p_time_block_id: number }
        Returns: string
      }
      has_required_booking_profile: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      is_gym_maintenance_window: { Args: never; Returns: boolean }
      is_time_block_closed: {
        Args: { p_booking_date: string; p_time_block_id: number }
        Returns: boolean
      }
      lock_booking_closure_scope: { Args: never; Returns: undefined }
      lock_booking_slot: {
        Args: { p_booking_date: string; p_time_block_id: number }
        Returns: undefined
      }
      lock_user_booking_day: {
        Args: { p_booking_date: string; p_user_id: string }
        Returns: undefined
      }
      parse_strict_iso_date: { Args: { p_value: string }; Returns: string }
      replace_routine_plan_exercises: {
        Args: { p_items: Json; p_routine_plan_id: string }
        Returns: undefined
      }
      require_active_user: {
        Args: { p_user_id: string }
        Returns: Database["public"]["Tables"]["app_user"]["Row"]
        SetofOptions: {
          from: "*"
          to: "app_user"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      require_bookable_time_block: {
        Args: {
          p_booking_date: string
          p_checked_at: string
          p_time_block_id: number
          p_user_id: string
        }
        Returns: Database["public"]["Tables"]["app_user"]["Row"]
        SetofOptions: {
          from: "*"
          to: "app_user"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      require_current_admin: { Args: { p_user_id: string }; Returns: undefined }
      require_current_news_editor: {
        Args: { p_user_id: string }
        Returns: undefined
      }
      require_current_research_admin: {
        Args: { p_user_id: string }
        Returns: undefined
      }
      require_current_research_recipient: {
        Args: { p_user_id: string }
        Returns: Database["public"]["Tables"]["app_user"]["Row"]
        SetofOptions: {
          from: "*"
          to: "app_user"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      require_current_routine_editor: {
        Args: { p_user_id: string }
        Returns: undefined
      }
      require_current_staff: { Args: { p_user_id: string }; Returns: undefined }
      require_qr_eligible_user: {
        Args: { p_user_id: string }
        Returns: undefined
      }
      require_regulation_accepted_user: {
        Args: { p_user_id: string }
        Returns: Database["public"]["Tables"]["app_user"]["Row"]
        SetofOptions: {
          from: "*"
          to: "app_user"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      require_unreserved_time_block_closure: {
        Args: { p_booking_date: string; p_time_block_id: number }
        Returns: undefined
      }
      required_booking_profile_missing_fields: {
        Args: { p_user_id: string }
        Returns: string[]
      }
      revoke_unscanned_check_in_qr_tokens: {
        Args: {
          p_booking_date: string
          p_time_block_id: number
          p_user_id: string
        }
        Returns: undefined
      }
      search_user_directory: {
        Args: {
          p_allowed_roles: Database["public"]["Enums"]["app_role"][]
          p_include_disabled: boolean
          p_limit: number
          p_query: string
        }
        Returns: {
          allowed_time_block_id: number
          disabled_at: string
          disabled_reason: string
          institutional_username: string
          user_id: string
          user_name: string
          user_role: Database["public"]["Enums"]["app_role"]
        }[]
      }
      user_has_preventive_attention: {
        Args: { p_user_id: string }
        Returns: boolean
      }
    }
    Enums: {
      catalog_response_kind:
        | "boolean"
        | "integer"
        | "decimal"
        | "date"
        | "short_text"
        | "single_choice"
        | "derived"
      reported_sex: "masculino" | "femenino" | "otro" | "prefiero_no_decir"
      research_campaign_status:
        | "draft"
        | "scheduled"
        | "active"
        | "closed"
        | "cancelled"
      routine_plan_kind: "template" | "assignment"
      routine_plan_status: "draft" | "assigned" | "archived"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      app_user: {
        Row: {
          allowed_time_block_id: number | null
          created_at: string
          disabled_at: string | null
          disabled_by_user_id: string | null
          disabled_reason: string | null
          identity_hmac: string
          regulation_accepted_at: string | null
          role: Database["public"]["Enums"]["app_role"]
          theme_preference: string
          updated_at: string
          user_id: string
          user_name: string
        }
        Insert: {
          allowed_time_block_id?: number | null
          created_at?: string
          disabled_at?: string | null
          disabled_by_user_id?: string | null
          disabled_reason?: string | null
          identity_hmac: string
          regulation_accepted_at?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          theme_preference?: string
          updated_at?: string
          user_id: string
          user_name: string
        }
        Update: {
          allowed_time_block_id?: number | null
          created_at?: string
          disabled_at?: string | null
          disabled_by_user_id?: string | null
          disabled_reason?: string | null
          identity_hmac?: string
          regulation_accepted_at?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          theme_preference?: string
          updated_at?: string
          user_id?: string
          user_name?: string
        }
        Relationships: [
          {
            foreignKeyName: "app_user_allowed_time_block_id_fkey"
            columns: ["allowed_time_block_id"]
            isOneToOne: false
            referencedRelation: "time_block"
            referencedColumns: ["time_block_id"]
          },
          {
            foreignKeyName: "app_user_disabled_by_user_id_fkey"
            columns: ["disabled_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
        ]
      }
      booking: {
        Row: {
          absent_at: string | null
          admission_source: Database["public"]["Enums"]["booking_admission_source"]
          booked_at: string
          booking_date: string
          booking_id: string
          cancelled_at: string | null
          confirmed_at: string | null
          created_at: string
          is_overcapacity: boolean
          late_qr_authorized_at: string | null
          present_at: string | null
          qr_scanned_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          time_block_id: number
          updated_at: string
          user_id: string
        }
        Insert: {
          absent_at?: string | null
          admission_source?: Database["public"]["Enums"]["booking_admission_source"]
          booked_at?: string
          booking_date: string
          booking_id?: string
          cancelled_at?: string | null
          confirmed_at?: string | null
          created_at?: string
          is_overcapacity?: boolean
          late_qr_authorized_at?: string | null
          present_at?: string | null
          qr_scanned_at?: string | null
          status?: Database["public"]["Enums"]["booking_status"]
          time_block_id: number
          updated_at?: string
          user_id: string
        }
        Update: {
          absent_at?: string | null
          admission_source?: Database["public"]["Enums"]["booking_admission_source"]
          booked_at?: string
          booking_date?: string
          booking_id?: string
          cancelled_at?: string | null
          confirmed_at?: string | null
          created_at?: string
          is_overcapacity?: boolean
          late_qr_authorized_at?: string | null
          present_at?: string | null
          qr_scanned_at?: string | null
          status?: Database["public"]["Enums"]["booking_status"]
          time_block_id?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "booking_time_block_id_fkey"
            columns: ["time_block_id"]
            isOneToOne: false
            referencedRelation: "time_block"
            referencedColumns: ["time_block_id"]
          },
          {
            foreignKeyName: "booking_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
        ]
      }
      booking_event: {
        Row: {
          actor_user_id: string | null
          booking_event_id: string
          booking_id: string
          created_at: string
          event_type: Database["public"]["Enums"]["booking_event_type"]
          metadata: Json
        }
        Insert: {
          actor_user_id?: string | null
          booking_event_id?: string
          booking_id: string
          created_at?: string
          event_type: Database["public"]["Enums"]["booking_event_type"]
          metadata?: Json
        }
        Update: {
          actor_user_id?: string | null
          booking_event_id?: string
          booking_id?: string
          created_at?: string
          event_type?: Database["public"]["Enums"]["booking_event_type"]
          metadata?: Json
        }
        Relationships: [
          {
            foreignKeyName: "booking_event_actor_user_id_fkey"
            columns: ["actor_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "booking_event_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "booking"
            referencedColumns: ["booking_id"]
          },
        ]
      }
      disciplinary_action: {
        Row: {
          action_kind: Database["public"]["Enums"]["discipline_action_kind"]
          applied_at: string
          disciplinary_action_id: string
          discipline_rule_id: string
          occurrence_count: number
          source_event_id: string
          user_id: string
          violation_type: Database["public"]["Enums"]["discipline_violation_type"]
        }
        Insert: {
          action_kind: Database["public"]["Enums"]["discipline_action_kind"]
          applied_at?: string
          disciplinary_action_id?: string
          discipline_rule_id: string
          occurrence_count: number
          source_event_id: string
          user_id: string
          violation_type: Database["public"]["Enums"]["discipline_violation_type"]
        }
        Update: {
          action_kind?: Database["public"]["Enums"]["discipline_action_kind"]
          applied_at?: string
          disciplinary_action_id?: string
          discipline_rule_id?: string
          occurrence_count?: number
          source_event_id?: string
          user_id?: string
          violation_type?: Database["public"]["Enums"]["discipline_violation_type"]
        }
        Relationships: [
          {
            foreignKeyName: "disciplinary_action_discipline_rule_id_fkey"
            columns: ["discipline_rule_id"]
            isOneToOne: false
            referencedRelation: "discipline_rule"
            referencedColumns: ["discipline_rule_id"]
          },
          {
            foreignKeyName: "disciplinary_action_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
        ]
      }
      discipline_rule: {
        Row: {
          action_kind: Database["public"]["Enums"]["discipline_action_kind"]
          created_at: string
          created_by_user_id: string
          discipline_rule_id: string
          enabled: boolean
          occurrence_threshold: number
          updated_at: string
          updated_by_user_id: string
          violation_type: Database["public"]["Enums"]["discipline_violation_type"]
          window_days: number
        }
        Insert: {
          action_kind: Database["public"]["Enums"]["discipline_action_kind"]
          created_at?: string
          created_by_user_id: string
          discipline_rule_id?: string
          enabled?: boolean
          occurrence_threshold: number
          updated_at?: string
          updated_by_user_id: string
          violation_type: Database["public"]["Enums"]["discipline_violation_type"]
          window_days?: number
        }
        Update: {
          action_kind?: Database["public"]["Enums"]["discipline_action_kind"]
          created_at?: string
          created_by_user_id?: string
          discipline_rule_id?: string
          enabled?: boolean
          occurrence_threshold?: number
          updated_at?: string
          updated_by_user_id?: string
          violation_type?: Database["public"]["Enums"]["discipline_violation_type"]
          window_days?: number
        }
        Relationships: [
          {
            foreignKeyName: "discipline_rule_created_by_user_id_fkey"
            columns: ["created_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "discipline_rule_updated_by_user_id_fkey"
            columns: ["updated_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
        ]
      }
      full_day_closure_period: {
        Row: {
          closure_end_date: string
          closure_start_date: string
          created_at: string
          created_by_user_id: string
          full_day_closure_period_id: string
          reason: string
        }
        Insert: {
          closure_end_date: string
          closure_start_date: string
          created_at?: string
          created_by_user_id: string
          full_day_closure_period_id?: string
          reason: string
        }
        Update: {
          closure_end_date?: string
          closure_start_date?: string
          created_at?: string
          created_by_user_id?: string
          full_day_closure_period_id?: string
          reason?: string
        }
        Relationships: [
          {
            foreignKeyName: "full_day_closure_period_created_by_user_id_fkey"
            columns: ["created_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
        ]
      }
      news_item: {
        Row: {
          caption: string
          created_at: string
          created_by_user_id: string
          news_item_id: string
          published_at: string | null
          status: Database["public"]["Enums"]["news_item_status"]
          storage_path: string
          updated_at: string
          withdrawn_at: string | null
        }
        Insert: {
          caption: string
          created_at?: string
          created_by_user_id: string
          news_item_id?: string
          published_at?: string | null
          status?: Database["public"]["Enums"]["news_item_status"]
          storage_path: string
          updated_at?: string
          withdrawn_at?: string | null
        }
        Update: {
          caption?: string
          created_at?: string
          created_by_user_id?: string
          news_item_id?: string
          published_at?: string | null
          status?: Database["public"]["Enums"]["news_item_status"]
          storage_path?: string
          updated_at?: string
          withdrawn_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_item_created_by_user_id_fkey"
            columns: ["created_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
        ]
      }
      system_settings: {
        Row: {
          n_sessions_per_day: number
          overcapacity_max_above: number
          singleton: boolean
          standard_capacity: number
          statistics_history_start_date: string | null
          updated_at: string
          updated_by_user_id: string | null
        }
        Insert: {
          n_sessions_per_day?: number
          overcapacity_max_above?: number
          singleton?: boolean
          standard_capacity?: number
          statistics_history_start_date?: string | null
          updated_at?: string
          updated_by_user_id?: string | null
        }
        Update: {
          n_sessions_per_day?: number
          overcapacity_max_above?: number
          singleton?: boolean
          standard_capacity?: number
          statistics_history_start_date?: string | null
          updated_at?: string
          updated_by_user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "system_settings_updated_by_user_id_fkey"
            columns: ["updated_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
        ]
      }
      time_block: {
        Row: {
          display_order: number
          time_block_id: number
          time_block_t0: string
          time_block_t1: string
        }
        Insert: {
          display_order: number
          time_block_id: number
          time_block_t0: string
          time_block_t1: string
        }
        Update: {
          display_order?: number
          time_block_id?: number
          time_block_t0?: string
          time_block_t1?: string
        }
        Relationships: []
      }
      time_block_closure: {
        Row: {
          closure_date: string
          created_at: string
          created_by_user_id: string
          reason: string
          time_block_closure_id: string
          time_block_id: number
        }
        Insert: {
          closure_date: string
          created_at?: string
          created_by_user_id: string
          reason: string
          time_block_closure_id?: string
          time_block_id: number
        }
        Update: {
          closure_date?: string
          created_at?: string
          created_by_user_id?: string
          reason?: string
          time_block_closure_id?: string
          time_block_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "time_block_closure_created_by_user_id_fkey"
            columns: ["created_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "time_block_closure_time_block_id_fkey"
            columns: ["time_block_id"]
            isOneToOne: false
            referencedRelation: "time_block"
            referencedColumns: ["time_block_id"]
          },
        ]
      }
      user_warning: {
        Row: {
          booking_id: string | null
          created_at: string
          created_by_user_id: string | null
          user_id: string
          user_warning_id: string
          warning_type: Database["public"]["Enums"]["warning_type"]
        }
        Insert: {
          booking_id?: string | null
          created_at?: string
          created_by_user_id?: string | null
          user_id: string
          user_warning_id?: string
          warning_type: Database["public"]["Enums"]["warning_type"]
        }
        Update: {
          booking_id?: string | null
          created_at?: string
          created_by_user_id?: string | null
          user_id?: string
          user_warning_id?: string
          warning_type?: Database["public"]["Enums"]["warning_type"]
        }
        Relationships: [
          {
            foreignKeyName: "user_warning_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "booking"
            referencedColumns: ["booking_id"]
          },
          {
            foreignKeyName: "user_warning_created_by_user_id_fkey"
            columns: ["created_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "user_warning_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
        ]
      }
      weekly_time_block_closure: {
        Row: {
          created_at: string
          created_by_user_id: string
          iso_weekday: number
          reason: string
          time_block_id: number
          weekly_time_block_closure_id: string
        }
        Insert: {
          created_at?: string
          created_by_user_id: string
          iso_weekday: number
          reason: string
          time_block_id: number
          weekly_time_block_closure_id?: string
        }
        Update: {
          created_at?: string
          created_by_user_id?: string
          iso_weekday?: number
          reason?: string
          time_block_id?: number
          weekly_time_block_closure_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "weekly_time_block_closure_created_by_user_id_fkey"
            columns: ["created_by_user_id"]
            isOneToOne: false
            referencedRelation: "app_user"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "weekly_time_block_closure_time_block_id_fkey"
            columns: ["time_block_id"]
            isOneToOne: false
            referencedRelation: "time_block"
            referencedColumns: ["time_block_id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_regulation: { Args: never; Returns: undefined }
      admit_current_staff_block_user: {
        Args: {
          p_actor_user_id: string
          p_admission_source: Database["public"]["Enums"]["booking_admission_source"]
          p_target_user_id: string
        }
        Returns: {
          absent_at: string | null
          admission_source: Database["public"]["Enums"]["booking_admission_source"]
          booked_at: string
          booking_date: string
          booking_id: string
          cancelled_at: string | null
          confirmed_at: string | null
          created_at: string
          is_overcapacity: boolean
          late_qr_authorized_at: string | null
          present_at: string | null
          qr_scanned_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          time_block_id: number
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "booking"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      advance_research_campaign_statuses: { Args: never; Returns: undefined }
      assign_routine_template: {
        Args: {
          p_actor_user_id: string
          p_recipient_user_id: string
          p_template_routine_plan_id: string
          p_title: string
        }
        Returns: Database["private"]["Tables"]["routine_plan"]["Row"]
        SetofOptions: {
          from: "*"
          to: "routine_plan"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      cancel_booking: {
        Args: { p_booking_id: string }
        Returns: {
          absent_at: string | null
          admission_source: Database["public"]["Enums"]["booking_admission_source"]
          booked_at: string
          booking_date: string
          booking_id: string
          cancelled_at: string | null
          confirmed_at: string | null
          created_at: string
          is_overcapacity: boolean
          late_qr_authorized_at: string | null
          present_at: string | null
          qr_scanned_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          time_block_id: number
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "booking"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      confirm_booking: {
        Args: { p_booking_id: string }
        Returns: {
          absent_at: string | null
          admission_source: Database["public"]["Enums"]["booking_admission_source"]
          booked_at: string
          booking_date: string
          booking_id: string
          cancelled_at: string | null
          confirmed_at: string | null
          created_at: string
          is_overcapacity: boolean
          late_qr_authorized_at: string | null
          present_at: string | null
          qr_scanned_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          time_block_id: number
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "booking"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      consume_check_in_qr: {
        Args: { p_scanner_user_id: string; p_token_hash: string }
        Returns: {
          scanned_at: string
          state: string
        }[]
      }
      create_admin_news_item_draft: {
        Args: { p_actor_user_id: string; p_caption: string }
        Returns: {
          caption: string
          created_at: string
          created_by_user_id: string
          news_item_id: string
          published_at: string | null
          status: Database["public"]["Enums"]["news_item_status"]
          storage_path: string
          updated_at: string
          withdrawn_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "news_item"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_admin_research_campaign_draft: {
        Args: {
          p_actor_user_id: string
          p_consent_text: string
          p_data_use_notice: string
          p_purpose: string
          p_questions: Json
          p_target_roles: Json
          p_title: string
        }
        Returns: Database["private"]["Tables"]["research_campaign"]["Row"]
        SetofOptions: {
          from: "*"
          to: "research_campaign"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_booking: {
        Args: { p_booking_date: string; p_time_block_id: number }
        Returns: {
          absent_at: string | null
          admission_source: Database["public"]["Enums"]["booking_admission_source"]
          booked_at: string
          booking_date: string
          booking_id: string
          cancelled_at: string | null
          confirmed_at: string | null
          created_at: string
          is_overcapacity: boolean
          late_qr_authorized_at: string | null
          present_at: string | null
          qr_scanned_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          time_block_id: number
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "booking"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_routine_template_draft: {
        Args: { p_actor_user_id: string; p_exercises: Json; p_title: string }
        Returns: Database["private"]["Tables"]["routine_plan"]["Row"]
        SetofOptions: {
          from: "*"
          to: "routine_plan"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      delete_admin_news_item: {
        Args: { p_actor_user_id: string; p_news_item_id: string }
        Returns: string
      }
      delete_expired_staff_block_admission_requests: {
        Args: never
        Returns: number
      }
      disable_admin_user: {
        Args: {
          p_actor_user_id: string
          p_reason: string
          p_target_user_id: string
        }
        Returns: {
          allowed_time_block_id: number | null
          created_at: string
          disabled_at: string | null
          disabled_by_user_id: string | null
          disabled_reason: string | null
          identity_hmac: string
          regulation_accepted_at: string | null
          role: Database["public"]["Enums"]["app_role"]
          theme_preference: string
          updated_at: string
          user_id: string
          user_name: string
        }
        SetofOptions: {
          from: "*"
          to: "app_user"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      expire_unconfirmed_bookings: { Args: never; Returns: number }
      finalize_due_attendance: { Args: never; Returns: number }
      get_academic_programs: {
        Args: never
        Returns: {
          academic_program_id: number
          program_name: string
        }[]
      }
      get_admin_booking_export: {
        Args: {
          p_actor_user_id: string
          p_end_date: string
          p_start_date: string
        }
        Returns: {
          absent_at: string
          academic_program_name: string
          admission_source: Database["public"]["Enums"]["booking_admission_source"]
          block_ends_at: string
          block_starts_at: string
          booked_at: string
          booking_date: string
          booking_status: Database["public"]["Enums"]["booking_status"]
          cancelled_at: string
          career_entry_year: number
          confirmed_at: string
          date_of_birth: string
          height_cm: number
          is_overcapacity: boolean
          late_qr_authorized_at: string
          participant_id: string
          participant_label: string
          present_at: string
          qr_scanned_at: string
          reported_sex: string
          time_block_id: number
          user_role: Database["public"]["Enums"]["app_role"]
          warning_types: string
          weight_kg: number
        }[]
      }
      get_admin_configuration: {
        Args: { p_actor_user_id: string }
        Returns: Json
      }
      get_admin_disciplinary_action_export: {
        Args: {
          p_actor_user_id: string
          p_end_date: string
          p_start_date: string
        }
        Returns: {
          academic_program_name: string
          action_kind: Database["public"]["Enums"]["discipline_action_kind"]
          applied_at: string
          career_entry_year: number
          date_of_birth: string
          height_cm: number
          occurrence_count: number
          participant_id: string
          participant_label: string
          reported_sex: string
          user_role: Database["public"]["Enums"]["app_role"]
          violation_type: Database["public"]["Enums"]["discipline_violation_type"]
          weight_kg: number
        }[]
      }
      get_admin_discipline_rules: {
        Args: { p_actor_user_id: string }
        Returns: {
          action_kind: Database["public"]["Enums"]["discipline_action_kind"]
          created_at: string
          created_by_user_id: string
          discipline_rule_id: string
          enabled: boolean
          occurrence_threshold: number
          updated_at: string
          updated_by_user_id: string
          violation_type: Database["public"]["Enums"]["discipline_violation_type"]
          window_days: number
        }[]
        SetofOptions: {
          from: "*"
          to: "discipline_rule"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_admin_research_question_catalog: {
        Args: { p_actor_user_id: string }
        Returns: {
          help_text: string
          is_campaign_selectable: boolean
          is_derived: boolean
          options: Json
          prompt: string
          question_key: string
          response_kind: Database["private"]["Enums"]["catalog_response_kind"]
          section_key: string
          sets_preventive_attention: boolean
          source_code: string
          validation: Json
        }[]
      }
      get_admin_standalone_warning_export: {
        Args: {
          p_actor_user_id: string
          p_end_date: string
          p_start_date: string
        }
        Returns: {
          academic_program_name: string
          career_entry_year: number
          date_of_birth: string
          height_cm: number
          participant_id: string
          participant_label: string
          reported_sex: string
          user_role: Database["public"]["Enums"]["app_role"]
          warning_created_at: string
          warning_type: Database["public"]["Enums"]["warning_type"]
          weight_kg: number
        }[]
      }
      get_booking_closure_reasons: {
        Args: {
          p_actor_user_id: string
          p_end_date: string
          p_start_date: string
        }
        Returns: {
          closure_date: string
          reason: string
          time_block_id: number
        }[]
      }
      get_booking_week_availability: {
        Args: { p_week_start: string }
        Returns: {
          booking_date: string
          current_booking_id: string
          current_booking_is_overcapacity: boolean
          current_booking_status: Database["public"]["Enums"]["booking_status"]
          n_sessions_per_day: number
          standard_capacity: number
          standard_count: number
          time_block_id: number
          time_block_t0: string
          time_block_t1: string
        }[]
      }
      get_check_in_qr_status: {
        Args: { p_check_in_qr_token_id: string; p_user_id: string }
        Returns: {
          scanned_at: string
          state: string
        }[]
      }
      get_current_access_state: { Args: never; Returns: string }
      get_current_staff_block_candidates: {
        Args: { p_actor_user_id: string }
        Returns: {
          admission_source: Database["public"]["Enums"]["booking_admission_source"]
          booking_status: Database["public"]["Enums"]["booking_status"]
          is_overcapacity: boolean
          requested_at: string
          user_id: string
          user_name: string
        }[]
      }
      get_current_staff_block_context: {
        Args: { p_actor_user_id: string }
        Returns: {
          block_ends_at: string
          block_starts_at: string
          booking_date: string
          confirmed_overcapacity_count: number
          confirmed_standard_count: number
          overcapacity_max_above: number
          standard_capacity: number
          time_block_id: number
        }[]
      }
      get_own_active_research_campaigns: {
        Args: { p_user_id: string }
        Returns: {
          closes_at: string
          consent_text: string
          data_use_notice: string
          purpose: string
          questions: Json
          research_campaign_id: string
          submitted_at: string
          title: string
        }[]
      }
      get_own_routine_assignments: {
        Args: never
        Returns: {
          assigned_at: string
          created_by_name: string
          exercises: Json
          routine_plan_id: string
          title: string
        }[]
      }
      get_profile_monthly_attendance: {
        Args: {
          p_actor_user_id: string
          p_month_start: string
          p_target_user_id: string
        }
        Returns: {
          attendance_status: Database["public"]["Enums"]["booking_status"]
          booking_date: string
        }[]
      }
      get_profile_overview: {
        Args: { p_actor_user_id: string; p_target_user_id: string }
        Returns: {
          academic_program_id: number
          academic_program_name: string
          booking_profile_complete: boolean
          booking_profile_missing_fields: string[]
          career_entry_year: number
          date_of_birth: string
          height_cm: number
          institutional_username: string
          reported_sex: string
          role: Database["public"]["Enums"]["app_role"]
          streak_weeks: number
          theme_preference: string
          user_name: string
          weight_kg: number
        }[]
      }
      get_published_news_feed: {
        Args: never
        Returns: {
          caption: string
          news_item_id: string
          published_at: string
          storage_path: string
        }[]
      }
      get_routine_editor_plan: {
        Args: { p_actor_user_id: string; p_routine_plan_id: string }
        Returns: {
          assigned_at: string
          created_by_user_name: string
          exercises: Json
          kind: Database["private"]["Enums"]["routine_plan_kind"]
          recipient_institutional_username: string
          recipient_user_id: string
          recipient_user_name: string
          routine_plan_id: string
          status: Database["private"]["Enums"]["routine_plan_status"]
          title: string
          updated_at: string
          updated_by_user_name: string
        }[]
      }
      has_accepted_regulation: { Args: never; Returns: boolean }
      issue_check_in_qr: {
        Args: { p_token_hash: string; p_user_id: string }
        Returns: {
          booking_date: string
          check_in_qr_token_id: string
          expires_at: string
          state: string
          time_block_id: number
        }[]
      }
      list_routine_editor_plans: {
        Args: { p_actor_user_id: string; p_query?: string }
        Returns: {
          assigned_at: string
          created_by_user_name: string
          exercise_count: number
          kind: Database["private"]["Enums"]["routine_plan_kind"]
          recipient_institutional_username: string
          recipient_user_id: string
          recipient_user_name: string
          routine_plan_id: string
          status: Database["private"]["Enums"]["routine_plan_status"]
          title: string
          updated_at: string
          updated_by_user_name: string
        }[]
      }
      prune_cron_job_run_details: { Args: never; Returns: number }
      publish_admin_news_item: {
        Args: { p_actor_user_id: string; p_news_item_id: string }
        Returns: {
          caption: string
          created_at: string
          created_by_user_id: string
          news_item_id: string
          published_at: string | null
          status: Database["public"]["Enums"]["news_item_status"]
          storage_path: string
          updated_at: string
          withdrawn_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "news_item"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      reauthorize_current_staff_block_qr: {
        Args: { p_actor_user_id: string; p_target_user_id: string }
        Returns: {
          absent_at: string | null
          admission_source: Database["public"]["Enums"]["booking_admission_source"]
          booked_at: string
          booking_date: string
          booking_id: string
          cancelled_at: string | null
          confirmed_at: string | null
          created_at: string
          is_overcapacity: boolean
          late_qr_authorized_at: string | null
          present_at: string | null
          qr_scanned_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          time_block_id: number
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "booking"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      record_profile_data_from_payload: {
        Args: {
          p_actor_user_id: string
          p_profile_data: Json
          p_target_user_id: string
        }
        Returns: undefined
      }
      remove_admin_discipline_rule: {
        Args: { p_actor_user_id: string; p_discipline_rule_id: string }
        Returns: boolean
      }
      remove_admin_full_day_closure_period: {
        Args: { p_actor_user_id: string; p_full_day_closure_period_id: string }
        Returns: boolean
      }
      remove_admin_time_block_closure: {
        Args: { p_actor_user_id: string; p_time_block_closure_id: string }
        Returns: boolean
      }
      remove_admin_weekly_time_block_closure: {
        Args: {
          p_actor_user_id: string
          p_weekly_time_block_closure_id: string
        }
        Returns: boolean
      }
      replace_daily_booking: {
        Args: {
          p_booking_date: string
          p_source_booking_id: string
          p_time_block_id: number
        }
        Returns: {
          absent_at: string | null
          admission_source: Database["public"]["Enums"]["booking_admission_source"]
          booked_at: string
          booking_date: string
          booking_id: string
          cancelled_at: string | null
          confirmed_at: string | null
          created_at: string
          is_overcapacity: boolean
          late_qr_authorized_at: string | null
          present_at: string | null
          qr_scanned_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          time_block_id: number
          updated_at: string
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "booking"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      request_current_block_admission: {
        Args: { p_user_id: string }
        Returns: {
          booking_date: string
          expires_at: string
          time_block_id: number
        }[]
      }
      restore_admin_user: {
        Args: { p_actor_user_id: string; p_target_user_id: string }
        Returns: {
          allowed_time_block_id: number | null
          created_at: string
          disabled_at: string | null
          disabled_by_user_id: string | null
          disabled_reason: string | null
          identity_hmac: string
          regulation_accepted_at: string | null
          role: Database["public"]["Enums"]["app_role"]
          theme_preference: string
          updated_at: string
          user_id: string
          user_name: string
        }
        SetofOptions: {
          from: "*"
          to: "app_user"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      run_booking_maintenance: { Args: never; Returns: undefined }
      run_research_campaign_maintenance: { Args: never; Returns: undefined }
      save_routine_template_draft: {
        Args: {
          p_actor_user_id: string
          p_exercises: Json
          p_routine_plan_id: string
          p_title: string
        }
        Returns: Database["private"]["Tables"]["routine_plan"]["Row"]
        SetofOptions: {
          from: "*"
          to: "routine_plan"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      schedule_admin_research_campaign: {
        Args: {
          p_actor_user_id: string
          p_closes_at: string
          p_opens_at: string
          p_research_campaign_id: string
        }
        Returns: Database["private"]["Tables"]["research_campaign"]["Row"]
        SetofOptions: {
          from: "*"
          to: "research_campaign"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      search_admin_users: {
        Args: { p_actor_user_id: string; p_query: string }
        Returns: {
          allowed_time_block_id: number
          disabled_at: string
          disabled_reason: string
          institutional_username: string
          user_id: string
          user_name: string
          user_role: Database["public"]["Enums"]["app_role"]
        }[]
      }
      search_current_staff_block_users: {
        Args: { p_actor_user_id: string; p_query: string }
        Returns: {
          booking_status: Database["public"]["Enums"]["booking_status"]
          institutional_username: string
          user_id: string
          user_name: string
        }[]
      }
      search_routine_assignment_recipients: {
        Args: { p_actor_user_id: string; p_query: string }
        Returns: {
          institutional_username: string
          user_id: string
          user_name: string
          user_role: Database["public"]["Enums"]["app_role"]
        }[]
      }
      search_staff_profile_users: {
        Args: { p_actor_user_id: string; p_query: string }
        Returns: {
          institutional_username: string
          user_id: string
          user_name: string
          user_role: Database["public"]["Enums"]["app_role"]
        }[]
      }
      set_admin_research_question_campaign_availability: {
        Args: {
          p_actor_user_id: string
          p_is_campaign_selectable: boolean
          p_question_key: string
        }
        Returns: Database["private"]["Tables"]["research_question_catalog"]["Row"]
        SetofOptions: {
          from: "*"
          to: "research_question_catalog"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      submit_own_research_campaign: {
        Args: {
          p_research_campaign_id: string
          p_responses: Json
          p_user_id: string
        }
        Returns: Database["private"]["Tables"]["research_campaign_submission"]["Row"]
        SetofOptions: {
          from: "*"
          to: "research_campaign_submission"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_admin_operational_settings: {
        Args: {
          p_actor_user_id: string
          p_n_sessions_per_day: number
          p_overcapacity_max_above: number
        }
        Returns: {
          n_sessions_per_day: number
          overcapacity_max_above: number
          singleton: boolean
          standard_capacity: number
          statistics_history_start_date: string | null
          updated_at: string
          updated_by_user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "system_settings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_admin_user_access: {
        Args: {
          p_actor_user_id: string
          p_role: Database["public"]["Enums"]["app_role"]
          p_target_user_id: string
        }
        Returns: {
          allowed_time_block_id: number | null
          created_at: string
          disabled_at: string | null
          disabled_by_user_id: string | null
          disabled_reason: string | null
          identity_hmac: string
          regulation_accepted_at: string | null
          role: Database["public"]["Enums"]["app_role"]
          theme_preference: string
          updated_at: string
          user_id: string
          user_name: string
        }
        SetofOptions: {
          from: "*"
          to: "app_user"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_assigned_routine: {
        Args: {
          p_actor_user_id: string
          p_exercises: Json
          p_routine_plan_id: string
          p_title: string
        }
        Returns: Database["private"]["Tables"]["routine_plan"]["Row"]
        SetofOptions: {
          from: "*"
          to: "routine_plan"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      update_current_user_theme_preference: {
        Args: { p_actor_user_id: string; p_theme_preference: string }
        Returns: string
      }
      upsert_admin_date_time_block_closure: {
        Args: {
          p_actor_user_id: string
          p_closure_date: string
          p_reason: string
          p_time_block_id: number
        }
        Returns: {
          closure_date: string
          created_at: string
          created_by_user_id: string
          reason: string
          time_block_closure_id: string
          time_block_id: number
        }
        SetofOptions: {
          from: "*"
          to: "time_block_closure"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_admin_discipline_rule: {
        Args: {
          p_action_kind: Database["public"]["Enums"]["discipline_action_kind"]
          p_actor_user_id: string
          p_occurrence_threshold: number
          p_violation_type: Database["public"]["Enums"]["discipline_violation_type"]
          p_window_days: number
        }
        Returns: {
          action_kind: Database["public"]["Enums"]["discipline_action_kind"]
          created_at: string
          created_by_user_id: string
          discipline_rule_id: string
          enabled: boolean
          occurrence_threshold: number
          updated_at: string
          updated_by_user_id: string
          violation_type: Database["public"]["Enums"]["discipline_violation_type"]
          window_days: number
        }
        SetofOptions: {
          from: "*"
          to: "discipline_rule"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_admin_full_day_closure_period: {
        Args: {
          p_actor_user_id: string
          p_end_date: string
          p_reason: string
          p_start_date: string
        }
        Returns: {
          closure_end_date: string
          closure_start_date: string
          created_at: string
          created_by_user_id: string
          full_day_closure_period_id: string
          reason: string
        }
        SetofOptions: {
          from: "*"
          to: "full_day_closure_period"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_admin_weekly_time_block_closure: {
        Args: {
          p_actor_user_id: string
          p_iso_weekday: number
          p_reason: string
          p_time_block_id: number
        }
        Returns: {
          created_at: string
          created_by_user_id: string
          iso_weekday: number
          reason: string
          time_block_id: number
          weekly_time_block_closure_id: string
        }
        SetofOptions: {
          from: "*"
          to: "weekly_time_block_closure"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      upsert_institutional_identity: {
        Args: { p_institutional_username: string; p_user_id: string }
        Returns: undefined
      }
      withdraw_admin_news_item: {
        Args: { p_actor_user_id: string; p_news_item_id: string }
        Returns: {
          caption: string
          created_at: string
          created_by_user_id: string
          news_item_id: string
          published_at: string | null
          status: Database["public"]["Enums"]["news_item_status"]
          storage_path: string
          updated_at: string
          withdrawn_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "news_item"
          isOneToOne: true
          isSetofReturn: false
        }
      }
    }
    Enums: {
      app_role: "student" | "u_staff" | "gym_staff" | "admin"
      booking_admission_source:
        | "self_service"
        | "staff_exception"
        | "staff_overcapacity"
      booking_event_type:
        | "reserved"
        | "reactivated"
        | "cancelled"
        | "confirmed"
        | "expired_to_absent"
        | "qr_check_in"
        | "visual_check_in"
        | "visual_absence"
        | "late_qr_authorized"
        | "attendance_finalized"
      booking_status:
        | "reserved"
        | "confirmed"
        | "present"
        | "absent"
        | "cancelled"
      discipline_action_kind: "notice" | "disable"
      discipline_violation_type:
        | "absent"
        | "missed_confirmation"
        | "missed_qr"
        | "unbooked_attendance"
      news_item_status: "draft" | "published" | "withdrawn"
      warning_type: "missed_confirmation" | "missed_qr" | "unbooked_attendance"
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
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
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  private: {
    Enums: {
      catalog_response_kind: [
        "boolean",
        "integer",
        "decimal",
        "date",
        "short_text",
        "single_choice",
        "derived",
      ],
      reported_sex: ["masculino", "femenino", "otro", "prefiero_no_decir"],
      research_campaign_status: [
        "draft",
        "scheduled",
        "active",
        "closed",
        "cancelled",
      ],
      routine_plan_kind: ["template", "assignment"],
      routine_plan_status: ["draft", "assigned", "archived"],
    },
  },
  public: {
    Enums: {
      app_role: ["student", "u_staff", "gym_staff", "admin"],
      booking_admission_source: [
        "self_service",
        "staff_exception",
        "staff_overcapacity",
      ],
      booking_event_type: [
        "reserved",
        "reactivated",
        "cancelled",
        "confirmed",
        "expired_to_absent",
        "qr_check_in",
        "visual_check_in",
        "visual_absence",
        "late_qr_authorized",
        "attendance_finalized",
      ],
      booking_status: [
        "reserved",
        "confirmed",
        "present",
        "absent",
        "cancelled",
      ],
      discipline_action_kind: ["notice", "disable"],
      discipline_violation_type: [
        "absent",
        "missed_confirmation",
        "missed_qr",
        "unbooked_attendance",
      ],
      news_item_status: ["draft", "published", "withdrawn"],
      warning_type: ["missed_confirmation", "missed_qr", "unbooked_attendance"],
    },
  },
} as const
