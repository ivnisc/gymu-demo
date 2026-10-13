"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2 } from "lucide-react";
import { CREATE_SUPABASE_BROWSER_CLIENT } from "@gusm/database/client";

export default function TermsPage() {
  const [acceptanceError, setAcceptanceError] = useState(false);
  const [isAccepting, setIsAccepting] = useState(false);
  const [isAccepted, setIsAccepted] = useState<boolean | null>(null);
  const router = useRouter();

  useEffect(() => {
    let isMounted = true;

    async function loadAcceptanceState() {
      const supabase = CREATE_SUPABASE_BROWSER_CLIENT();
      const { data, error } = await supabase.rpc("has_accepted_regulation");

      if (!isMounted || error) return;

      setIsAccepted(data);
    }

    void loadAcceptanceState();
    return () => {
      isMounted = false;
    };
  }, []);

  async function acceptRegulation() {
    if (isAccepted) {
      router.replace("/reserva");
      return;
    }

    setAcceptanceError(false);
    setIsAccepting(true);

    try {
      const response = await fetch("/api/terms/accept", {
        method: "POST",
        cache: "no-store",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ acceptRegulation: true }),
      });

      if (response.status !== 204) {
        setAcceptanceError(true);
        setIsAccepting(false);
        return;
      }

      setIsAccepted(true);
      router.replace("/reserva");
    } catch {
      setAcceptanceError(true);
      setIsAccepting(false);
    }
  }

  return (
    <div className="flex min-h-svh w-full justify-center bg-bg">
      <main className="flex h-svh gusm-app-shell flex-col gap-8 overflow-y-auto px-4 pt-[max(2rem,calc(env(safe-area-inset-top)+1rem))] pb-[max(2rem,calc(env(safe-area-inset-bottom)+1rem))] sm:px-6 sm:py-12">
        <header className="flex flex-col gap-3">
          <p className="text-sm tracking-[0.16em] text-accent uppercase">GYMU · reglamento</p>
          <h1 className="text-2xl font-semibold text-foreground">Reglamento de uso</h1>
          <p className="text-base leading-6 text-muted">Sala de Musculación UTFSM Concepción</p>
        </header>

        <article className="flex flex-col gap-5 rounded-2xl border border-accent/15 px-5 py-5 text-sm leading-6 text-muted">
          <p className="text-justify">
            Este texto es una versión transitoria para la revisión de interfaz. El reglamento
            oficial de uso de la Sala de Musculación será provisto y aprobado por DEFIDER.
          </p>

          <section>
            <h2 className="text-base font-semibold text-foreground">Uso de la sala</h2>
            <p className="text-justify">
              La reserva de un bloque implica respetar los horarios, las instrucciones del equipo de
              sala y el uso responsable de los cupos. La confirmación y el registro de asistencia
              ayudan a que otras personas puedan usar la Sala de Musculación.
            </p>
          </section>

          <section>
            <h2 className="text-base font-semibold text-foreground">Reservas y asistencia</h2>
            <p className="text-justify">
              Una reserva debe usarse con responsabilidad. Si no puedes asistir, debes cancelarla
              dentro de la ventana permitida. La aplicación puede registrar advertencias operativas
              cuando una reserva confirmada no se utiliza o cuando no se completa el flujo
              requerido.
            </p>
          </section>

          <section>
            <h2 className="text-base font-semibold text-foreground">Indicaciones del equipo</h2>
            <p className="text-justify">
              El equipo de sala puede organizar el acceso presencial, autorizar excepciones
              operativas y orientar el uso de los implementos. Estas decisiones buscan resguardar el
              funcionamiento de la Sala de Musculación durante cada bloque.
            </p>
          </section>

          <section>
            <h2 className="text-base font-semibold text-foreground">Vigencia</h2>
            <p className="text-justify">
              Podrás consultar este reglamento desde tu perfil antes de realizar una reserva.
            </p>
          </section>

          <section>
            <h2 className="text-base font-semibold text-foreground">Aceptación</h2>
            <p className="text-justify">
              Al seleccionar “He leído y acepto”, declaras haber revisado este reglamento de uso. La
              aceptación registra la fecha y hora.
            </p>
          </section>
        </article>

        {acceptanceError && (
          <p role="alert" className="text-sm text-rose-500">
            No fue posible registrar tu aceptación. Intenta nuevamente.
          </p>
        )}

        <button
          type="button"
          disabled={isAccepting || isAccepted !== false}
          onClick={acceptRegulation}
          className="flex gusm-button-primary items-center justify-center gap-2 disabled:cursor-not-allowed"
        >
          {isAccepted === null ? (
            <>
              <Loader2 size={18} className="animate-spin" />
              Verificando…
            </>
          ) : isAccepting ? (
            <>
              <Loader2 size={18} className="animate-spin" />
              Registrando…
            </>
          ) : isAccepted ? (
            "Reglamento ya aceptado"
          ) : (
            "He leído y acepto el reglamento"
          )}
        </button>
      </main>
    </div>
  );
}
