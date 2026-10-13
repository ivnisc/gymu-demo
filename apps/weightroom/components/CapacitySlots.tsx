"use client";

import clsx from "clsx";
import { motion, useReducedMotion } from "motion/react";

type CapacitySlotsProps = {
  isDisabled?: boolean;
  occupied: number;
  total: number;
};

function clampOccupiedSlots(occupied: number, total: number): number {
  return Math.max(0, Math.min(occupied, total));
}

function getCapacityFillClass(occupied: number, total: number): string {
  const blueCapacity = Math.round((total * 7) / 15);
  const yellowCapacity = Math.round((total * 11) / 15);

  if (occupied <= blueCapacity) return "bg-capacity-segment-blue";
  if (occupied <= yellowCapacity) return "bg-capacity-segment-yellow";
  return "bg-capacity-segment-red";
}

export function CapacitySlots({ isDisabled = false, occupied, total }: CapacitySlotsProps) {
  const shouldReduceMotion = useReducedMotion();
  const occupiedSlots = clampOccupiedSlots(occupied, total);

  return (
    <div
      className={clsx(
        "relative h-2 min-w-0 flex-1 overflow-hidden rounded-full",
        isDisabled ? "bg-capacity-disabled-track" : "bg-ghost",
      )}
      aria-label={`${occupiedSlots} de ${total} cupos ocupados`}
      role="img"
    >
      <motion.span
        aria-hidden="true"
        className={clsx(
          "absolute inset-y-0 left-0 w-full origin-left rounded-full",
          isDisabled ? "bg-capacity-disabled-fill" : getCapacityFillClass(occupiedSlots, total),
        )}
        initial={false}
        animate={{
          opacity: occupiedSlots === 0 ? 0 : 1,
          transform: `scaleX(${occupiedSlots / total})`,
        }}
        transition={
          shouldReduceMotion ? { duration: 0 } : { duration: 0.28, ease: [0.23, 1, 0.32, 1] }
        }
      />
    </div>
  );
}
