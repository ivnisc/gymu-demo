"use client";

import { useRef } from "react";
import { motion, useInView, useReducedMotion } from "motion/react";
import styles from "@/app/landing.module.css";

const STREAK_PATH = "M70 45 C330 -15 345 140 200 155 S35 330 330 265";
const JOURNEY_DURATION = 6;
const STREAK_STOPS = [
  { label: "1 semana", arrival: 0 },
  { label: "otra más", arrival: 0.486 },
  { label: "sigue y conseguirás premios!", arrival: 1 },
];

export function LandingStreakPath() {
  const artworkRef = useRef<HTMLDivElement>(null);
  const isVisible = useInView(artworkRef, { once: true, amount: 0.1 });
  const reducedMotion = useReducedMotion();
  const showJourney = isVisible || reducedMotion;

  return (
    <div ref={artworkRef} className={styles.weekArtwork} data-started={showJourney || undefined}>
      <svg className={styles.weekTrail} viewBox="0 0 400 310" fill="none" aria-hidden="true">
        <path d={STREAK_PATH} className={styles.weekTrack} />
        <path
          d={STREAK_PATH}
          className={styles.weekProgress}
          pathLength={1}
          strokeDasharray="1 1"
          strokeDashoffset={1}
        />
      </svg>
      <ol className={styles.weekNodes} aria-label="Tu camino de constancia">
        {STREAK_STOPS.map(function renderStop(stop) {
          return (
            <li key={stop.label}>
              <motion.span
                className={styles.weekNode}
                aria-hidden="true"
                initial={{ opacity: 0.25 }}
                animate={{ opacity: showJourney ? 1 : 0.25 }}
                transition={{
                  duration: reducedMotion ? 0 : 0.2,
                  delay: showJourney && !reducedMotion ? stop.arrival * JOURNEY_DURATION : 0,
                  ease: "linear",
                }}
              />
              <span>{stop.label}</span>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
