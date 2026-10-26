"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { usePathname, useRouter } from "next/navigation";
import {
  BarChart3,
  CalendarCheck,
  CalendarDays,
  Dumbbell,
  Flame,
  LayoutDashboard,
  LogOut,
  Menu,
  Newspaper,
  QrCode,
  Settings,
  type LucideIcon,
  User,
  Users,
} from "lucide-react";
import clsx from "clsx";
import { motion, useReducedMotion } from "motion/react";
import { useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import { CREATE_SUPABASE_BROWSER_CLIENT } from "@gusm/database/client";
import { ActiveBookingsPanel } from "@/components/ActiveBookingsPanel";
import { SignOutConfirmationDialog } from "@/components/SignOutConfirmationDialog";
import { ThemeToggle } from "@/components/ThemeToggle";
import landingStyles from "@/app/landing.module.css";
import {
  bookingWeekAvailabilityQueryKey,
  getBookingWeekAvailability,
} from "@/lib/booking/availability";
import { createActiveBookings, getActiveBookingWeekStarts } from "@/lib/booking/active-bookings";
import { getCurrentUser } from "@/lib/current-user";
import { CURRENT_USER_QUERY_KEY } from "@/lib/query-keys";
import type { ThemePreference } from "@/lib/theme";
import { notifyError } from "@/lib/toast";

const SPANISH_PLURAL_RULES = new Intl.PluralRules("es-CL");
const STREAK_GLOW_DURATION_MILLISECONDS = 1500;

export type AppRole = "student" | "u_staff" | "gym_staff" | "admin";

type ActivePopover = "bookings" | "menu" | "streak" | null;
type MenuItemVariant = "default" | "destructive";

type AvatarMenuItem = {
  href?: string;
  label: string;
  icon: LucideIcon;
  onClick: () => void | Promise<void>;
  variant?: MenuItemVariant;
};

type DesktopNavigationItem = {
  href: string;
  label: string;
  icon: LucideIcon;
};

const DESKTOP_NAVIGATION_ITEMS: DesktopNavigationItem[] = [
  { href: "/reserva", label: "Reserva", icon: CalendarDays },
  { href: "/perfil", label: "Perfil", icon: User },
  { href: "/qr", label: "QR", icon: QrCode },
  { href: "/estadisticas", label: "Cifras", icon: BarChart3 },
  { href: "/noticias", label: "Noticias", icon: Newspaper },
];

type UserTopBarProps = {
  accountLabel?: string;
  pageTitle?: string;
  userName?: string;
  role?: AppRole;
  streakWeeks?: number;
  onGoProfile?: () => void;
  onGoCheckIn?: () => void;
  onGoOvercapacity?: () => void;
  onGoInformation?: () => void;
  onGoRoutines?: () => void;
  onGoSettings?: () => void;
  onSignOut?: () => void | Promise<void>;
  onThemePreferenceChange?: (themePreference: ThemePreference) => Promise<boolean>;
  themeTransitionStyle?: "diagonal" | "fade";
  showUserName?: boolean;
};

function isAtLeastStaff(role: AppRole): boolean {
  return role === "gym_staff" || role === "admin";
}

function isAdmin(role: AppRole): boolean {
  return role === "admin";
}

function usesDirectAccountActions(role: AppRole | undefined): boolean {
  return role === "student" || role === "u_staff";
}

function getStreakSeenStorageKey(userName: string): string {
  return `gymu:streak-weeks:${userName.trim().toLocaleLowerCase("es-CL")}`;
}

function getStoredStreakWeeks(storageKey: string): number {
  const value = Number(window.localStorage.getItem(storageKey));
  return Number.isInteger(value) && value >= 0 ? value : 0;
}

export function UserTopBar({
  accountLabel,
  pageTitle,
  userName,
  role,
  streakWeeks,
  onGoProfile,
  onGoCheckIn,
  onGoOvercapacity,
  onGoInformation,
  onGoRoutines,
  onGoSettings,
  onSignOut,
  onThemePreferenceChange,
  themeTransitionStyle,
  showUserName = true,
}: UserTopBarProps) {
  const pathname = usePathname();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [activePopover, setActivePopover] = useState<ActivePopover>(null);
  const [isSignOutConfirmationOpen, setIsSignOutConfirmationOpen] = useState(false);
  const [isStreakCelebrating, setIsStreakCelebrating] = useState(false);
  const topBarRef = useRef<HTMLDivElement>(null);
  const shouldReduceMotion = useReducedMotion();
  const currentUserQuery = useQuery({
    queryKey: CURRENT_USER_QUERY_KEY,
    queryFn: getCurrentUser,
    staleTime: 60_000,
  });
  const currentUser = currentUserQuery.data;
  const topBarRole = role ?? currentUser?.role;
  const topBarUserName = userName ?? currentUser?.userName;
  const topBarStreakWeeks = streakWeeks ?? currentUser?.streakWeeks;
  const previousStreakWeeksRef = useRef(topBarStreakWeeks);
  const [currentWeekStart, followingWeekStart] = getActiveBookingWeekStarts();
  const activeBookingQueries = useQueries({
    queries: [currentWeekStart, followingWeekStart].map((weekStart) => ({
      queryKey: bookingWeekAvailabilityQueryKey(weekStart),
      queryFn: () => getBookingWeekAvailability(weekStart),
      staleTime: 60_000,
      gcTime: 10 * 60_000,
      enabled: topBarRole !== undefined,
    })),
  });
  const activeBookings = useMemo(
    () => createActiveBookings(activeBookingQueries.flatMap((query) => query.data ?? [])),
    [activeBookingQueries],
  );

  const closePopover = useCallback(() => {
    setActivePopover(null);
  }, []);

  useEffect(() => {
    if (activePopover === null) return;

    function closeOnOutsideClick(event: MouseEvent) {
      if (
        event.target instanceof Element &&
        (topBarRef.current?.contains(event.target) ||
          event.target.closest("[data-active-bookings-panel]"))
      ) {
        return;
      }

      closePopover();
    }

    document.addEventListener("click", closeOnOutsideClick);
    return () => document.removeEventListener("click", closeOnOutsideClick);
  }, [activePopover, closePopover]);

  useEffect(() => {
    const previousStreakWeeks = previousStreakWeeksRef.current;
    previousStreakWeeksRef.current = topBarStreakWeeks;

    if (topBarStreakWeeks === undefined || !topBarUserName) return;

    const storageKey = getStreakSeenStorageKey(topBarUserName);
    const storedStreakWeeks = getStoredStreakWeeks(storageKey);
    const previousKnownStreakWeeks = previousStreakWeeks ?? storedStreakWeeks;
    window.localStorage.setItem(storageKey, String(topBarStreakWeeks));

    if (topBarStreakWeeks <= previousKnownStreakWeeks) return;

    setIsStreakCelebrating(true);
    const timeout = window.setTimeout(() => {
      setIsStreakCelebrating(false);
    }, STREAK_GLOW_DURATION_MILLISECONDS);

    return () => window.clearTimeout(timeout);
  }, [topBarStreakWeeks, topBarUserName]);

  function togglePopover(event: React.MouseEvent<HTMLButtonElement>, popover: ActivePopover) {
    event.stopPropagation();
    setActivePopover((currentPopover) => (currentPopover === popover ? null : popover));
  }

  function handleMenuItemClick(menuItem: AvatarMenuItem) {
    closePopover();

    if (menuItem.variant === "destructive") {
      setIsSignOutConfirmationOpen(true);
      return;
    }

    void menuItem.onClick();
  }

  function confirmSignOut() {
    setIsSignOutConfirmationOpen(false);
    if (onSignOut) void onSignOut();
  }

  async function confirmActiveBooking(bookingKey: string) {
    const supabase = CREATE_SUPABASE_BROWSER_CLIENT();
    const { error } = await supabase.rpc("confirm_booking", { p_booking_id: bookingKey });

    if (error) {
      notifyError("No fue posible confirmar la reserva", {
        description:
          "Su estado pudo haber cambiado. Actualiza la disponibilidad e inténtalo otra vez.",
        zone: "top",
      });
      return;
    }

    await queryClient.invalidateQueries({ queryKey: ["booking-week-availability"] });
  }

  async function cancelActiveBooking(bookingKey: string) {
    const supabase = CREATE_SUPABASE_BROWSER_CLIENT();
    const { error } = await supabase.rpc("cancel_booking", { p_booking_id: bookingKey });

    if (error) {
      notifyError("No fue posible cancelar la reserva", {
        description:
          "Su estado pudo haber cambiado. Actualiza la disponibilidad e inténtalo otra vez.",
        zone: "top",
      });
      return;
    }

    await queryClient.invalidateQueries({ queryKey: ["booking-week-availability"] });
  }

  const streakLabel =
    topBarStreakWeeks === undefined
      ? null
      : SPANISH_PLURAL_RULES.select(topBarStreakWeeks) === "one"
        ? "semana entrenando"
        : "semanas entrenando";

  const avatarMenu: AvatarMenuItem[] = [];
  const hasManagementMenu = topBarRole !== undefined && isAtLeastStaff(topBarRole);
  const showDirectSignOut = usesDirectAccountActions(topBarRole) && onSignOut !== undefined;

  if (hasManagementMenu) {
    if (onGoOvercapacity) {
      avatarMenu.push({
        href: "/bloque",
        label: "Bloque actual",
        icon: Users,
        onClick: onGoOvercapacity,
      });
    }
    if (onGoRoutines) {
      avatarMenu.push({
        href: "/rutinas",
        label: "Rutinas",
        icon: Dumbbell,
        onClick: onGoRoutines,
      });
    }
    if (topBarRole && isAdmin(topBarRole) && onGoSettings) {
      avatarMenu.push({
        href: "/configuracion",
        label: "Configuración",
        icon: Settings,
        onClick: onGoSettings,
      });
    }
    if (onSignOut) {
      avatarMenu.push({
        label: "Cerrar sesión",
        icon: LogOut,
        onClick: onSignOut,
        variant: "destructive",
      });
    }
  } else if (role === undefined) {
    if (onGoProfile) {
      avatarMenu.push({ label: "Perfil", icon: User, onClick: onGoProfile });
    }
    if (onGoCheckIn) {
      avatarMenu.push({ label: "Marcar asistencia", icon: QrCode, onClick: onGoCheckIn });
    }
    if (onGoInformation) {
      avatarMenu.push({ label: "Información", icon: LayoutDashboard, onClick: onGoInformation });
    }
    if (onSignOut) {
      avatarMenu.push({
        label: "Cerrar sesión",
        icon: LogOut,
        onClick: onSignOut,
        variant: "destructive",
      });
    }
  }

  const showsDesktopNavigation = topBarRole !== undefined;
  const hasMenu = avatarMenu.length > 0 || showsDesktopNavigation;
  const hasStreak = topBarStreakWeeks !== undefined && streakLabel !== null;
  const desktopMenuItems = avatarMenu.filter((menuItem) => menuItem.variant !== "destructive");
  const desktopSignOutItem = avatarMenu.find((menuItem) => menuItem.variant === "destructive");

  return (
    <div
      ref={topBarRef}
      className="flex min-h-12 items-center justify-between gap-3 px-4 pt-[max(0.25rem,env(safe-area-inset-top))] pb-1"
    >
      <div className="flex min-w-0 items-center gap-2 text-accent">
        {hasMenu && (
          <div className="relative shrink-0">
            <button
              type="button"
              onClick={(event) => togglePopover(event, "menu")}
              aria-expanded={activePopover === "menu"}
              aria-label="Abrir menú de cuenta"
              className={clsx(
                "flex size-8 items-center justify-center text-accent transition-transform active:scale-95",
                avatarMenu.length === 0 && "hidden lg:flex",
              )}
            >
              <Menu className="size-4" aria-hidden="true" />
            </button>

            {activePopover === "menu" && (
              <div
                className={clsx(
                  "absolute top-full left-0 z-50 mt-2 flex min-w-52 flex-col rounded-xl",
                  "border border-divider bg-surface p-1 shadow-xl",
                  "animate-in fade-in slide-in-from-top-1 duration-200",
                )}
              >
                {avatarMenu.map((menuItem) => {
                  const Icon = menuItem.icon;
                  const isDestructive = menuItem.variant === "destructive";
                  const isCurrentRoute = menuItem.href === pathname;

                  return (
                    <button
                      key={menuItem.label}
                      type="button"
                      onClick={() => handleMenuItemClick(menuItem)}
                      className={clsx(
                        "flex items-center gap-2 rounded-lg px-3 py-2 text-left text-base transition-colors",
                        showsDesktopNavigation && "lg:hidden",
                        isDestructive
                          ? "text-red-500 hover:bg-red-500/10"
                          : isCurrentRoute
                            ? "bg-accent/12 text-accent"
                            : "text-foreground-muted hover:bg-accent/10 hover:text-accent",
                      )}
                    >
                      <Icon className="size-4" aria-hidden="true" />
                      {menuItem.label}
                    </button>
                  );
                })}

                {showsDesktopNavigation && topBarRole && (
                  <div className="hidden flex-col lg:flex">
                    <div className="mx-3 border-b border-divider py-2">
                      <span className="text-xs font-medium tracking-[0.12em] text-dim">
                        @{topBarRole}
                      </span>
                    </div>
                    <div className="flex flex-col py-1">
                      {DESKTOP_NAVIGATION_ITEMS.map((menuItem) => {
                        const Icon = menuItem.icon;
                        const isCurrentRoute = menuItem.href === pathname;

                        return (
                          <button
                            key={menuItem.href}
                            type="button"
                            onClick={() => {
                              closePopover();
                              router.push(menuItem.href);
                            }}
                            className={clsx(
                              "flex items-center gap-2 rounded-lg px-3 py-2 text-left text-base transition-colors",
                              isCurrentRoute
                                ? "bg-accent/12 text-accent"
                                : "text-foreground-muted hover:bg-accent/10 hover:text-accent",
                            )}
                          >
                            <Icon className="size-4" aria-hidden="true" />
                            {menuItem.label}
                          </button>
                        );
                      })}
                    </div>
                    {desktopMenuItems.length > 0 && (
                      <div className="flex flex-col border-t border-divider py-1">
                        {desktopMenuItems.map((menuItem) => {
                          const Icon = menuItem.icon;
                          const isCurrentRoute = menuItem.href === pathname;

                          return (
                            <button
                              key={menuItem.label}
                              type="button"
                              onClick={() => handleMenuItemClick(menuItem)}
                              className={clsx(
                                "flex items-center gap-2 rounded-lg px-3 py-2 text-left text-base transition-colors",
                                isCurrentRoute
                                  ? "bg-accent/12 text-accent"
                                  : "text-foreground-muted hover:bg-accent/10 hover:text-accent",
                              )}
                            >
                              <Icon className="size-4" aria-hidden="true" />
                              {menuItem.label}
                            </button>
                          );
                        })}
                      </div>
                    )}
                    {(desktopSignOutItem || showDirectSignOut) && (
                      <button
                        type="button"
                        onClick={() => {
                          closePopover();
                          setIsSignOutConfirmationOpen(true);
                        }}
                        className="flex items-center gap-2 border-t border-divider px-3 py-3 text-left text-base text-red-500 transition-colors hover:bg-red-500/10"
                      >
                        <LogOut className="size-4" aria-hidden="true" />
                        Cerrar sesión
                      </button>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        <span className={landingStyles.topbarWordmark}>GYMU</span>
        {pageTitle && <span className="truncate text-sm font-medium text-muted">{pageTitle}</span>}
      </div>

      <div className="flex min-w-0 shrink items-center gap-2">
        {showUserName && topBarUserName && (
          <span className="hidden max-w-48 min-w-0 truncate text-sm text-muted sm:block">
            {topBarUserName}
          </span>
        )}

        {accountLabel && <span className="text-sm text-muted">{accountLabel}</span>}

        {topBarRole !== undefined && (
          <button
            type="button"
            onClick={(event) => togglePopover(event, "bookings")}
            aria-expanded={activePopover === "bookings"}
            aria-label="Ver reservas activas"
            className="flex size-10 shrink-0 items-center justify-center rounded-lg text-accent transition-colors hover:bg-accent/10 active:scale-95"
          >
            <CalendarCheck className="size-4" aria-hidden="true" />
          </button>
        )}

        {topBarRole !== undefined && hasStreak && <span className="h-5 w-px shrink-0 bg-divider" />}

        {hasStreak && (
          <div className="relative shrink-0">
            <button
              type="button"
              onClick={(event) => togglePopover(event, "streak")}
              aria-expanded={activePopover === "streak"}
              aria-label="Ver detalle de racha"
              className="flex min-h-10 items-center gap-1 rounded-lg px-2 text-base text-accent transition-colors hover:bg-accent/10 active:scale-95"
            >
              <span className="relative flex size-4 items-center justify-center" aria-hidden="true">
                {isStreakCelebrating && !shouldReduceMotion && (
                  <motion.span
                    className="absolute -inset-2 rounded-full bg-accent/35 blur-md"
                    initial={{ opacity: 0, scale: 0.55 }}
                    animate={{ opacity: [0, 0.8, 0], scale: [0.55, 1.2, 1.65] }}
                    transition={{ duration: 0.72, repeat: 1, repeatDelay: 0.06 }}
                  />
                )}
                <motion.span
                  animate={
                    isStreakCelebrating && !shouldReduceMotion
                      ? { scale: [1, 1.22, 1], y: [0, -1, 0] }
                      : { scale: 1, y: 0 }
                  }
                  transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                >
                  <Flame className="size-4" />
                </motion.span>
              </span>
              <span className="tabular-nums">{topBarStreakWeeks}</span>
              {isStreakCelebrating && (
                <span className="sr-only" aria-live="polite">
                  Nueva semana de racha conseguida
                </span>
              )}
            </button>

            {activePopover === "streak" && (
              <div
                className={clsx(
                  "absolute top-full right-0 z-50 mt-2 flex min-w-52 items-center gap-2 rounded-xl",
                  "border border-accent/20 bg-surface px-3 py-2 shadow-xl",
                  "animate-in fade-in slide-in-from-top-1 duration-200",
                )}
              >
                <Flame className="size-4 shrink-0 text-accent" aria-hidden="true" />
                <span className="text-sm text-foreground-muted">
                  Llevas{" "}
                  <span className="font-semibold text-accent tabular-nums">
                    {topBarStreakWeeks}
                  </span>{" "}
                  {streakLabel}
                </span>
              </div>
            )}
          </div>
        )}

        {onThemePreferenceChange && (
          <ThemeToggle
            onThemePreferenceChange={onThemePreferenceChange}
            transitionStyle={themeTransitionStyle}
          />
        )}

        {showDirectSignOut && (
          <button
            type="button"
            onClick={() => setIsSignOutConfirmationOpen(true)}
            aria-label="Cerrar sesión"
            className="flex size-10 shrink-0 items-center justify-center rounded-lg text-dim transition-colors hover:bg-red-500/10 hover:text-red-500 focus-visible:ring-2 focus-visible:ring-red-500 focus-visible:outline-none active:scale-95 lg:hidden"
          >
            <LogOut className="size-4" aria-hidden="true" />
          </button>
        )}
      </div>

      {activePopover === "bookings" && (
        <ActiveBookingsPanel
          bookings={activeBookings}
          onClose={closePopover}
          onConfirm={confirmActiveBooking}
          onCancel={cancelActiveBooking}
        />
      )}

      {isSignOutConfirmationOpen && (
        <SignOutConfirmationDialog
          onCancel={() => setIsSignOutConfirmationOpen(false)}
          onConfirm={confirmSignOut}
        />
      )}
    </div>
  );
}
