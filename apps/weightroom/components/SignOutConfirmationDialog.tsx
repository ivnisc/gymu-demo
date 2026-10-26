import { LogOut, X } from "lucide-react";

type SignOutConfirmationDialogProps = {
  onCancel: () => void;
  onConfirm: () => void;
};

export function SignOutConfirmationDialog({ onCancel, onConfirm }: SignOutConfirmationDialogProps) {
  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-overlay px-5">
      <section
        role="dialog"
        aria-modal="true"
        aria-labelledby="sign-out-title"
        className="w-full max-w-sm rounded-2xl border border-divider bg-surface p-5 shadow-2xl"
      >
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="text-sm font-medium tracking-widest text-accent">Cerrar Sesión</p>
            <h2 id="sign-out-title" className="mt-2 text-xl font-semibold text-foreground">
              ¿Estás seguro?
            </h2>
          </div>
          <button
            type="button"
            onClick={onCancel}
            aria-label="Volver"
            className="flex size-8 shrink-0 items-center justify-center rounded-full text-muted transition-colors hover:bg-input hover:text-foreground active:scale-95"
          >
            <X className="size-4" aria-hidden="true" />
          </button>
        </div>
        <div className="mt-5 flex gap-3">
          <button
            type="button"
            onClick={onCancel}
            className="flex flex-1 items-center justify-center rounded-xl bg-accent-fill px-3 py-2.5 text-base font-semibold text-accent-foreground shadow-sm transition-opacity hover:opacity-90 active:scale-[0.98]"
          >
            Volver
          </button>
          <button
            type="button"
            onClick={onConfirm}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-capacity-segment-red px-3 py-2.5 text-base font-semibold text-white shadow-sm transition-opacity hover:opacity-90 active:scale-[0.98]"
          >
            <LogOut className="size-4" aria-hidden="true" />
            Cerrar sesión
          </button>
        </div>
      </section>
    </div>
  );
}
