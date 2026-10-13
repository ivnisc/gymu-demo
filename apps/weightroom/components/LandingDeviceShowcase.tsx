"use client";

import { useRef } from "react";
import Image from "next/image";
import { motion, useReducedMotion, useScroll, useTransform } from "motion/react";
import type { LandingDeviceRenders } from "@/lib/landing-device-renders";
import styles from "./LandingDeviceShowcase.module.css";

type Props = { renders: LandingDeviceRenders };

export function LandingDeviceShowcase({ renders }: Props) {
  const sectionRef = useRef<HTMLElement>(null);
  const reducedMotion = useReducedMotion();
  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ["start start", "end end"],
  });
  const topOpacity = useTransform(scrollYProgress, [0, 0.45, 0.55, 1], [1, 1, 0, 0]);
  const reservationOpacity = useTransform(scrollYProgress, [0, 0.45, 0.55, 1], [0, 0, 1, 1]);
  const transform = useTransform(
    scrollYProgress,
    [0, 0.5, 1],
    [
      "translateY(16px) rotate(-4deg)",
      "translateY(0px) rotate(0deg)",
      "translateY(-16px) rotate(4deg)",
    ],
  );

  return (
    <section ref={sectionRef} className={styles.showcase} aria-label="Explora GYMU">
      <div className={styles.stage}>
        <motion.div className={styles.frame} style={reducedMotion ? undefined : { transform }}>
          <motion.figure
            className={styles.first}
            style={reducedMotion ? undefined : { opacity: topOpacity }}
          >
            <Image
              src={renders.topGlobals}
              width={renders.width}
              height={renders.height}
              alt="GYMU: vista de tops globales en iPhone"
              sizes="(min-width: 1024px) 480px, 80vw"
            />
            <figcaption>Tops globales</figcaption>
          </motion.figure>
          <motion.figure
            className={styles.second}
            style={reducedMotion ? undefined : { opacity: reservationOpacity }}
          >
            <Image
              src={renders.reservation}
              width={renders.width}
              height={renders.height}
              alt="GYMU: vista de reserva en iPhone"
              sizes="(min-width: 1024px) 480px, 80vw"
            />
            <figcaption>Tu próxima reserva</figcaption>
          </motion.figure>
        </motion.div>
      </div>
    </section>
  );
}
