"use client";

import { useLayoutEffect, useRef, useState } from "react";
import { Moon, Sun } from "lucide-react";
import { clsx } from "clsx";
import {
  fadeThemePreference,
  getDocumentThemePreference,
  transitionThemePreference,
  type ThemePreference,
} from "@/lib/theme";

type Props = Omit<React.ComponentProps<"button">, "aria-label" | "onClick" | "type"> & {
  onThemePreferenceChange?: (themePreference: ThemePreference) => Promise<boolean>;
  onThemePreferenceSelect?: (themePreference: ThemePreference) => void;
  transitionStyle?: "diagonal" | "fade";
};

export function ThemeToggle({
  className,
  disabled,
  onThemePreferenceChange,
  onThemePreferenceSelect,
  transitionStyle = "diagonal",
  ...props
}: Props) {
  const [theme, setTheme] = useState<ThemePreference>("dark");
  const [isUpdating, setIsUpdating] = useState(false);
  const isTransitioningRef = useRef(false);

  useLayoutEffect(function synchronizeTheme() {
    setTheme(getDocumentThemePreference());
  }, []);

  async function toggleTheme() {
    if (disabled || isUpdating || isTransitioningRef.current) return;

    const previousTheme = theme;
    const nextTheme: ThemePreference = theme === "dark" ? "light" : "dark";

    isTransitioningRef.current = true;
    setIsUpdating(true);

    try {
      const transitionTheme =
        transitionStyle === "fade" ? fadeThemePreference : transitionThemePreference;

      await transitionTheme(nextTheme, () => {
        setTheme(nextTheme);
        onThemePreferenceSelect?.(nextTheme);
      });

      if (onThemePreferenceChange) {
        let didPersist = false;

        try {
          didPersist = await onThemePreferenceChange(nextTheme);
        } catch {
          didPersist = false;
        }

        if (!didPersist) {
          await transitionTheme(previousTheme, () => {
            setTheme(previousTheme);
            onThemePreferenceSelect?.(previousTheme);
          });
        }
      }
    } finally {
      isTransitioningRef.current = false;
      setIsUpdating(false);
    }
  }

  const isDarkTheme = theme === "dark";
  const Icon = isDarkTheme ? Sun : Moon;

  return (
    <button
      {...props}
      type="button"
      onClick={() => void toggleTheme()}
      disabled={disabled || isUpdating}
      aria-label={isDarkTheme ? "Cambiar a modo claro" : "Cambiar a modo oscuro"}
      title={isDarkTheme ? "Modo claro" : "Modo oscuro"}
      className={clsx(
        "flex size-8 shrink-0 items-center justify-center rounded-full border border-accent/30",
        "bg-accent/10 text-accent transition-all active:scale-95 disabled:cursor-not-allowed disabled:opacity-40",
        className,
      )}
    >
      <Icon className="size-4" aria-hidden="true" />
    </button>
  );
}
