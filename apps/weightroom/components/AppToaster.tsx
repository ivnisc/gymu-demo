"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { AlertCircle, AlertTriangle, CheckCircle2, Info, LoaderCircle } from "lucide-react";
import { toast, Toaster } from "sonner";

type AppTheme = "dark" | "light";

function getAppTheme(): AppTheme {
  return document.documentElement.dataset.theme === "light" ? "light" : "dark";
}

export function AppToaster() {
  const pathname = usePathname();
  const [theme, setTheme] = useState<AppTheme>("dark");

  useEffect(() => {
    setTheme(getAppTheme());

    const observer = new MutationObserver(() => {
      setTheme(getAppTheme());
    });
    observer.observe(document.documentElement, {
      attributeFilter: ["data-theme"],
      attributes: true,
    });

    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    toast.dismiss();
  }, [pathname]);

  return (
    <Toaster
      closeButton
      expand={false}
      gap={12}
      mobileOffset={{
        bottom: "calc(env(safe-area-inset-bottom) + 5.5rem)",
        left: "1rem",
        right: "1rem",
        top: "calc(env(safe-area-inset-top) + 4.5rem)",
      }}
      offset={{
        bottom: "1.5rem",
        right: "1.5rem",
        top: "5.5rem",
      }}
      position="bottom-right"
      theme={theme}
      toastOptions={{ duration: 3_000 }}
      icons={{
        error: <AlertCircle className="size-4 text-accent" aria-hidden="true" />,
        info: <Info className="size-4 text-accent" aria-hidden="true" />,
        loading: <LoaderCircle className="size-4 animate-spin text-accent" aria-hidden="true" />,
        success: <CheckCircle2 className="size-4 text-emerald-500" aria-hidden="true" />,
        warning: <AlertTriangle className="size-4 text-accent" aria-hidden="true" />,
      }}
      visibleToasts={3}
    />
  );
}
