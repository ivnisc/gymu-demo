import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import { clsx } from "clsx";
import { LandingStreakPath } from "@/components/LandingStreakPath";
import { LandingThemeToggle } from "@/components/LandingThemeToggle";
import { GITHUB_VIMASTO_ORG_URL } from "@/constants";
import { LandingSection } from "@/components/LandingSection";
import { LandingDeviceShowcase } from "@/components/LandingDeviceShowcase";
import styles from "./landing.module.css";

export const metadata: Metadata = {
  title: "GYMU · Hazte espacio",
  description:
    "Reserva tu bloque en la Sala de Musculación UTFSM Concepción. Hazte espacio para entrenar con GYMU.",
};

export default function RootPage() {
  return (
    <div className="flex min-h-svh w-full justify-center bg-bg">
      <div className={clsx("gusm-app-shell", styles.landing)}>
        <header className="flex h-24 items-center justify-between gap-6">
          <span className={styles.wordmark}>GYMU</span>
          <div className="flex items-center gap-2">
            <LandingThemeToggle />
          </div>
        </header>
        <main>
          <section className={styles.hero} aria-labelledby="landing-title">
            <div className={styles.heroCopy}>
              <h1 id="landing-title" className={styles.headline}>
                Hazte
                <br />
                <span>espacio</span>
              </h1>
              <p className="mt-6 max-w-80 text-base leading-7 text-muted">
                Reserva tu bloque en la Sala de Musculación UTFSM Concepción.
              </p>
              <Link
                href="/login"
                prefetch={false}
                className={clsx(styles.link, styles.cta, "mt-7 text-accent-foreground")}
              >
                Ingresar <ArrowUpRight size={25} strokeWidth={1.8} aria-hidden="true" />
              </Link>
            </div>
            <div className={styles.sculpture} aria-hidden="true">
              <div className={styles.orbit} />
              <Image
                src="/landing/weight-sculpture-v2.webp"
                width={1200}
                height={1200}
                alt=""
                sizes="(min-width: 1024px) 620px, (min-width: 520px) 480px, calc(100vw - 40px)"
                loading="eager"
                fetchPriority="high"
                className={styles.sculptureImage}
              />
            </div>
          </section>
          <LandingDeviceShowcase />
          <LandingSection
            className={clsx(styles.sequence, styles.reveal)}
            aria-label="Cómo funciona GYMU"
          >
            <p className="mb-9 max-w-64 text-sm leading-6 text-muted">Ahora solo bastan 3 pasos</p>
            <ol className={styles.steps}>
              <li className={styles.step}>
                <h2>
                  Reserva<span aria-hidden="true">.</span>
                </h2>
                <p>Elige el día y el bloque, desde tu dispositivo</p>
              </li>
              <li className={styles.step}>
                <h2>
                  Confirma<span aria-hidden="true">.</span>
                </h2>
                <p>Entra a confirmar asistencia durante la ventana habilitada para ello</p>
              </li>
              <li className={styles.step}>
                <h2>
                  Entrena<span aria-hidden="true">.</span>
                </h2>
                <p>Muestra el QR en el marcador y listo!</p>
              </li>
            </ol>
          </LandingSection>
          <LandingSection
            className={clsx(styles.streak, styles.reveal)}
            aria-labelledby="streak-title"
          >
            <div className={styles.streakCopy}>
              <h2 id="streak-title">
                Tu constancia
                <br />
                <span className="text-accent">cuenta</span>
              </h2>
              <p className="mt-6 max-w-80 text-base leading-7 text-muted">
                Una asistencia por semana hará crecer tu racha. La constancia es la clave
              </p>
            </div>
            <LandingStreakPath />
          </LandingSection>
        </main>
        <footer className={styles.footer}>
          <div>
            <span className={styles.footerBrand} aria-hidden="true">
              GYMU
            </span>
            <p className="mt-4 text-sm leading-6 text-muted">
              Sala de Musculación
              <br />
              UTFSM Concepción
            </p>
          </div>
          <a href={GITHUB_VIMASTO_ORG_URL} className={clsx(styles.link, "text-base text-muted")}>
            GitHub <ArrowUpRight size={18} aria-hidden="true" />
          </a>
        </footer>
      </div>
    </div>
  );
}
