"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  BadgeCheck,
  CalendarCheck,
  CheckCircle2,
  CircleAlert,
  Clock3,
  MoreHorizontal,
  QrCode,
  Search,
  UserPlus,
  Users,
  UsersRound,
  X,
  type LucideIcon,
} from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import clsx from "clsx";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { CREATE_SUPABASE_BROWSER_CLIENT } from "@gusm/database/client";
import { CapacitySlots } from "@/components/CapacitySlots";
import {
  InstitutionalUserSearch,
  type InstitutionalUserSearchResult,
} from "@/components/InstitutionalUserSearch";
import { UserTopBar } from "@/components/UserTopBar";
import { getCurrentUser } from "@/lib/current-user";
import { clearProfileCache } from "@/lib/profile-cache";
import { CURRENT_USER_QUERY_KEY } from "@/lib/query-keys";
import { notifyInfo, notifySuccess, notifyWarning } from "@/lib/toast";

const STANDARD_CAPACITY = 15;
const OVERCAPACITY_LIMIT = 3;

type AdmissionSource = "self_service" | "staff_exception" | "staff_overcapacity";
type ParticipantStatus = "confirmed" | "present" | "requested" | "manual_admission";
type BlockParticipant = InstitutionalUserSearchResult & {
  admissionSource?: AdmissionSource;
  canReauthorizeLateQr?: boolean;
  id: string;
  isLateQrAuthorized?: boolean;
  name: string;
  status: ParticipantStatus;
  username: string;
};

type ParticipantStatusPresentation = {
  icon: LucideIcon;
  label: string;
  surfaceClassName: string;
  textClassName: string;
};

const INITIAL_PARTICIPANTS: BlockParticipant[] = [
  { id: "1", name: "Matías Rojas", status: "present", username: "matias.rojas" },
  {
    admissionSource: "self_service",
    id: "2",
    name: "Constanza Vega",
    status: "confirmed",
    username: "constanza.vega",
  },
  { id: "3", name: "Antonia Pérez", status: "requested", username: "antonia.perez" },
  {
    admissionSource: "self_service",
    canReauthorizeLateQr: true,
    id: "4",
    name: "Diego Fuentes",
    status: "confirmed",
    username: "diego.fuentes",
  },
];

const MOCK_SEARCH_RESULTS: BlockParticipant[] = [
  { id: "5", name: "Gabriel Araya", status: "requested", username: "gabriel.araya" },
  { id: "6", name: "Sofía Morales", status: "requested", username: "sofia.morales" },
  { id: "7", name: "Tomás Vidal", status: "requested", username: "tomas.vidal" },
];

function getParticipantStatusPresentation(
  participant: BlockParticipant,
): ParticipantStatusPresentation {
  if (participant.status === "present") {
    return {
      icon: CheckCircle2,
      label: "Asistencia registrada",
      surfaceClassName: "bg-emerald-400/12 text-emerald-400",
      textClassName: "text-emerald-400",
    };
  }
  if (participant.status === "requested") {
    return {
      icon: CircleAlert,
      label: "Solicitud de ingreso",
      surfaceClassName: "bg-amber-400/12 text-amber-400",
      textClassName: "text-amber-400",
    };
  }
  if (participant.status === "manual_admission") {
    return {
      icon: UserPlus,
      label: "Ingreso presencial",
      surfaceClassName: "bg-accent/12 text-accent",
      textClassName: "text-accent",
    };
  }
  if (participant.isLateQrAuthorized) {
    return {
      icon: QrCode,
      label: "QR disponible por 5 min",
      surfaceClassName: "bg-accent/12 text-accent",
      textClassName: "text-accent",
    };
  }
  if (participant.admissionSource === "staff_exception") {
    return {
      icon: BadgeCheck,
      label: "Ingreso autorizado",
      surfaceClassName: "bg-accent/12 text-accent",
      textClassName: "text-accent",
    };
  }
  if (participant.admissionSource === "staff_overcapacity") {
    return {
      icon: UsersRound,
      label: "Sobrecupo autorizado",
      surfaceClassName: "bg-rose-500/12 text-rose-400",
      textClassName: "text-rose-400",
    };
  }
  return {
    icon: CalendarCheck,
    label: "Reserva confirmada",
    surfaceClassName: "bg-ghost text-muted",
    textClassName: "text-muted",
  };
}

function getCountLabel(count: number, singular: string, plural: string): string {
  return `${count} ${count === 1 ? singular : plural}`;
}

const PROFILE_SECTION_CLASS = "rounded-2xl border border-accent/15 bg-input/30 px-4 py-4";

export default function CurrentBlockPage() {
  const router = useRouter();
  const shouldReduceMotion = useReducedMotion();
  const currentUserQuery = useQuery({
    queryKey: CURRENT_USER_QUERY_KEY,
    queryFn: getCurrentUser,
  });
  const [participants, setParticipants] = useState(INITIAL_PARTICIPANTS);
  const [confirmedCount, setConfirmedCount] = useState(14);
  const [overcapacityCount, setOvercapacityCount] = useState(0);
  const [authorizationCount, setAuthorizationCount] = useState(0);
  const [openParticipantId, setOpenParticipantId] = useState<string | null>(null);
  const [statusDetailsParticipantId, setStatusDetailsParticipantId] = useState<string | null>(null);
  const [newlyAddedParticipantId, setNewlyAddedParticipantId] = useState<string | null>(null);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [query, setQuery] = useState("");
  const statusDetailsTimeoutRef = useRef<number | null>(null);

  const currentUser = currentUserQuery.data;
  const normalizedQuery = query.trim().toLocaleLowerCase("es-CL");
  const searchResults = MOCK_SEARCH_RESULTS.filter((result) => {
    const searchableValue = `${result.name} ${result.username}`.toLocaleLowerCase("es-CL");
    const matchesQuery = !normalizedQuery || searchableValue.includes(normalizedQuery);
    const isAlreadyListed = participants.some((participant) => participant.id === result.id);

    return matchesQuery && !isAlreadyListed;
  });

  useEffect(function clearStatusDetailsTimeoutOnUnmount() {
    return function clearStatusDetailsTimeout() {
      if (statusDetailsTimeoutRef.current !== null) {
        window.clearTimeout(statusDetailsTimeoutRef.current);
      }
    };
  }, []);

  function toggleStatusDetails(participantId: string) {
    if (statusDetailsTimeoutRef.current !== null) {
      window.clearTimeout(statusDetailsTimeoutRef.current);
      statusDetailsTimeoutRef.current = null;
    }

    if (statusDetailsParticipantId === participantId) {
      setStatusDetailsParticipantId(null);
      return;
    }

    setStatusDetailsParticipantId(participantId);
    statusDetailsTimeoutRef.current = window.setTimeout(() => {
      setStatusDetailsParticipantId(null);
      statusDetailsTimeoutRef.current = null;
    }, 3000);
  }

  function handleParticipantAction(participant: BlockParticipant) {
    if (participant.status === "requested" || participant.status === "manual_admission") {
      const isStandardAdmission = confirmedCount < STANDARD_CAPACITY;
      const admissionSource: AdmissionSource = isStandardAdmission
        ? "staff_exception"
        : "staff_overcapacity";

      if (!isStandardAdmission && overcapacityCount >= OVERCAPACITY_LIMIT) {
        notifyWarning("No quedan sobrecupos disponibles", {
          description: "El máximo operativo de sobrecupo ya fue alcanzado para este bloque.",
        });
        return;
      }

      setParticipants((currentParticipants) =>
        currentParticipants.map((currentParticipant) => {
          if (currentParticipant.id !== participant.id) return currentParticipant;
          return {
            ...currentParticipant,
            admissionSource,
            isLateQrAuthorized: true,
            status: "confirmed",
          };
        }),
      );
      if (isStandardAdmission) {
        setConfirmedCount((currentCount) => currentCount + 1);
        setAuthorizationCount((currentCount) => currentCount + 1);
      } else {
        setOvercapacityCount((currentCount) => currentCount + 1);
      }
      notifySuccess(isStandardAdmission ? "Ingreso autorizado" : "Sobrecupo autorizado", {
        description:
          "La persona puede generar y presentar su QR durante los próximos cinco minutos.",
      });
    } else if (participant.status === "confirmed") {
      setParticipants((currentParticipants) =>
        currentParticipants.map((currentParticipant) =>
          currentParticipant.id === participant.id
            ? { ...currentParticipant, isLateQrAuthorized: true }
            : currentParticipant,
        ),
      );
      setAuthorizationCount((currentCount) => currentCount + 1);
      notifyInfo("QR habilitado temporalmente", {
        description:
          "La reserva conserva su procedencia y su cupo. Solo se habilitó el QR por cinco minutos.",
      });
    }

    setOpenParticipantId(null);
  }

  function addSearchResult(result: BlockParticipant) {
    const alreadyListed = participants.some((participant) => participant.id === result.id);
    if (alreadyListed) return;

    const participant = { ...result, status: "manual_admission" as const };
    setParticipants((currentParticipants) => [...currentParticipants, participant]);
    setNewlyAddedParticipantId(participant.id);
    setQuery("");
    setIsSearchOpen(false);
    setOpenParticipantId(participant.id);
    notifyInfo("Persona añadida", {
      description: "Autoriza su ingreso desde la lista de participantes.",
    });
  }

  async function signOut() {
    const supabase = CREATE_SUPABASE_BROWSER_CLIENT();
    const { error } = await supabase.auth.signOut();
    if (error) {
      console.error("[BLOCK] could not sign out.", error);
      return;
    }

    clearProfileCache();
    router.replace("/login");
  }

  return (
    <main className="flex min-h-svh w-full justify-center bg-bg">
      <div className="flex h-svh gusm-app-shell flex-col overflow-hidden bg-surface">
        <header className="z-20 shrink-0 border-b border-divider bg-surface">
          <UserTopBar
            pageTitle="Bloque actual"
            role={currentUser?.role}
            streakWeeks={currentUser?.streakWeeks}
            onGoOvercapacity={() => router.push("/bloque")}
            onGoRoutines={() => router.push("/rutinas")}
            onGoSettings={() => router.push("/configuracion")}
            onSignOut={signOut}
          />
        </header>

        <div className="flex gusm-page-scroll flex-col gap-4 px-4 pt-5 pb-[calc(5.5rem+env(safe-area-inset-bottom))]">
          <section className={PROFILE_SECTION_CLASS} aria-label="Estado del bloque actual">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs font-medium tracking-[0.12em] text-dim uppercase">
                  Bloque actual
                </p>
                <h1 className="mt-1 text-lg font-semibold text-foreground">
                  Bloque 7 · 17:15 · 18:40
                </h1>
              </div>
              <QrCode className="mt-1 size-5 shrink-0 text-accent" aria-hidden="true" />
            </div>

            <div className="mt-4 border-t border-accent/15 pt-4">
              <div className="flex items-end justify-between gap-4">
                <div>
                  <p className="text-xs font-medium tracking-[0.12em] text-dim uppercase">
                    Capacidad
                  </p>
                  <p className="text-base font-semibold text-foreground">
                    {confirmedCount}/{STANDARD_CAPACITY} usuarios confirmados
                  </p>
                  <p className="mt-0.5 text-sm text-muted">
                    {getCountLabel(overcapacityCount, "sobrecupo", "sobrecupos")} y{" "}
                    {getCountLabel(authorizationCount, "autorización", "autorizaciones")}
                  </p>
                </div>
                <Users className="size-5 shrink-0 text-accent" aria-hidden="true" />
              </div>
              <div className="mt-3">
                <CapacitySlots occupied={confirmedCount} total={STANDARD_CAPACITY} />
              </div>
            </div>
          </section>

          <section className={PROFILE_SECTION_CLASS} aria-labelledby="block-participants-title">
            <div className="flex items-end justify-between gap-3 border-b border-accent/15 pb-3">
              <div>
                <p className="text-xs font-medium tracking-[0.12em] text-dim uppercase">
                  Asistencia
                </p>
                <h2
                  id="block-participants-title"
                  className="mt-1 text-lg font-semibold text-foreground"
                >
                  Participantes
                </h2>
              </div>
              <span className="text-sm text-muted tabular-nums">{participants.length}</span>
            </div>
            <div className="divide-y divide-accent/15">
              {participants.map((participant) => {
                const isActionOpen = openParticipantId === participant.id;
                const isStatusDetailsOpen = statusDetailsParticipantId === participant.id;
                const isNewlyAdded = newlyAddedParticipantId === participant.id;
                const isActionable =
                  participant.status === "requested" ||
                  participant.status === "manual_admission" ||
                  (participant.status === "confirmed" && participant.canReauthorizeLateQr);
                const isStandardAdmission = confirmedCount < STANDARD_CAPACITY;
                const actionLabel =
                  participant.status === "requested" || participant.status === "manual_admission"
                    ? isStandardAdmission
                      ? "Autorizar ingreso"
                      : "Autorizar sobrecupo"
                    : "Habilitar QR 5 min";
                const statusPresentation = getParticipantStatusPresentation(participant);
                const StatusIcon = statusPresentation.icon;

                return (
                  <motion.article
                    key={participant.id}
                    layout="position"
                    initial={
                      shouldReduceMotion || !isNewlyAdded
                        ? false
                        : { opacity: 0, transform: "translateY(10px) scale(0.97)" }
                    }
                    animate={{ opacity: 1, transform: "translateY(0px) scale(1)" }}
                    transition={
                      shouldReduceMotion
                        ? { duration: 0 }
                        : {
                            layout: { duration: 0.22, ease: [0.16, 1, 0.3, 1] },
                            opacity: { duration: 0.2, ease: [0.23, 1, 0.32, 1] },
                            transform: { duration: 0.24, ease: [0.23, 1, 0.32, 1] },
                          }
                    }
                    className="py-3"
                  >
                    <div className="relative grid min-w-0 grid-cols-[minmax(0,1fr)_auto] items-start gap-x-3">
                      <div className="min-w-0">
                        <p className="truncate text-base font-semibold text-foreground">
                          {participant.name}
                        </p>
                        <p className="truncate text-sm text-muted">{participant.username}</p>
                      </div>
                      <div className="flex min-w-0 items-center justify-end gap-1.5">
                        <AnimatePresence initial={false}>
                          {isStatusDetailsOpen && (
                            <motion.span
                              initial={
                                shouldReduceMotion
                                  ? false
                                  : { opacity: 0, transform: "translateX(8px)" }
                              }
                              animate={{ opacity: 1, transform: "translateX(0px)" }}
                              exit={
                                shouldReduceMotion
                                  ? undefined
                                  : { opacity: 0, transform: "translateX(4px)" }
                              }
                              transition={
                                shouldReduceMotion
                                  ? { duration: 0 }
                                  : { duration: 0.24, ease: [0.23, 1, 0.32, 1] }
                              }
                              className={clsx(
                                "shrink-0 whitespace-nowrap text-right text-sm leading-5",
                                statusPresentation.textClassName,
                              )}
                            >
                              {statusPresentation.label}
                            </motion.span>
                          )}
                        </AnimatePresence>
                        <button
                          type="button"
                          onClick={() => toggleStatusDetails(participant.id)}
                          aria-expanded={isStatusDetailsOpen}
                          aria-label={`${statusPresentation.label}. Mostrar detalle del estado`}
                          className={clsx(
                            "flex size-7 shrink-0 items-center justify-center rounded-md transition-transform active:scale-95 focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none",
                            statusPresentation.surfaceClassName,
                          )}
                          title={statusPresentation.label}
                        >
                          <StatusIcon className="size-3.5" aria-hidden="true" />
                        </button>
                      </div>
                      {isActionable && (
                        <button
                          type="button"
                          onClick={() =>
                            setOpenParticipantId((openId) =>
                              openId === participant.id ? null : participant.id,
                            )
                          }
                          aria-expanded={isActionOpen}
                          aria-label={`Acciones para ${participant.name}`}
                          className="absolute right-0 bottom-0 flex size-5 items-center justify-center text-accent transition-transform focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none active:scale-95"
                        >
                          {isActionOpen ? (
                            <X className="size-4" aria-hidden="true" />
                          ) : (
                            <MoreHorizontal className="size-4" aria-hidden="true" />
                          )}
                        </button>
                      )}
                    </div>
                    <AnimatePresence initial={false}>
                      {isActionOpen && (
                        <motion.div
                          className="overflow-hidden"
                          initial={shouldReduceMotion ? false : { height: 0, opacity: 0 }}
                          animate={{ height: "auto", opacity: 1 }}
                          exit={shouldReduceMotion ? undefined : { height: 0, opacity: 0 }}
                          transition={
                            shouldReduceMotion
                              ? { duration: 0 }
                              : {
                                  height: { duration: 0.24, ease: [0.16, 1, 0.3, 1] },
                                  opacity: { duration: 0.12, delay: 0.1 },
                                }
                          }
                        >
                          <div className="mt-2 flex items-center gap-2 border-t border-accent/15 pt-2">
                            <button
                              type="button"
                              onClick={() => handleParticipantAction(participant)}
                              className="flex min-h-9 w-full items-center justify-center gap-2 rounded-lg border border-accent-fill bg-accent-fill px-3 text-base font-semibold text-accent-foreground transition-all hover:opacity-90 focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none active:scale-[0.98]"
                            >
                              {participant.status === "confirmed" ? (
                                <Clock3 className="size-4" aria-hidden="true" />
                              ) : (
                                <CheckCircle2 className="size-4" aria-hidden="true" />
                              )}
                              {actionLabel}
                            </button>
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </motion.article>
                );
              })}
            </div>
          </section>

          <section className={PROFILE_SECTION_CLASS} aria-labelledby="block-admission-title">
            <p className="mb-2 text-xs font-medium tracking-[0.12em] text-dim uppercase">
              Ingreso presencial
            </p>
            <button
              type="button"
              onClick={() => setIsSearchOpen((isOpen) => !isOpen)}
              aria-expanded={isSearchOpen}
              className="flex w-full items-center justify-between gap-3 text-left text-base font-semibold text-foreground transition-colors hover:text-accent focus-visible:ring-2 focus-visible:ring-accent focus-visible:outline-none"
            >
              <span id="block-admission-title" className="flex items-center gap-2">
                <UserPlus className="size-4 text-accent" aria-hidden="true" />
                Añadir persona sin reserva
              </span>
              {isSearchOpen ? (
                <X className="size-4" aria-hidden="true" />
              ) : (
                <Search className="size-4" aria-hidden="true" />
              )}
            </button>

            <AnimatePresence initial={false}>
              {isSearchOpen && (
                <motion.div
                  initial={
                    shouldReduceMotion
                      ? false
                      : { opacity: 0, y: -6, clipPath: "inset(0 0 100% 0)" }
                  }
                  animate={{ opacity: 1, y: 0, clipPath: "inset(0 0 0% 0)" }}
                  exit={
                    shouldReduceMotion
                      ? undefined
                      : { opacity: 0, y: -4, clipPath: "inset(0 0 100% 0)" }
                  }
                  transition={
                    shouldReduceMotion
                      ? { duration: 0 }
                      : { duration: 0.2, ease: [0.16, 1, 0.3, 1] }
                  }
                  className="mt-4 flex flex-col gap-2 border-t border-accent/15 pt-4"
                >
                  <InstitutionalUserSearch
                    emptyMessage="No hay personas disponibles para añadir."
                    inputId="block-user-search"
                    onQueryChange={setQuery}
                    onSelect={(result) => {
                      const participant = searchResults.find(
                        (candidate) => candidate.id === result.id,
                      );
                      if (participant) addSearchResult(participant);
                    }}
                    placeholder="Buscar usuario institucional"
                    query={query}
                    results={searchResults}
                    selectLabel="Añadir"
                  />
                </motion.div>
              )}
            </AnimatePresence>
          </section>

          <p className="flex items-start gap-2 px-1 pb-2 text-xs leading-5 text-dim">
            <CircleAlert className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />
            Vista de maqueta: las autorizaciones no modifican reservas ni asistencias reales.
          </p>
        </div>
      </div>
    </main>
  );
}
