"use client";

import { useRef, useState } from "react";
import clsx from "clsx";
import type { WeeklyOccupancy } from "@/lib/statistics";

type Props = {
  occupancy: WeeklyOccupancy[];
};

type ChartDay = {
  label: string;
  value: number;
};

const DAY_LABELS = ["Lun", "Mar", "Mié", "Jue", "Vie"] as const;

function getOccupancyPercent(day: WeeklyOccupancy) {
  if (day.capacity === 0) return 0;
  return Math.min(100, Math.round((day.occupied / day.capacity) * 100));
}

function createChartData(occupancy: WeeklyOccupancy[]): ChartDay[] {
  return occupancy.map((day, index) => ({
    label: DAY_LABELS[index] ?? "",
    value: getOccupancyPercent(day),
  }));
}

export function WeeklyOccupancyBars({ occupancy }: Props) {
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);
  const [displayValue, setDisplayValue] = useState<number | null>(null);
  const [isHovering, setIsHovering] = useState(false);
  const clearValueTimeoutRef = useRef<number | null>(null);
  const data = createChartData(occupancy);

  function clearPendingValueTimeout() {
    if (clearValueTimeoutRef.current === null) return;

    window.clearTimeout(clearValueTimeoutRef.current);
    clearValueTimeoutRef.current = null;
  }

  function handleActiveIndex(index: number) {
    clearPendingValueTimeout();
    setHoveredIndex(index);
    setDisplayValue(data[index]?.value ?? null);
  }

  function handleContainerEnter() {
    clearPendingValueTimeout();
    setIsHovering(true);
  }

  function handleContainerLeave() {
    setIsHovering(false);
    setHoveredIndex(null);
    clearValueTimeoutRef.current = window.setTimeout(() => {
      setDisplayValue(null);
      clearValueTimeoutRef.current = null;
    }, 150);
  }

  function handleBarClick(index: number) {
    if (hoveredIndex === index) {
      handleContainerLeave();
    } else {
      handleContainerEnter();
      handleActiveIndex(index);
    }
  }

  return (
    <section
      onPointerEnter={(event) => {
        if (event.pointerType === "mouse") handleContainerEnter();
      }}
      onPointerLeave={(event) => {
        if (event.pointerType === "mouse") handleContainerLeave();
      }}
      className="group relative mx-auto flex w-full max-w-72 flex-col gap-4 rounded-2xl border border-foreground/[0.06] bg-foreground/[0.02] p-6 backdrop-blur-sm transition-[background-color,border-color] duration-500 hover:border-foreground/[0.1] hover:bg-foreground/[0.04]"
    >
      <div className="relative z-10 mb-6 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="size-2 animate-pulse rounded-full bg-emerald-500" aria-hidden="true" />
          <span className="text-xs font-medium tracking-wide text-muted uppercase">Ocupación</span>
        </div>
        <div className="relative flex h-7 items-center">
          <span
            className={clsx(
              "text-lg font-semibold tabular-nums transition-all duration-300 ease-out",
              isHovering && displayValue !== null
                ? "text-foreground opacity-100"
                : "text-muted opacity-50",
            )}
          >
            {displayValue ?? ""}
            <span
              className={clsx(
                "ml-0.5 text-xs font-normal text-muted transition-opacity duration-300",
                displayValue !== null ? "opacity-100" : "opacity-0",
              )}
            >
              %
            </span>
          </span>
        </div>
      </div>

      <div className="relative z-10 flex h-28 items-end gap-2">
        {data.map((item, index) => {
          const heightPx = (item.value / 100) * 112;
          const isHovered = hoveredIndex === index;
          const isAnyHovered = hoveredIndex !== null;
          const isNeighbor =
            hoveredIndex !== null && (index === hoveredIndex - 1 || index === hoveredIndex + 1);

          return (
            <button
              key={item.label}
              type="button"
              aria-label={`${item.label}: ${item.value}% de ocupación`}
              aria-pressed={isHovered}
              onFocus={() => handleActiveIndex(index)}
              onBlur={handleContainerLeave}
              onPointerEnter={(event) => {
                if (event.pointerType === "mouse") handleActiveIndex(index);
              }}
              onClick={() => handleBarClick(index)}
              className="relative flex h-full min-w-0 flex-1 cursor-pointer flex-col items-center justify-end rounded-sm outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-surface"
            >
              <span
                className={clsx(
                  "w-full origin-bottom cursor-pointer rounded-full transition-all duration-300 ease-out",
                  isHovered
                    ? "bg-foreground"
                    : isNeighbor
                      ? "bg-foreground/30"
                      : isAnyHovered
                        ? "bg-foreground/10"
                        : "bg-foreground/20 group-hover:bg-foreground/25",
                  isHovered
                    ? "scale-x-[1.15] scale-y-[1.02]"
                    : isNeighbor
                      ? "scale-x-[1.05]"
                      : "scale-100",
                )}
                style={{ height: `${heightPx}px` }}
              />

              <span
                className={clsx(
                  "mt-2 text-[10px] font-medium transition-colors duration-300",
                  isHovered ? "text-foreground" : "text-muted/60",
                )}
                aria-hidden="true"
              >
                {item.label.charAt(0)}
              </span>

              <span
                className={clsx(
                  "pointer-events-none absolute -top-8 left-1/2 -translate-x-1/2 rounded-md bg-foreground px-2 py-1 text-xs font-medium whitespace-nowrap text-bg transition-all duration-200",
                  isHovered
                    ? "translate-y-0 opacity-100"
                    : "pointer-events-none translate-y-1 opacity-0",
                )}
                aria-hidden="true"
              >
                {item.value}%
              </span>
            </button>
          );
        })}
      </div>

      <div className="pointer-events-none absolute inset-0 rounded-2xl bg-gradient-to-b from-foreground/[0.02] to-transparent opacity-0 transition-opacity duration-500 group-hover:opacity-100" />
    </section>
  );
}
