"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useEffect } from "react";
import { BarChart3, CalendarDays, Newspaper, QrCode, User, type LucideIcon } from "lucide-react";
import clsx from "clsx";
import { motion, useReducedMotion } from "motion/react";
import { getCurrentUser } from "@/lib/current-user";
import { CURRENT_USER_QUERY_KEY } from "@/lib/query-keys";

type AppNavigationProps = {
  children: React.ReactNode;
};

type NavigationItem = {
  href: string;
  icon: LucideIcon;
  label: string;
};

const NAVIGATION_EXCLUDED_PATHS = new Set(["/", "/login", "/terminos", "/qr/escanear"]);

const DOCK_FLOATING_ANIMATION = {
  initial: { y: 0 },
  animate: {
    y: [-2, 2, -2],
    transition: {
      duration: 4,
      ease: "easeInOut" as const,
      repeat: Infinity,
    },
  },
};

function getNavigationItems(): NavigationItem[] {
  return [
    { href: "/reserva", icon: CalendarDays, label: "Reserva" },
    { href: "/perfil", icon: User, label: "Perfil" },
    { href: "/qr", icon: QrCode, label: "QR" },
    { href: "/estadisticas", icon: BarChart3, label: "Cifras" },
    { href: "/noticias", icon: Newspaper, label: "Noticias" },
  ];
}

function isNavigationVisible(pathname: string): boolean {
  return !NAVIGATION_EXCLUDED_PATHS.has(pathname);
}

type NavigationLinksProps = {
  items: NavigationItem[];
  pathname: string;
  shouldReduceMotion: boolean | null;
  variant: "ios" | "dock";
};

function NavigationLinks({ items, pathname, shouldReduceMotion, variant }: NavigationLinksProps) {
  const usesCompactLayout = items.length > 4;
  const isDock = variant === "dock";

  return items.map((item) => {
    const Icon = item.icon;
    const isActive = pathname === item.href;

    const navigationLink = (
      <Link
        key={item.href}
        href={item.href}
        aria-current={isActive ? "page" : undefined}
        aria-label={item.label}
        className={clsx(
          "group relative flex shrink-0 items-center justify-center transition-[background-color,color] duration-150 ease-out focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-accent focus-visible:outline-none",
          isDock
            ? "size-11 rounded-lg p-3"
            : clsx(
                "flex-col gap-0.5 rounded-md p-0 text-[length:var(--font-size-bottom-navigation)] font-normal leading-4",
                usesCompactLayout ? "size-12" : "size-13",
              ),
          isActive ? "bg-accent/15 text-accent" : "text-muted hover:bg-input hover:text-foreground",
        )}
      >
        <Icon
          className={isDock || usesCompactLayout ? "size-5 shrink-0" : "size-5.5 shrink-0"}
          aria-hidden="true"
        />
        {isDock ? (
          <span className="pointer-events-none absolute -top-8 left-1/2 hidden -translate-x-1/2 whitespace-nowrap rounded-md bg-surface px-2 py-1 text-xs text-foreground opacity-0 shadow-sm transition-opacity group-hover:opacity-100 md:block">
            {item.label}
          </span>
        ) : (
          <span className="truncate">{item.label}</span>
        )}
      </Link>
    );

    if (!isDock) return navigationLink;

    return (
      <motion.div
        key={item.href}
        whileHover={shouldReduceMotion ? undefined : { scale: 1.1, y: -2 }}
        whileTap={shouldReduceMotion ? undefined : { scale: 0.95 }}
      >
        {navigationLink}
      </motion.div>
    );
  });
}

export function AppNavigation({ children }: AppNavigationProps) {
  const pathname = usePathname();
  const shouldReduceMotion = useReducedMotion();
  const navigationVisible = isNavigationVisible(pathname);
  const wrapperClassName = navigationVisible
    ? "h-svh min-h-0 w-full overflow-hidden"
    : "min-h-svh w-full";

  useEffect(() => {
    const root = document.documentElement;

    if (navigationVisible) {
      root.classList.add("gymu-app-viewport");
    } else {
      root.classList.remove("gymu-app-viewport");
    }

    return () => {
      root.classList.remove("gymu-app-viewport");
    };
  }, [navigationVisible]);

  const currentUserQuery = useQuery({
    queryKey: CURRENT_USER_QUERY_KEY,
    queryFn: getCurrentUser,
    enabled: navigationVisible,
    refetchOnMount: "always",
  });
  const currentUser = currentUserQuery.data;
  const items = currentUser ? getNavigationItems() : [];
  const hasNavigation = navigationVisible && currentUser !== undefined;

  return (
    <div className={clsx(wrapperClassName, hasNavigation && "gymu-navigation-active")}>
      {hasNavigation && (
        <nav
          aria-label="Navegación principal"
          className={clsx(
            "gymu-navigation-ios fixed bottom-[max(env(safe-area-inset-bottom),0.75rem)] left-1/2 z-30 min-h-17 w-fit max-w-[calc(100%-1rem)] -translate-x-1/2 items-center justify-center rounded-s-full rounded-e-full border border-divider/65 bg-transparent py-2 shadow-[0_6px_20px_rgb(0_0_0_/_0.12)] backdrop-blur-[2px] backdrop-saturate-125",
            items.length > 4 ? "gap-1.5 px-3" : "gap-3 px-4",
          )}
        >
          <NavigationLinks
            items={items}
            pathname={pathname}
            shouldReduceMotion={shouldReduceMotion}
            variant="ios"
          />
        </nav>
      )}
      {hasNavigation && (
        <nav
          aria-label="Navegación principal"
          className="gymu-navigation-dock fixed bottom-4 left-1/2 z-30 w-fit max-w-[calc(100%-2rem)] -translate-x-1/2"
        >
          <motion.div
            animate={shouldReduceMotion ? "initial" : "animate"}
            className="flex items-center justify-center gap-1 rounded-2xl border border-divider bg-surface/90 p-2 shadow-[0_6px_20px_rgb(0_0_0_/_0.12)] backdrop-blur-lg backdrop-saturate-125"
            initial="initial"
            variants={DOCK_FLOATING_ANIMATION}
          >
            <NavigationLinks
              items={items}
              pathname={pathname}
              shouldReduceMotion={shouldReduceMotion}
              variant="dock"
            />
          </motion.div>
        </nav>
      )}
      {children}
    </div>
  );
}
