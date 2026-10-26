"use client";

import { toast } from "sonner";

type ToastZone = "top" | "bottom";

type SonnerPosition =
  | "top-left"
  | "top-center"
  | "top-right"
  | "bottom-left"
  | "bottom-center"
  | "bottom-right";

type ToastNotification = {
  description?: string;
  zone?: ToastZone;
};

const DESKTOP_TOAST_MEDIA_QUERY = "(min-width: 48rem)";

function getToastPosition(zone: ToastZone): SonnerPosition {
  const isDesktop =
    typeof window !== "undefined" && window.matchMedia(DESKTOP_TOAST_MEDIA_QUERY).matches;

  if (isDesktop) return zone === "top" ? "top-right" : "bottom-right";
  return zone === "top" ? "top-center" : "bottom-center";
}

function getToastOptions({ description, zone = "bottom" }: ToastNotification) {
  return { description, position: getToastPosition(zone) };
}

export function notifySuccess(title: string, notification: ToastNotification = {}) {
  return toast.success(title, getToastOptions(notification));
}

export function notifyError(title: string, notification: ToastNotification = {}) {
  return toast.error(title, getToastOptions(notification));
}

export function notifyWarning(title: string, notification: ToastNotification = {}) {
  return toast.warning(title, getToastOptions(notification));
}

export function notifyInfo(title: string, notification: ToastNotification = {}) {
  return toast.info(title, getToastOptions(notification));
}

export function notifyLoading(title: string, notification: ToastNotification = {}) {
  return toast.loading(title, getToastOptions(notification));
}
