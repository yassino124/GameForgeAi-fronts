"use client";

import {
  createContext,
  ReactNode,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
} from "react";

type ToastKind = "success" | "error" | "info";

type Toast = {
  id: string;
  kind: ToastKind;
  title: string;
  message?: string;
  createdAt: number;
};

type ToastApi = {
  push: (t: { kind: ToastKind; title: string; message?: string }) => void;
  success: (title: string, message?: string) => void;
  error: (title: string, message?: string) => void;
  info: (title: string, message?: string) => void;
};

const ToastContext = createContext<ToastApi | null>(null);

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function ToastCard(props: { toast: Toast; onClose: () => void }) {
  const { toast } = props;
  const palette =
    toast.kind === "success"
      ? "border-emerald-400/20 bg-emerald-500/10 text-emerald-100"
      : toast.kind === "error"
        ? "border-red-400/20 bg-red-500/10 text-red-100"
        : "border-white/10 bg-white/5 text-zinc-100";

  return (
    <div
      className={cx(
        "pointer-events-auto w-[360px] rounded-2xl border p-4 shadow-[0_0_0_1px_rgba(255,255,255,0.04)] backdrop-blur-xl",
        palette,
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="truncate text-sm font-semibold">{toast.title}</div>
          {toast.message ? (
            <div className="mt-1 text-xs text-white/70">{toast.message}</div>
          ) : null}
        </div>
        <button
          className="gf-btn rounded-lg px-2 py-1 text-xs"
          onClick={props.onClose}
        >
          Close
        </button>
      </div>
    </div>
  );
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const timers = useRef(new Map<string, any>());

  const remove = useCallback((id: string) => {
    setToasts((cur) => cur.filter((t) => t.id !== id));
    const tm = timers.current.get(id);
    if (tm) {
      clearTimeout(tm);
      timers.current.delete(id);
    }
  }, []);

  const push = useCallback(
    (t: { kind: ToastKind; title: string; message?: string }) => {
      const id = `${Date.now()}_${Math.random().toString(16).slice(2)}`;
      const toast: Toast = {
        id,
        kind: t.kind,
        title: t.title,
        message: t.message,
        createdAt: Date.now(),
      };
      setToasts((cur) => [toast, ...cur].slice(0, 5));
      const tm = setTimeout(() => remove(id), 3500);
      timers.current.set(id, tm);
    },
    [remove],
  );

  const api: ToastApi = useMemo(
    () => ({
      push,
      success: (title: string, message?: string) => push({ kind: "success", title, message }),
      error: (title: string, message?: string) => push({ kind: "error", title, message }),
      info: (title: string, message?: string) => push({ kind: "info", title, message }),
    }),
    [push],
  );

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div className="pointer-events-none fixed right-4 top-4 z-[100] flex flex-col gap-3">
        {toasts.map((t) => (
          <ToastCard key={t.id} toast={t} onClose={() => remove(t.id)} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) {
    throw new Error("useToast must be used within ToastProvider");
  }
  return ctx;
}
