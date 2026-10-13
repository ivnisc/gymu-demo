"use client";

import { useLayoutEffect, useRef, useState } from "react";
import { Moon, Sun } from "lucide-react";
import {
  getDocumentThemePreference,
  transitionThemePreference,
  type ThemePreference,
} from "@/lib/theme";
import styles from "@/app/landing.module.css";

export function LandingThemeToggle() {
  const [theme, setTheme] = useState<ThemePreference>("dark");
  const transitioning = useRef(false);

  useLayoutEffect(function synchronizeTheme() {
    setTheme(getDocumentThemePreference());
  }, []);

  async function toggleTheme() {
    if (transitioning.current) return;

    const nextTheme = getDocumentThemePreference() === "dark" ? "light" : "dark";
    function updateTheme() {
      setTheme(nextTheme);
    }

    transitioning.current = true;
    try {
      await transitionThemePreference(nextTheme, updateTheme);
    } finally {
      transitioning.current = false;
    }
  }

  const label = theme === "dark" ? "Cambiar a modo claro" : "Cambiar a modo oscuro";
  const Icon = theme === "dark" ? Sun : Moon;

  return (
    <button
      type="button"
      onClick={() => void toggleTheme()}
      className={styles.iconLink}
      aria-label={label}
      title={label}
    >
      <Icon size={22} strokeWidth={1.6} aria-hidden="true" />
    </button>
  );
}
