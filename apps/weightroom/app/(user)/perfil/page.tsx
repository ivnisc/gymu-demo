"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { BookOpenCheck, CheckCircle2, Dumbbell, Loader2, Pencil, X } from "lucide-react";
import * as z from "zod/v4";
import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { CREATE_SUPABASE_BROWSER_CLIENT } from "@gusm/database/client";
import { ProfileCalendar, type ProfileAttendanceEntry } from "@/components/ProfileCalendar";
import { StreakMilestoneProgress } from "@/components/StreakMilestoneProgress";
import { type AppRole, UserTopBar } from "@/components/UserTopBar";
import { getSantiagoToday } from "@/components/UserCalendarBanner";
import { clearQueryCache } from "@/lib/query-client";
import { CURRENT_USER_QUERY_KEY, PROFILE_QUERY_KEY, profileMonthQueryKey } from "@/lib/query-keys";
import type { CurrentUser } from "@/lib/current-user";
import {
  applyThemePreference,
  getDocumentThemePreference,
  type ThemePreference,
} from "@/lib/theme";

const PROFILE_SCHEMA = z.object({
  userName: z.string().min(1),
  role: z.enum(["student", "u_staff", "gym_staff", "admin"]),
  institutionalUsername: z.string().min(1).nullable(),
  dateOfBirth: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullable(),
  reportedSex: z.enum(["masculino", "femenino", "otro", "prefiero_no_decir"]).nullable(),
  heightCm: z.number().nullable(),
  weightKg: z.number().nullable(),
  academicProgramId: z.number().int().positive().nullable(),
  academicProgramName: z.string().min(1).nullable(),
  careerEntryYear: z.number().int().nullable(),
  bookingProfileComplete: z.boolean(),
  bookingProfileMissingFields: z.array(z.string()),
  regulationAccepted: z.boolean(),
  streakWeeks: z.number().int().nonnegative(),
  themePreference: z.enum(["dark", "light"]),
});

const ACADEMIC_PROGRAM_SCHEMA = z.object({
  academicProgramId: z.number().int().positive(),
  programName: z.string().min(1),
});

const PROFILE_OVERVIEW_RESPONSE_SCHEMA = z.object({
  profile: PROFILE_SCHEMA,
  academicPrograms: z.array(ACADEMIC_PROGRAM_SCHEMA),
});
const PROFILE_ATTENDANCE_RESPONSE_SCHEMA = z.object({
  attendance: z.array(
    z.object({
      bookingDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      status: z.enum(["present", "absent"]),
    }),
  ),
});

const ROUTINE_ASSIGNMENT_SCHEMA = z.object({
  routine_plan_id: z.string().uuid(),
  title: z.string().min(1),
  assigned_at: z.string().datetime({ offset: true }),
  created_by_name: z.string().min(1),
  exercises: z.array(
    z.object({
      exerciseKey: z.string().min(1),
      name: z.string().min(1),
      totalSets: z.number().int().positive(),
      effectiveSets: z.number().int().nonnegative(),
      repetitionsMin: z.number().int().positive(),
      repetitionsMax: z.number().int().positive(),
      loadKg: z.number().nullable(),
      rir: z.number().int().nullable(),
      restSeconds: z.number().int().nullable(),
    }),
  ),
});

type Profile = z.infer<typeof PROFILE_SCHEMA>;
type ProfileOverviewResponse = z.infer<typeof PROFILE_OVERVIEW_RESPONSE_SCHEMA>;
type ProfileMonthResponse = z.infer<typeof PROFILE_ATTENDANCE_RESPONSE_SCHEMA> & {
  monthQuery: string;
};
type RoutineAssignment = z.infer<typeof ROUTINE_ASSIGNMENT_SCHEMA>;
type ProfileFormValues = {
  dateOfBirth: string;
  reportedSex: "" | "masculino" | "femenino" | "otro" | "prefiero_no_decir";
  heightCm: string;
  weightKg: string;
  academicProgramId: string;
  careerEntryYear: string;
};
type ProfileMutationPayload = {
  dateOfBirth: string | null;
  reportedSex: "masculino" | "femenino" | "otro" | "prefiero_no_decir" | null;
  heightCm: number | null;
  weightKg: number | null;
  academicProgramId: number | null;
  careerEntryYear: number | null;
};

const REPORTED_SEX_LABELS = {
  masculino: "Masculino",
  femenino: "Femenino",
  otro: "Otro",
  prefiero_no_decir: "Prefiero no decir",
} as const;

const ROLE_LABELS: Record<AppRole, string> = {
  student: "Estudiante",
  u_staff: "Personal USM",
  gym_staff: "Equipo de sala",
  admin: "Administración",
};

const MIN_HEIGHT_CM = 120;
const MAX_HEIGHT_CM = 230;
const MIN_WEIGHT_KG = 35;
const MAX_WEIGHT_KG = 300;
const MIN_CAREER_ENTRY_YEAR = 2017;
const PROFILE_CONTENT_TRANSITION = {
  duration: 0.18,
  ease: [0.23, 1, 0.32, 1] as const,
};

function getMonthStart(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function getMonthQuery(month: Date) {
  return `${month.getFullYear()}-${String(month.getMonth() + 1).padStart(2, "0")}`;
}

function getAge(dateOfBirth: string, today: Date) {
  const [yearText, monthText, dayText] = dateOfBirth.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const birthdayHasOccurred =
    today.getMonth() + 1 > month || (today.getMonth() + 1 === month && today.getDate() >= day);

  return today.getFullYear() - year - (birthdayHasOccurred ? 0 : 1);
}

function isDateOfBirthValid(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;

  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function createProfileFormValues(profile: Profile): ProfileFormValues {
  return {
    dateOfBirth: profile.dateOfBirth ?? "",
    reportedSex: profile.reportedSex ?? "",
    heightCm: profile.heightCm?.toString() ?? "",
    weightKg: profile.weightKg?.toString() ?? "",
    academicProgramId: profile.academicProgramId?.toString() ?? "",
    careerEntryYear: profile.careerEntryYear?.toString() ?? "",
  };
}

function createProfileMutationPayload(
  formValues: ProfileFormValues,
): { data: ProfileMutationPayload } | { error: string } {
  const dateOfBirth = formValues.dateOfBirth || null;
  const reportedSex = formValues.reportedSex || null;

  if (dateOfBirth && !isDateOfBirthValid(dateOfBirth)) {
    return { error: "Ingresa una fecha de nacimiento válida." };
  }

  const heightCm = formValues.heightCm === "" ? null : Number(formValues.heightCm);
  if (!Number.isFinite(heightCm) && heightCm !== null) {
    return { error: "La altura debe ser un número válido." };
  }
  if (heightCm !== null && (heightCm < MIN_HEIGHT_CM || heightCm > MAX_HEIGHT_CM)) {
    return { error: `La altura debe estar entre ${MIN_HEIGHT_CM} y ${MAX_HEIGHT_CM} cm.` };
  }

  const weightKg = formValues.weightKg === "" ? null : Number(formValues.weightKg);
  if (!Number.isFinite(weightKg) && weightKg !== null) {
    return { error: "El peso debe ser un número válido." };
  }
  if (weightKg !== null && (weightKg < MIN_WEIGHT_KG || weightKg > MAX_WEIGHT_KG)) {
    return { error: `El peso debe estar entre ${MIN_WEIGHT_KG} y ${MAX_WEIGHT_KG} kg.` };
  }

  const academicProgramId =
    formValues.academicProgramId === "" ? null : Number(formValues.academicProgramId);
  if (!Number.isInteger(academicProgramId) && academicProgramId !== null) {
    return { error: "Selecciona una carrera válida." };
  }

  const careerEntryYear =
    formValues.careerEntryYear === "" ? null : Number(formValues.careerEntryYear);
  if (!Number.isInteger(careerEntryYear) && careerEntryYear !== null) {
    return { error: "El año de ingreso debe ser un número entero." };
  }
  if (
    careerEntryYear !== null &&
    (careerEntryYear < MIN_CAREER_ENTRY_YEAR || careerEntryYear > getSantiagoToday().getFullYear())
  ) {
    return {
      error: `El año de ingreso debe estar entre ${MIN_CAREER_ENTRY_YEAR} y ${getSantiagoToday().getFullYear()}.`,
    };
  }

  return {
    data: {
      dateOfBirth,
      reportedSex,
      heightCm,
      weightKg,
      academicProgramId,
      careerEntryYear,
    },
  };
}

function getProfileValue(value: string | number | null) {
  return value === null ? "No informado" : value;
}

function truncateHeightInput(value: string) {
  const normalizedValue = value.replace(",", ".").replace(/[^\d.]/g, "");
  const parts = normalizedValue.split(".");
  const integerPart = (parts[0] ?? "").slice(0, 3);

  if (parts.length === 1) return integerPart;

  return `${integerPart}.${parts.slice(1).join("").slice(0, 2)}`;
}

function truncateWeightInput(value: string) {
  const normalizedValue = value.replace(",", ".").replace(/[^\d.]/g, "");
  const parts = normalizedValue.split(".");
  const integerPart = parts[0] ?? "";
  const decimalParts = parts.slice(1);
  const truncatedIntegerPart = integerPart.slice(0, 3);

  if (decimalParts.length === 0) return truncatedIntegerPart;

  return `${truncatedIntegerPart}.${decimalParts.join("").slice(0, 2)}`;
}

async function getProfileOverview(monthQuery: string): Promise<ProfileOverviewResponse> {
  const profileParameters = new URLSearchParams({
    includeAttendance: "false",
    includeOverview: "true",
    month: monthQuery,
  });
  const response = await fetch(`/api/profile?${profileParameters.toString()}`, {
    cache: "no-store",
  });

  if (!response.ok) throw new Error("Profile request was rejected.");

  const payload: unknown = await response.json();
  const profileResponse = PROFILE_OVERVIEW_RESPONSE_SCHEMA.safeParse(payload);
  if (!profileResponse.success) throw new Error("Profile response is invalid.");

  if (profileResponse.data.profile.themePreference !== getDocumentThemePreference()) {
    applyThemePreference(profileResponse.data.profile.themePreference);
  }

  return profileResponse.data;
}

async function getProfileAttendance(monthQuery: string): Promise<ProfileMonthResponse> {
  const profileParameters = new URLSearchParams({
    includeAttendance: "true",
    includeOverview: "false",
    month: monthQuery,
  });
  const response = await fetch(`/api/profile?${profileParameters.toString()}`, {
    cache: "no-store",
  });

  if (!response.ok) throw new Error("Profile attendance request was rejected.");

  const payload: unknown = await response.json();
  const attendanceResponse = PROFILE_ATTENDANCE_RESPONSE_SCHEMA.safeParse(payload);
  if (!attendanceResponse.success) throw new Error("Profile attendance response is invalid.");

  return { ...attendanceResponse.data, monthQuery };
}

async function saveProfileData(profileData: ProfileMutationPayload) {
  const response = await fetch("/api/profile", {
    method: "POST",
    cache: "no-store",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(profileData),
  });

  if (response.status !== 204) throw new Error("Profile update was rejected.");
}

async function getOwnRoutineAssignments(): Promise<RoutineAssignment[]> {
  const supabase = CREATE_SUPABASE_BROWSER_CLIENT();
  const { data, error } = await supabase.rpc("get_own_routine_assignments");

  if (error) throw new Error("Routine assignments request was rejected.");

  const parsedAssignments = z.array(ROUTINE_ASSIGNMENT_SCHEMA).safeParse(data);
  if (!parsedAssignments.success) throw new Error("Routine assignments response is invalid.");

  return parsedAssignments.data;
}

export default function ProfilePage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const today = getSantiagoToday();
  const shouldReduceMotion = useReducedMotion();
  const [visibleMonth, setVisibleMonth] = useState(() => getMonthStart(today));
  const [isPersonalInfoEditing, setIsPersonalInfoEditing] = useState(false);
  const [formValues, setFormValues] = useState<ProfileFormValues>({
    dateOfBirth: "",
    reportedSex: "",
    heightCm: "",
    weightKg: "",
    academicProgramId: "",
    careerEntryYear: "",
  });
  const [formError, setFormError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  const monthQuery = getMonthQuery(visibleMonth);
  const profileQuery = useQuery({
    queryKey: PROFILE_QUERY_KEY,
    queryFn: () => getProfileOverview(monthQuery),
    staleTime: 5 * 60_000,
  });
  const attendanceQuery = useQuery({
    queryKey: profileMonthQueryKey(monthQuery),
    queryFn: () => getProfileAttendance(monthQuery),
    placeholderData: keepPreviousData,
    staleTime: 5 * 60_000,
  });
  const routineAssignmentsQuery = useQuery({
    queryKey: ["own-routine-assignments"],
    queryFn: getOwnRoutineAssignments,
    staleTime: 5 * 60_000,
  });
  const profile = profileQuery.data?.profile ?? null;
  const academicPrograms = profileQuery.data?.academicPrograms ?? [];
  const attendanceForVisibleMonth: ProfileAttendanceEntry[] =
    attendanceQuery.data?.monthQuery === monthQuery ? attendanceQuery.data.attendance : [];
  const isAttendanceLoading = attendanceQuery.isLoading;
  const loadError = profileQuery.isError;
  const saveProfileMutation = useMutation({
    mutationFn: saveProfileData,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: PROFILE_QUERY_KEY });
    },
  });

  useEffect(() => {
    if (!profile) return;

    queryClient.setQueryData<CurrentUser>(CURRENT_USER_QUERY_KEY, (currentUser) =>
      currentUser
        ? {
            ...currentUser,
            userName: profile.userName,
            role: profile.role,
            bookingProfileComplete: profile.bookingProfileComplete,
            regulationAccepted: profile.regulationAccepted,
            streakWeeks: profile.streakWeeks,
            themePreference: profile.themePreference,
          }
        : currentUser,
    );
  }, [profile, queryClient]);

  function openEditor() {
    if (!profile) return;

    setFormValues(createProfileFormValues(profile));
    setFormError(null);
    setIsPersonalInfoEditing(true);
  }

  function closeEditor() {
    if (isSaving) return;

    setIsPersonalInfoEditing(false);
    setFormError(null);
  }

  async function saveProfile(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const profileData = createProfileMutationPayload(formValues);

    if ("error" in profileData) {
      setFormError(profileData.error);
      return;
    }

    setFormError(null);
    setIsSaving(true);

    try {
      await saveProfileMutation.mutateAsync(profileData.data);
      setIsPersonalInfoEditing(false);
    } catch (error) {
      console.error("[PROFILE] could not save profile data.", error);
      setFormError("No fue posible guardar tus datos. Intenta nuevamente.");
    } finally {
      setIsSaving(false);
    }
  }

  async function signOut() {
    const supabase = CREATE_SUPABASE_BROWSER_CLIENT();
    const { error } = await supabase.auth.signOut();

    if (error) {
      console.error("[PROFILE] could not sign out.", error);
      return;
    }

    clearQueryCache();
    router.replace("/login");
  }

  async function updateThemePreference(themePreference: ThemePreference) {
    try {
      const response = await fetch("/api/theme-preference", {
        method: "POST",
        cache: "no-store",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ themePreference }),
      });

      if (response.status !== 204) {
        throw new Error("Theme preference update was rejected.");
      }

      queryClient.setQueriesData<ProfileOverviewResponse>(
        { queryKey: PROFILE_QUERY_KEY },
        (currentProfile) =>
          currentProfile
            ? {
                ...currentProfile,
                profile: { ...currentProfile.profile, themePreference },
              }
            : currentProfile,
      );
      queryClient.setQueryData<CurrentUser>(CURRENT_USER_QUERY_KEY, (user) =>
        user ? { ...user, themePreference } : user,
      );
      return true;
    } catch (error) {
      console.error("[PROFILE] could not update theme preference.", error);
      return false;
    }
  }

  function goToPreviousMonth() {
    setVisibleMonth((month) => new Date(month.getFullYear(), month.getMonth() - 1, 1));
  }

  function goToNextMonth() {
    if (monthQuery === getMonthQuery(getMonthStart(today))) return;

    setVisibleMonth((month) => new Date(month.getFullYear(), month.getMonth() + 1, 1));
  }

  const cachedStreakWeeks = profileQuery.data?.profile.streakWeeks ?? 0;
  const age = profile?.dateOfBirth ? getAge(profile.dateOfBirth, today) : null;
  const sexLabel = profile?.reportedSex ? REPORTED_SEX_LABELS[profile.reportedSex] : null;
  const isMandatoryProfileComplete = profile?.bookingProfileComplete ?? false;
  const isRegulationAccepted = profile?.regulationAccepted ?? false;
  return (
    <main className="flex min-h-svh w-full justify-center bg-bg">
      <div className="flex h-svh gusm-app-shell flex-col overflow-hidden">
        <header className="z-20 shrink-0 border-b border-divider bg-surface">
          <UserTopBar
            pageTitle="Perfil"
            userName={profile?.userName}
            role={profile?.role}
            onGoOvercapacity={() => router.push("/bloque")}
            onGoRoutines={() => router.push("/rutinas")}
            onGoSettings={() => router.push("/configuracion")}
            onSignOut={signOut}
            onThemePreferenceChange={updateThemePreference}
            themeTransitionStyle="fade"
          />
        </header>

        <div className="flex gusm-page-scroll flex-col gap-4 px-4 pt-5 pb-[calc(5.5rem+env(safe-area-inset-bottom))]">
          {loadError && !profile ? (
            <section className="flex flex-1 flex-col items-center justify-center gap-4 px-6 text-center">
              <p className="text-base text-foreground-muted">No fue posible cargar tu perfil.</p>
              <button
                type="button"
                onClick={() => void profileQuery.refetch()}
                className="gusm-button-primary"
              >
                Reintentar
              </button>
            </section>
          ) : (
            <>
              <ProfileCalendar
                attendance={attendanceForVisibleMonth}
                isLoading={isAttendanceLoading}
                month={visibleMonth}
                onPreviousMonth={goToPreviousMonth}
                onNextMonth={goToNextMonth}
                today={today}
              />

              <StreakMilestoneProgress streakWeeks={profile?.streakWeeks ?? cachedStreakWeeks} />

              {attendanceQuery.isError && (
                <p role="alert" className="text-sm text-rose-400">
                  No fue posible actualizar este mes. Se muestra la información disponible.
                </p>
              )}

              <section className="rounded-2xl border border-accent/15 bg-input/30 px-4 py-4">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="text-xs font-medium tracking-[0.12em] text-dim uppercase">
                      Información personal
                    </p>
                    <h2 className="mt-1 text-lg font-semibold text-foreground">Datos personales</h2>
                  </div>
                  <button
                    type="button"
                    onClick={isPersonalInfoEditing ? closeEditor : openEditor}
                    disabled={!profile || (isPersonalInfoEditing && isSaving)}
                    aria-label={
                      isPersonalInfoEditing
                        ? "Cancelar edición de información personal"
                        : "Editar información personal"
                    }
                    className="flex size-11 items-center justify-center rounded-full text-accent transition-colors hover:bg-accent/10 disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    {isPersonalInfoEditing ? (
                      <X className="size-4" aria-hidden="true" />
                    ) : (
                      <Pencil className="size-4" aria-hidden="true" />
                    )}
                  </button>
                </div>

                <AnimatePresence initial={false} mode="wait">
                  {isPersonalInfoEditing ? (
                    <motion.form
                      key="editing"
                      aria-label="Editar información personal"
                      onSubmit={saveProfile}
                      initial={
                        shouldReduceMotion ? false : { opacity: 0, transform: "translateY(6px)" }
                      }
                      animate={{ opacity: 1, transform: "translateY(0)" }}
                      exit={
                        shouldReduceMotion
                          ? undefined
                          : { opacity: 0, transform: "translateY(-4px)" }
                      }
                      transition={shouldReduceMotion ? { duration: 0 } : PROFILE_CONTENT_TRANSITION}
                      className="mt-4 grid grid-cols-2 gap-x-3 gap-y-4 border-t border-divider/80 pt-4 lg:grid-cols-4"
                    >
                      <label className="grid min-w-0 gap-1.5 text-sm text-foreground-muted">
                        <span className="grid gap-0.5">
                          <span>Fecha de nacimiento</span>
                          <span className="text-red-500">Requerido</span>
                        </span>
                        <input
                          type="date"
                          value={formValues.dateOfBirth}
                          onChange={(event) =>
                            setFormValues((currentValues) => ({
                              ...currentValues,
                              dateOfBirth: event.target.value,
                            }))
                          }
                          max={
                            getMonthQuery(today) + `-${String(today.getDate()).padStart(2, "0")}`
                          }
                          className="gusm-input-primary"
                        />
                      </label>

                      <label className="grid min-w-0 gap-1.5 text-sm text-foreground-muted">
                        <span className="grid gap-0.5">
                          <span>Sexo declarado</span>
                          <span className="text-red-500">Requerido</span>
                        </span>
                        <select
                          value={formValues.reportedSex}
                          onChange={(event) =>
                            setFormValues((currentValues) => ({
                              ...currentValues,
                              reportedSex:
                                event.target.value === "masculino" ||
                                event.target.value === "femenino" ||
                                event.target.value === "otro" ||
                                event.target.value === "prefiero_no_decir"
                                  ? event.target.value
                                  : "",
                            }))
                          }
                          className="gusm-input-primary"
                        >
                          <option value="">No informado</option>
                          <option value="masculino">Masculino</option>
                          <option value="femenino">Femenino</option>
                          <option value="otro">Otro</option>
                          <option value="prefiero_no_decir">Prefiero no decir</option>
                        </select>
                      </label>

                      <label className="grid min-w-0 gap-1.5 text-sm text-foreground-muted">
                        <span className="grid gap-0.5">
                          <span>Altura (cm)</span>
                          <span className="text-red-500">Requerido</span>
                        </span>
                        <input
                          type="text"
                          inputMode="decimal"
                          maxLength={6}
                          value={formValues.heightCm}
                          onChange={(event) =>
                            setFormValues((currentValues) => ({
                              ...currentValues,
                              heightCm: truncateHeightInput(event.target.value),
                            }))
                          }
                          className="gusm-input-primary"
                        />
                      </label>

                      <label className="grid min-w-0 gap-1.5 text-sm text-foreground-muted">
                        <span className="grid gap-0.5">
                          <span>Peso (kg)</span>
                          <span className="text-red-500">Requerido</span>
                        </span>
                        <input
                          type="text"
                          inputMode="decimal"
                          maxLength={6}
                          value={formValues.weightKg}
                          onChange={(event) =>
                            setFormValues((currentValues) => ({
                              ...currentValues,
                              weightKg: truncateWeightInput(event.target.value),
                            }))
                          }
                          className="gusm-input-primary"
                        />
                      </label>

                      <label className="col-span-2 grid min-w-0 gap-1.5 text-sm text-foreground-muted lg:col-span-3">
                        <span className="grid gap-0.5">
                          <span>Carrera</span>
                          <span className="text-red-500">Requerido</span>
                        </span>
                        <select
                          value={formValues.academicProgramId}
                          onChange={(event) =>
                            setFormValues((currentValues) => ({
                              ...currentValues,
                              academicProgramId: event.target.value,
                            }))
                          }
                          className="gusm-input-primary"
                        >
                          <option value="">Selecciona tu carrera</option>
                          {academicPrograms.map((academicProgram) => (
                            <option
                              key={academicProgram.academicProgramId}
                              value={academicProgram.academicProgramId}
                            >
                              {academicProgram.programName}
                            </option>
                          ))}
                        </select>
                      </label>

                      <label className="col-span-2 grid min-w-0 gap-1.5 text-sm text-foreground-muted lg:col-span-1 lg:max-w-44">
                        <span className="grid gap-0.5">
                          <span>Año de ingreso</span>
                          <span className="text-red-500">Requerido</span>
                        </span>
                        <input
                          type="text"
                          inputMode="numeric"
                          maxLength={4}
                          value={formValues.careerEntryYear}
                          onChange={(event) =>
                            setFormValues((currentValues) => ({
                              ...currentValues,
                              careerEntryYear: event.target.value.replace(/\D/g, "").slice(0, 4),
                            }))
                          }
                          className="gusm-input-primary"
                        />
                      </label>

                      {formError && (
                        <p role="alert" className="col-span-2 text-sm text-rose-400 lg:col-span-4">
                          {formError}
                        </p>
                      )}

                      <div className="col-span-2 mt-2 grid grid-cols-2 gap-3 border-t border-divider/80 pt-4 lg:col-span-4">
                        <button
                          type="button"
                          onClick={closeEditor}
                          disabled={isSaving}
                          className="gusm-control-height rounded-xl border border-divider px-4 text-base text-foreground-muted transition-colors hover:border-muted disabled:cursor-not-allowed disabled:opacity-50"
                        >
                          Cancelar
                        </button>
                        <button
                          type="submit"
                          disabled={isSaving}
                          className="flex gusm-button-primary items-center justify-center gap-2"
                        >
                          {isSaving && (
                            <Loader2 className="size-4 animate-spin" aria-hidden="true" />
                          )}
                          Guardar
                        </button>
                      </div>
                    </motion.form>
                  ) : (
                    <motion.dl
                      key="reading"
                      initial={
                        shouldReduceMotion ? false : { opacity: 0, transform: "translateY(4px)" }
                      }
                      animate={{ opacity: 1, transform: "translateY(0)" }}
                      exit={
                        shouldReduceMotion
                          ? undefined
                          : { opacity: 0, transform: "translateY(-4px)" }
                      }
                      transition={shouldReduceMotion ? { duration: 0 } : PROFILE_CONTENT_TRANSITION}
                      className="mt-4 grid grid-cols-2 gap-x-3 gap-y-4 border-t border-divider/80 pt-4 lg:grid-cols-4"
                    >
                      <div className="min-w-0">
                        <dt className="text-sm text-dim">Edad</dt>
                        <dd className="mt-1 truncate text-base font-medium text-foreground">
                          {getProfileValue(age)}
                        </dd>
                      </div>
                      <div className="min-w-0">
                        <dt className="text-sm text-dim">Sexo declarado</dt>
                        <dd className="mt-1 truncate text-base font-medium text-foreground">
                          {getProfileValue(sexLabel)}
                        </dd>
                      </div>
                      <div className="min-w-0">
                        <dt className="text-sm text-dim">Altura</dt>
                        <dd className="mt-1 truncate text-base font-medium text-foreground">
                          {profile?.heightCm === null || profile?.heightCm === undefined
                            ? "No informada"
                            : `${profile.heightCm} cm`}
                        </dd>
                      </div>
                      <div className="min-w-0">
                        <dt className="text-sm text-dim">Peso</dt>
                        <dd className="mt-1 truncate text-base font-medium text-foreground">
                          {profile?.weightKg === null || profile?.weightKg === undefined
                            ? "No informado"
                            : `${profile.weightKg} kg`}
                        </dd>
                      </div>
                      <div className="min-w-0 lg:col-span-3">
                        <dt className="text-sm text-dim">Carrera</dt>
                        <dd className="mt-1 text-base leading-5 font-medium text-foreground">
                          {getProfileValue(profile?.academicProgramName ?? null)}
                        </dd>
                      </div>
                      <div className="min-w-0 lg:col-span-1">
                        <dt className="text-sm text-dim">Año de ingreso</dt>
                        <dd className="mt-1 truncate text-base font-medium text-foreground">
                          {getProfileValue(profile?.careerEntryYear ?? null)}
                        </dd>
                      </div>
                    </motion.dl>
                  )}
                </AnimatePresence>
              </section>

              {routineAssignmentsQuery.data && routineAssignmentsQuery.data.length > 0 && (
                <section className="rounded-2xl border border-accent/15 bg-input/30 px-4 py-4">
                  <p className="text-xs font-medium tracking-[0.12em] text-dim uppercase">
                    Rutinas
                  </p>
                  <h2 className="mt-1 text-lg font-semibold text-foreground">
                    Tu pauta de entrenamiento
                  </h2>
                  <div className="mt-4 divide-y divide-accent/15 border-y border-accent/15">
                    {routineAssignmentsQuery.data.map((routineAssignment) => (
                      <details key={routineAssignment.routine_plan_id} className="group py-3">
                        <summary className="flex cursor-pointer list-none items-center justify-between gap-4 text-base font-medium text-foreground marker:hidden">
                          <span className="flex min-w-0 items-center gap-3">
                            <Dumbbell className="size-4 shrink-0 text-accent" aria-hidden="true" />
                            <span className="truncate">{routineAssignment.title}</span>
                          </span>
                          <span className="shrink-0 text-sm font-normal text-muted">
                            {routineAssignment.exercises.length} ejercicios
                          </span>
                        </summary>
                        <p className="mt-2 text-sm text-muted">
                          Asignada por {routineAssignment.created_by_name}
                        </p>
                        <ul className="mt-3 grid gap-2 border-t border-divider/80 pt-3">
                          {routineAssignment.exercises.map((exercise) => (
                            <li
                              key={exercise.exerciseKey}
                              className="flex items-center justify-between gap-3 text-sm text-foreground-muted"
                            >
                              <span className="min-w-0 truncate">{exercise.name}</span>
                              <span className="shrink-0 text-dim">
                                {exercise.totalSets} × {exercise.repetitionsMin}
                                {exercise.repetitionsMin !== exercise.repetitionsMax
                                  ? `-${exercise.repetitionsMax}`
                                  : ""}
                              </span>
                            </li>
                          ))}
                        </ul>
                      </details>
                    ))}
                  </div>
                </section>
              )}

              <section
                id="acceso"
                className="rounded-2xl border border-accent/15 bg-input/30 px-4 py-4"
              >
                <p className="text-xs font-medium tracking-[0.12em] text-dim uppercase">
                  Acceso a la sala
                </p>
                <h2 className="mt-1 text-lg font-semibold text-foreground">
                  Requisitos para reservar
                </h2>
                <p className="mt-2 text-sm leading-5 text-muted">
                  Debes completar los siguientes pasos para poder reservar.
                </p>

                <div className="mt-4 divide-y divide-accent/15 border-y border-accent/15">
                  <div className="flex items-center justify-between gap-4 py-3">
                    <div className="min-w-0">
                      <div className="flex items-center gap-1">
                        <p className="text-base font-medium text-foreground">Reglamento de uso</p>
                        <Link
                          href="/terminos"
                          aria-label="Consultar reglamento de uso"
                          title="Consultar reglamento de uso"
                          className="flex size-8 shrink-0 items-center justify-center rounded-lg text-accent transition-colors hover:bg-accent/10 focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none"
                        >
                          <BookOpenCheck className="size-4" aria-hidden="true" />
                        </Link>
                      </div>
                      {!isRegulationAccepted && (
                        <p className="mt-0.5 text-sm text-muted">Pendiente de aceptación</p>
                      )}
                    </div>
                    {isRegulationAccepted ? (
                      <CheckCircle2
                        className="size-5 shrink-0 text-emerald-500"
                        aria-label="Aceptado"
                      />
                    ) : null}
                  </div>

                  <div className="flex items-center justify-between gap-4 py-3">
                    <div className="min-w-0">
                      <p className="text-base font-medium text-foreground">Datos principales</p>
                    </div>
                    {isMandatoryProfileComplete ? (
                      <CheckCircle2
                        className="size-5 shrink-0 text-emerald-500"
                        aria-label="Completos"
                      />
                    ) : (
                      <button
                        type="button"
                        onClick={openEditor}
                        className="min-h-11 shrink-0 px-1 text-base font-semibold text-accent underline decoration-accent/50 underline-offset-4 transition-colors hover:text-accent/75 focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none"
                      >
                        Completar
                      </button>
                    )}
                  </div>
                </div>
              </section>

              <section className="rounded-2xl border border-accent/15 bg-input/30 px-4 py-4">
                <p className="text-xs font-medium tracking-[0.12em] text-dim uppercase">Cuenta</p>
                <dl className="mt-3 divide-y divide-accent/15 border-y border-accent/15">
                  <div className="flex items-center justify-between gap-4 py-3">
                    <dt className="text-sm text-muted">Usuario institucional</dt>
                    <dd className="min-w-0 truncate text-base font-medium text-foreground">
                      {profile?.institutionalUsername ?? "No disponible"}
                    </dd>
                  </div>
                  <div className="flex items-center justify-between gap-4 py-3">
                    <dt className="text-sm text-muted">Rol</dt>
                    <dd className="text-base font-medium text-foreground">
                      {profile ? ROLE_LABELS[profile.role] : ""}
                    </dd>
                  </div>
                </dl>
              </section>
            </>
          )}
        </div>
      </div>
    </main>
  );
}
