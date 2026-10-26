export type ThemePreference = "dark" | "light";

export const THEME_PREFERENCE_STORAGE_KEY = "gymu.theme";
const THEME_SWITCHING_ATTRIBUTE = "data-theme-switching";

export function getDocumentThemePreference(): ThemePreference {
  return document.documentElement.dataset.theme === "light" ? "light" : "dark";
}

export function applyThemePreference(themePreference: ThemePreference) {
  const root = document.documentElement;
  const themeColor = document.querySelector<HTMLMetaElement>('meta[name="theme-color"]');

  root.setAttribute(THEME_SWITCHING_ATTRIBUTE, "");
  root.dataset.theme = themePreference;
  themeColor?.setAttribute("content", themePreference === "light" ? "#ffffff" : "#0a0a0a");

  try {
    window.localStorage.setItem(THEME_PREFERENCE_STORAGE_KEY, themePreference);
  } catch {
    // El tema visual sigue funcionando aunque el navegador bloquee almacenamiento local.
  }

  window.requestAnimationFrame(function clearThemeSwitchingState() {
    window.requestAnimationFrame(function removeThemeSwitchingState() {
      root.removeAttribute(THEME_SWITCHING_ATTRIBUTE);
    });
  });
}

export async function transitionThemePreference(
  themePreference: ThemePreference,
  onThemeApplied: () => void,
) {
  function applyTheme() {
    applyThemePreference(themePreference);
    onThemeApplied();
  }

  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    applyTheme();
    return;
  }

  if (!document.startViewTransition) {
    applyTheme();
    document.documentElement.animate([{ opacity: 0.6 }, { opacity: 1 }], {
      duration: 300,
      easing: "ease",
    });
    return;
  }

  const root = document.documentElement;
  root.classList.add("gymu-theme-transition");

  try {
    const transition = document.startViewTransition(applyTheme);
    await transition.finished;
  } catch {
    applyTheme();
  } finally {
    root.classList.remove("gymu-theme-transition");
  }
}

export async function fadeThemePreference(
  themePreference: ThemePreference,
  onThemeApplied: () => void,
) {
  function applyTheme() {
    applyThemePreference(themePreference);
    onThemeApplied();
  }

  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    applyTheme();
    return;
  }

  if (!document.startViewTransition) {
    applyTheme();
    document.documentElement.animate([{ opacity: 0.76 }, { opacity: 1 }], {
      duration: 220,
      easing: "cubic-bezier(0.2, 0, 0, 1)",
    });
    return;
  }

  const root = document.documentElement;
  root.classList.add("gymu-profile-theme-transition");

  try {
    const transition = document.startViewTransition(applyTheme);
    await transition.finished;
  } catch {
    applyTheme();
  } finally {
    root.classList.remove("gymu-profile-theme-transition");
  }
}
