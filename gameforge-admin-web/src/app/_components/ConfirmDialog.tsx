"use client";

import { ReactNode } from "react";

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export default function ConfirmDialog(props: {
  open: boolean;
  title: string;
  description?: string;
  confirmText?: string;
  confirmTone?: "danger" | "default";
  children?: ReactNode;
  onCancel: () => void;
  onConfirm: () => void;
  busy?: boolean;
}) {
  if (!props.open) return null;

  const confirmClass =
    props.confirmTone === "danger"
      ? "gf-btn gf-btn-danger"
      : "gf-btn";

  return (
    <div className="fixed inset-0 z-[120] flex items-center justify-center">
      <div
        className="absolute inset-0 bg-black/70 backdrop-blur-sm"
        onClick={() => (props.busy ? null : props.onCancel())}
      />
      <div className="gf-panel-strong relative mx-4 w-full max-w-md rounded-2xl p-5">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <div className="text-base font-semibold text-white">{props.title}</div>
            {props.description ? (
              <div className="mt-1 text-sm text-zinc-300">{props.description}</div>
            ) : null}
          </div>
          <button
            disabled={props.busy}
            className="gf-btn rounded-lg px-2 py-1 text-xs disabled:opacity-50"
            onClick={props.onCancel}
          >
            Esc
          </button>
        </div>

        {props.children ? <div className="mt-4">{props.children}</div> : null}

        <div className="mt-5 flex items-center justify-end gap-2">
          <button
            disabled={props.busy}
            className="gf-btn h-9 rounded-xl px-3 text-sm disabled:opacity-50"
            onClick={props.onCancel}
          >
            Cancel
          </button>
          <button
            disabled={props.busy}
            className={cx(
              "h-9 rounded-xl px-3 text-sm disabled:opacity-50",
              confirmClass,
            )}
            onClick={props.onConfirm}
          >
            {props.busy ? "Working..." : props.confirmText || "Confirm"}
          </button>
        </div>
      </div>
    </div>
  );
}
