"use client";

import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { CalendarDays, ChevronLeft, ChevronRight, Menu, QrCode, UserRound } from "lucide-react";
import { motion, useMotionValueEvent, useScroll, useTransform } from "motion/react";
import { BookingCard } from "@/components/BookingCard";
import styles from "./LandingDeviceShowcase.module.css";

const DEMO_BLOCKS = [
  { start: "08:50", end: "09:40", initial: 3, final: 15, delay: 0 },
  { start: "09:40", end: "11:05", initial: 5, final: 13, delay: 0.12 },
  { start: "11:05", end: "12:15", initial: 2, final: 15, delay: 0.22 },
  { start: "12:15", end: "13:40", initial: 4, final: 11, delay: 0.08 },
  { start: "14:40", end: "15:50", initial: 1, final: 9, delay: 0.3 },
];
const DEMO_DAYS = ["L", "M", "M", "J", "V"];

function ReservationPreview({ progress }: { progress: number }) {
  const screenRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.6);
  useEffect(function fitScreen() {
    const screen = screenRef.current;
    if (!screen) return;
    const observer = new ResizeObserver(([entry]) => {
      if (entry) setScale(entry.contentRect.width / 390);
    });
    observer.observe(screen);
    return () => observer.disconnect();
  }, []);
  return (
    <div className={styles.phone} aria-hidden="true" inert>
      <div ref={screenRef} className={styles.screen}>
        <div className={styles.interface} style={{ transform: `scale(${scale})` }}>
          <div className={styles.status}>
            <span>9:41</span>
            <span>••• ▰</span>
          </div>
          <div className={styles.topbar}>
            <strong>GYMU</strong>
            <Menu size={22} />
          </div>
          <div className={styles.week}>
            <ChevronLeft size={16} />
            <span>Esta semana</span>
            <ChevronRight size={16} />
          </div>
          <div className={styles.days}>
            {DEMO_DAYS.map((day, index) => (
              <div key={index} data-selected={index === 1 || undefined}>
                <span>{day}</span>
                <strong>{19 + index}</strong>
              </div>
            ))}
          </div>
          <div className={styles.blocks}>
            {DEMO_BLOCKS.map(function renderBlock(block) {
              const localProgress = Math.max(0, Math.min(1, (progress - block.delay) / 0.65));
              const taken =
                block.initial + Math.round((block.final - block.initial) * localProgress);
              return (
                <BookingCard
                  key={block.start}
                  title={block.start}
                  titleDetail={block.end}
                  taken={taken}
                  totalSpots={15}
                  actionState={taken === 15 ? "full" : "available"}
                  detail={taken === 15 ? "Bloque lleno" : ""}
                />
              );
            })}
          </div>
          <div className={styles.navigation}>
            <span>
              <CalendarDays size={23} />
              Reserva
            </span>
            <span>
              <QrCode size={23} />
              QR
            </span>
            <span>
              <UserRound size={23} />
              Perfil
            </span>
          </div>
        </div>
        <div className={styles.camera} />
      </div>
    </div>
  );
}
function ShowcaseTitle() {
  return (
    <h2 id="device-showcase-title" className={styles.title}>
      La sala de musculación<span>en tu bolsillo</span>
    </h2>
  );
}
function AnimatedShowcase() {
  const sectionRef = useRef<HTMLElement>(null);
  const [step, setStep] = useState(0);
  const { scrollYProgress } = useScroll({ target: sectionRef, offset: ["start start", "end end"] });
  const phoneTransform = useTransform(
    scrollYProgress,
    [0, 0.65, 1],
    [
      "translateY(0%) rotateX(22deg) scale(0.94)",
      "translateY(-8%) rotateX(0deg) scale(1)",
      "translateY(-8%) rotateX(0deg) scale(1)",
    ],
  );
  const titleTransform = useTransform(
    scrollYProgress,
    [0, 1],
    ["translateY(0px)", "translateY(-24px)"],
  );
  useMotionValueEvent(scrollYProgress, "change", function updateDemo(value) {
    setStep(Math.round(Math.max(0, Math.min(1, (value - 0.1) / 0.8)) * 100));
  });
  return (
    <section ref={sectionRef} className={styles.showcase} aria-labelledby="device-showcase-title">
      <div className={styles.stage}>
        <motion.div className={styles.heading} style={{ transform: titleTransform }}>
          <ShowcaseTitle />
        </motion.div>
        <motion.div className={styles.device} style={{ transform: phoneTransform }}>
          <ReservationPreview progress={step / 100} />
        </motion.div>
        <p className="sr-only">
          La pantalla de reserva muestra bloques horarios cuya ocupación simulada aumenta con el
          desplazamiento. No representa disponibilidad real ni permite reservar.
        </p>
      </div>
    </section>
  );
}
function subscribeReducedMotion(onChange: () => void) {
  const preference = window.matchMedia("(prefers-reduced-motion: reduce)");
  preference.addEventListener("change", onChange);
  return () => preference.removeEventListener("change", onChange);
}
function getReducedMotion() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}
function getServerReducedMotion() {
  return false;
}
export function LandingDeviceShowcase() {
  const reducedMotion = useSyncExternalStore(
    subscribeReducedMotion,
    getReducedMotion,
    getServerReducedMotion,
  );
  if (reducedMotion) {
    return (
      <section className={styles.still} aria-labelledby="device-showcase-title">
        <ShowcaseTitle />
        <ReservationPreview progress={1} />
        <p className={styles.caption}>Vista de demostración · Ocupación simulada</p>
        <p className="sr-only">
          Ejemplo de la pantalla de reserva con bloques disponibles y completos. No permite
          reservar.
        </p>
      </section>
    );
  }
  return <AnimatedShowcase />;
}
