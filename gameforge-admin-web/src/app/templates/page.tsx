"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import AdminShell from "@/app/_components/AdminShell";
import { apiFetch, apiFetchForm, ApiError } from "@/lib/api";
import { clearToken, getToken } from "@/lib/auth";
import ConfirmDialog from "@/app/_components/ConfirmDialog";
import { useToast } from "@/app/_components/ToastProvider";
import { NeonChip } from "@/app/_components/Hud";

type TemplateRow = {
  id: string;
  ownerId?: string;
  name?: string;
  description?: string;
  category?: string;
  tags?: string[];
  isPublic?: boolean;
  price?: number;
  rating?: number;
  downloads?: number;
  previewImageUrl?: string;
  createdAt?: string;
};

type Paged<T> = { page: number; limit: number; total: number; items: T[] };

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function PublicPill({ isPublic }: { isPublic?: boolean }) {
  return (
    <span
      className={cx(
        "rounded-full border px-2 py-0.5 text-xs",
        isPublic ? "border-emerald-400/20 bg-emerald-500/10 text-emerald-200" : "border-white/10 bg-white/5 text-zinc-200",
      )}
    >
      {isPublic ? "public" : "private"}
    </span>
  );
}

export default function TemplatesPage() {
  return (
    <Suspense fallback={null}>
      <TemplatesPageInner />
    </Suspense>
  );
}

function TemplatesPageInner() {
  const toast = useToast();
  const searchParams = useSearchParams();
  const token = useMemo(() => getToken(), []);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [uploadOpen, setUploadOpen] = useState(() => searchParams.get("upload") === "1");
  const [uploadBusy, setUploadBusy] = useState(false);
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const [uploadPreviewImage, setUploadPreviewImage] = useState<File | null>(null);
  const [uploadPreviewVideo, setUploadPreviewVideo] = useState<File | null>(null);
  const [uploadScreenshots, setUploadScreenshots] = useState<File[]>([]);
  const [uploadName, setUploadName] = useState("");
  const [uploadDescription, setUploadDescription] = useState("");
  const [uploadCategory, setUploadCategory] = useState("");
  const [uploadTags, setUploadTags] = useState("");
  const [uploadPrice, setUploadPrice] = useState("");

  const [q, setQ] = useState(() => searchParams.get("q") || "");
  const [category, setCategory] = useState(() => searchParams.get("category") || "");
  const [publicFlag, setPublicFlag] = useState(() => searchParams.get("public") || "");
  const [page, setPage] = useState(1);
  const [data, setData] = useState<Paged<TemplateRow> | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<null | { id: string; action: "toggle" | "delete"; name?: string; nextPublic?: boolean }>(null);

  const [editOpen, setEditOpen] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [editCategory, setEditCategory] = useState("");
  const [editTags, setEditTags] = useState("");
  const [editPrice, setEditPrice] = useState("");
  const [editBusy, setEditBusy] = useState(false);
  const [editPreviewImage, setEditPreviewImage] = useState<File | null>(null);
  const [editPreviewVideo, setEditPreviewVideo] = useState<File | null>(null);
  const [editScreenshots, setEditScreenshots] = useState<File[]>([]);

  async function load() {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const qs = new URLSearchParams();
      qs.set("page", String(page));
      qs.set("limit", "20");
      if (q.trim()) qs.set("q", q.trim());
      if (category.trim()) qs.set("category", category.trim());
      if (publicFlag.trim()) qs.set("public", publicFlag.trim());
      const res = await apiFetch<Paged<TemplateRow>>(`/admin/templates?${qs.toString()}`, { method: "GET", token });
      setData(res);
    } catch (e: any) {
      const msg = e?.message || "Failed to load templates";
      setError(msg);
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
        clearToken();
      }
    } finally {
      setLoading(false);
    }
  }

  async function doUpload() {
    if (!token) return;
    if (!uploadFile) {
      toast.error("Missing file", "Please select a template zip file");
      return;
    }
    setUploadBusy(true);
    setError(null);
    try {
      const form = new FormData();
      form.append("file", uploadFile);
      if (uploadPreviewImage) form.append("previewImage", uploadPreviewImage);
      if (uploadPreviewVideo) form.append("previewVideo", uploadPreviewVideo);
      for (const s of uploadScreenshots) form.append("screenshots", s);
      if (uploadName.trim()) form.append("name", uploadName.trim());
      if (uploadDescription.trim()) form.append("description", uploadDescription.trim());
      if (uploadCategory.trim()) form.append("category", uploadCategory.trim());
      if (uploadTags.trim()) form.append("tags", uploadTags.trim());
      if (uploadPrice.trim()) form.append("price", uploadPrice.trim());

      await apiFetchForm("/templates/upload", { method: "POST", token, form });
      toast.success("Template uploaded");
      setUploadOpen(false);
      setUploadFile(null);
      setUploadPreviewImage(null);
      setUploadPreviewVideo(null);
      setUploadScreenshots([]);
      setUploadName("");
      setUploadDescription("");
      setUploadCategory("");
      setUploadTags("");
      setUploadPrice("");
      await load();
    } catch (e: any) {
      const msg = e?.message || "Upload failed";
      setError(msg);
      toast.error("Upload failed", msg);
    } finally {
      setUploadBusy(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, q, category, publicFlag]);

  useEffect(() => {
    const nextQ = searchParams.get("q") || "";
    const nextCategory = searchParams.get("category") || "";
    const nextPublic = searchParams.get("public") || "";
    setQ(nextQ);
    setCategory(nextCategory);
    setPublicFlag(nextPublic);
    setPage(1);
    setUploadOpen(searchParams.get("upload") === "1");
    setTimeout(() => {
      load();
    }, 0);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  const total = data?.total ?? 0;
  const totalPages = Math.max(1, Math.ceil(total / (data?.limit || 20)));

  async function doTemplateAction(templateId: string, action: "toggle" | "delete", nextPublic?: boolean) {
    if (!token) return;
    setBusyId(templateId);
    setError(null);
    try {
      if (action === "delete") {
        await apiFetch(`/admin/templates/${encodeURIComponent(templateId)}`, { method: "DELETE", token });
        toast.success("Template deleted");
      } else {
        await apiFetch(`/admin/templates/${encodeURIComponent(templateId)}/public`, {
          method: "PATCH",
          token,
          body: { isPublic: Boolean(nextPublic) },
        });
        toast.success("Template updated", nextPublic ? "Now public" : "Now private");
      }
      await load();
    } catch (e: any) {
      const msg = e?.message || "Action failed";
      setError(msg);
      toast.error("Action failed", msg);
    } finally {
      setBusyId(null);
    }
  }

  function openEditModal(t: TemplateRow) {
    setEditId(t.id);
    setEditName(t.name || "");
    setEditDescription(t.description || "");
    setEditCategory(t.category || "");
    setEditTags((t.tags || []).join(", "));
    setEditPrice(String(t.price ?? 0));
    setEditPreviewImage(null);
    setEditPreviewVideo(null);
    setEditScreenshots([]);
    setEditOpen(true);
  }

  async function doEdit() {
    if (!token || !editId) return;
    setEditBusy(true);
    setError(null);
    try {
      // Update text fields
      const body: any = {};
      if (editName.trim()) body.name = editName.trim();
      if (editDescription.trim()) body.description = editDescription.trim();
      if (editCategory.trim()) body.category = editCategory.trim();
      if (editTags.trim()) {
        body.tags = editTags.split(",").map((t) => t.trim()).filter(Boolean);
      }
      const priceNum = parseFloat(editPrice);
      if (Number.isFinite(priceNum) && priceNum >= 0) body.price = priceNum;

      if (Object.keys(body).length > 0) {
        await apiFetch(`/admin/templates/${encodeURIComponent(editId)}`, {
          method: "PATCH",
          token,
          body,
        });
      }

      // Update media if any files selected
      if (editPreviewImage || editPreviewVideo || editScreenshots.length > 0) {
        const form = new FormData();
        if (editPreviewImage) form.append("previewImage", editPreviewImage);
        if (editPreviewVideo) form.append("previewVideo", editPreviewVideo);
        for (const s of editScreenshots) form.append("screenshots", s);
        await apiFetchForm(`/templates/${encodeURIComponent(editId)}/media`, { method: "POST", token, form });
      }

      toast.success("Template updated");
      setEditOpen(false);
      setEditId(null);
      await load();
    } catch (e: any) {
      const msg = e?.message || "Update failed";
      setError(msg);
      toast.error("Update failed", msg);
    } finally {
      setEditBusy(false);
    }
  }

  return (
    <AdminShell
      title="Templates"
      right={
        <div className="flex items-center gap-2">
          <NeonChip tone="amber">
            <span className="font-mono">VAULT</span>
            <span className="text-white">TEMPLATES</span>
          </NeonChip>
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search templates"
            className="gf-input h-9 w-56 rounded-xl px-3 text-sm placeholder:text-zinc-500"
          />
          <input
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            placeholder="Category"
            className="gf-input h-9 w-40 rounded-xl px-3 text-sm placeholder:text-zinc-500"
          />
          <select
            value={publicFlag}
            onChange={(e) => setPublicFlag(e.target.value)}
            className="gf-input h-9 rounded-xl px-3 text-sm"
          >
            <option value="">All</option>
            <option value="true">public</option>
            <option value="false">private</option>
          </select>
          <button
            onClick={() => {
              setPage(1);
              load();
            }}
            className="gf-btn h-9 rounded-xl px-3 text-sm"
          >
            Apply
          </button>
          <button
            onClick={() => setUploadOpen(true)}
            className="gf-btn h-9 rounded-xl px-3 text-sm"
          >
            Upload
          </button>
        </div>
      }
    >
      <div className="gf-card relative mb-4 overflow-hidden rounded-2xl border border-white/10 p-5">
        <div
          className="pointer-events-none absolute inset-0 opacity-50"
          style={{
            backgroundImage:
              "radial-gradient(circle at 20% 0%, rgba(34,211,238,0.18), transparent 55%), radial-gradient(circle at 80% 100%, rgba(251,191,36,0.14), transparent 55%)",
          }}
        />
        <div className="pointer-events-none absolute inset-0 opacity-20" style={{ backgroundImage: "repeating-linear-gradient(to bottom, rgba(255,255,255,0.10), rgba(255,255,255,0.10) 1px, transparent 1px, transparent 7px)" }} />
        <div className="relative flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <NeonChip tone="amber">TEMPLATE VAULT</NeonChip>
            <div className="mt-2 text-sm text-zinc-400">Upload, publish, and manage marketplace content</div>
          </div>
          <NeonChip tone="zinc">
            <span className="font-mono">TOTAL</span>
            <span className="text-white">{loading ? "—" : String(total)}</span>
          </NeonChip>
        </div>
      </div>

      {error ? (
        <div className="mb-4 rounded-xl border border-red-400/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
          {error}
        </div>
      ) : null}

      <div className="gf-table gf-scrollbar overflow-hidden rounded-2xl">
        <div className="gf-table-head grid grid-cols-[1.3fr_0.8fr_0.6fr_0.6fr_0.7fr_0.9fr] gap-0 border-b border-white/10 px-4 py-3 text-xs font-medium text-zinc-400">
          <div>Template</div>
          <div>Category</div>
          <div>Visibility</div>
          <div>Price</div>
          <div>Rating / DL</div>
          <div className="text-right">Actions</div>
        </div>

        {(loading ? Array.from({ length: 8 }) : data?.items || []).map((t: any, idx: number) => (
          <div
            key={t?.id || idx}
            className="gf-row gf-tr grid grid-cols-[1.3fr_0.8fr_0.6fr_0.6fr_0.7fr_0.9fr] items-center gap-0 px-4 py-3 text-sm text-zinc-200"
          >
            <div className="flex items-center gap-3 truncate">
              {loading ? (
                <div className="h-10 w-10 animate-pulse rounded-xl bg-white/10" />
              ) : (
                <div
                  className="h-10 w-10 rounded-xl border border-white/10 bg-white/5"
                  style={
                    t.previewImageUrl
                      ? { backgroundImage: `url(${t.previewImageUrl})`, backgroundSize: "cover", backgroundPosition: "center" }
                      : undefined
                  }
                />
              )}
              <div className="min-w-0">
                <div className="truncate">
                  {loading ? <div className="h-4 w-56 animate-pulse rounded bg-white/10" /> : t.name || "—"}
                </div>
                {!loading ? (
                  <div className="mt-0.5 truncate text-xs text-zinc-500">
                    {(t.tags || []).slice(0, 4).join(", ")}
                  </div>
                ) : null}
              </div>
            </div>
            <div className="truncate">{loading ? <div className="h-4 w-24 animate-pulse rounded bg-white/10" /> : t.category || "—"}</div>
            <div>{loading ? <div className="h-4 w-16 animate-pulse rounded bg-white/10" /> : <PublicPill isPublic={t.isPublic} />}</div>
            <div>
              {loading ? <div className="h-4 w-12 animate-pulse rounded bg-white/10" /> : `$${Number(t.price || 0).toFixed(2)}`}
            </div>
            <div className="text-xs text-zinc-300">
              {loading ? (
                <div className="h-4 w-24 animate-pulse rounded bg-white/10" />
              ) : (
                <>
                  <span className="text-zinc-200">{Number(t.rating || 0).toFixed(1)}</span>
                  <span className="text-zinc-500"> / </span>
                  <span>{Number(t.downloads || 0)}</span>
                </>
              )}
            </div>
            <div className="flex justify-end gap-2">
              {loading ? (
                <div className="h-9 w-32 animate-pulse rounded-xl bg-white/10" />
              ) : (
                <>
                  <button
                    disabled={busyId === t.id}
                    onClick={() => openEditModal(t)}
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Edit
                  </button>
                  <button
                    disabled={busyId === t.id}
                    onClick={() =>
                      setConfirm({
                        id: t.id,
                        action: "toggle",
                        name: t.name,
                        nextPublic: !Boolean(t.isPublic),
                      })
                    }
                    className="gf-btn h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    {t.isPublic ? "Make private" : "Make public"}
                  </button>
                  <button
                    disabled={busyId === t.id}
                    onClick={() => setConfirm({ id: t.id, action: "delete", name: t.name })}
                    className="gf-btn gf-btn-danger h-9 rounded-xl px-3 text-xs disabled:opacity-50"
                  >
                    Delete
                  </button>
                </>
              )}
            </div>
          </div>
        ))}
      </div>

      <div className="mt-4 flex items-center justify-between text-sm text-zinc-300">
        <div>
          Showing {(data?.items?.length ?? 0).toString()} of {total.toString()}
        </div>
        <div className="flex items-center gap-2">
          <button
            disabled={page <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            className="gf-btn h-9 rounded-xl px-3 text-sm disabled:opacity-50"
          >
            Prev
          </button>
          <div className="gf-input rounded-xl px-3 py-2 text-xs">
            Page {page} / {totalPages}
          </div>
          <button
            disabled={page >= totalPages}
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            className="gf-btn h-9 rounded-xl px-3 text-sm disabled:opacity-50"
          >
            Next
          </button>
        </div>
      </div>

      <ConfirmDialog
        open={Boolean(confirm)}
        title={
          confirm?.action === "delete"
            ? "Delete template?"
            : confirm?.nextPublic
              ? "Make template public?"
              : "Make template private?"
        }
        description={confirm?.name ? `Template: ${confirm.name}` : undefined}
        confirmText={
          confirm?.action === "delete" ? "Delete" : confirm?.nextPublic ? "Make public" : "Make private"
        }
        confirmTone={confirm?.action === "delete" ? "danger" : "default"}
        busy={Boolean(confirm?.id && busyId === confirm.id)}
        onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          if (!confirm) return;
          const { id, action, nextPublic } = confirm;
          setConfirm(null);
          await doTemplateAction(id, action, nextPublic);
        }}
      />

      {uploadOpen ? (
        <div className="fixed inset-0 z-[150] flex items-start justify-center pt-20">
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={() => (uploadBusy ? null : setUploadOpen(false))} />
          <div className="gf-panel-strong relative mx-4 w-full max-w-2xl overflow-hidden rounded-2xl">
            <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
              <div>
                <h3 className="text-sm font-semibold text-white">Upload Template</h3>
                <p className="mt-1 text-xs text-zinc-500">Upload a Unity template zip and optional media.</p>
              </div>
              <button
                className="gf-btn h-9 rounded-xl px-3 text-sm"
                disabled={uploadBusy}
                onClick={() => setUploadOpen(false)}
              >
                Close
              </button>
            </div>

            <div className="grid grid-cols-1 gap-4 px-5 py-5 sm:grid-cols-2">
              <div className="sm:col-span-2">
                <label className="text-xs font-medium text-zinc-400">Template zip</label>
                <input
                  type="file"
                  accept=".zip"
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  disabled={uploadBusy}
                  onChange={(e) => setUploadFile(e.target.files?.[0] || null)}
                />
              </div>

              <div>
                <label className="text-xs font-medium text-zinc-400">Name</label>
                <input
                  value={uploadName}
                  onChange={(e) => setUploadName(e.target.value)}
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  placeholder="My awesome template"
                  disabled={uploadBusy}
                />
              </div>
              <div>
                <label className="text-xs font-medium text-zinc-400">Category</label>
                <input
                  value={uploadCategory}
                  onChange={(e) => setUploadCategory(e.target.value)}
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  placeholder="Platformer"
                  disabled={uploadBusy}
                />
              </div>

              <div className="sm:col-span-2">
                <label className="text-xs font-medium text-zinc-400">Description</label>
                <textarea
                  value={uploadDescription}
                  onChange={(e) => setUploadDescription(e.target.value)}
                  className="mt-2 gf-input w-full resize-none rounded-xl px-3 py-2 text-sm"
                  rows={3}
                  placeholder="Short description"
                  disabled={uploadBusy}
                />
              </div>

              <div>
                <label className="text-xs font-medium text-zinc-400">Tags</label>
                <input
                  value={uploadTags}
                  onChange={(e) => setUploadTags(e.target.value)}
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  placeholder="fps, sci-fi, multiplayer"
                  disabled={uploadBusy}
                />
              </div>
              <div>
                <label className="text-xs font-medium text-zinc-400">Price</label>
                <input
                  value={uploadPrice}
                  onChange={(e) => setUploadPrice(e.target.value)}
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  placeholder="9.99"
                  disabled={uploadBusy}
                />
              </div>

              <div>
                <label className="text-xs font-medium text-zinc-400">Preview image</label>
                <input
                  type="file"
                  accept="image/*"
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  disabled={uploadBusy}
                  onChange={(e) => setUploadPreviewImage(e.target.files?.[0] || null)}
                />
              </div>
              <div>
                <label className="text-xs font-medium text-zinc-400">Preview video</label>
                <input
                  type="file"
                  accept="video/*"
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  disabled={uploadBusy}
                  onChange={(e) => setUploadPreviewVideo(e.target.files?.[0] || null)}
                />
              </div>

              <div className="sm:col-span-2">
                <label className="text-xs font-medium text-zinc-400">Screenshots</label>
                <input
                  type="file"
                  accept="image/*"
                  multiple
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  disabled={uploadBusy}
                  onChange={(e) => setUploadScreenshots(Array.from(e.target.files || []))}
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 border-t border-white/10 px-5 py-4">
              <button
                className="gf-btn h-10 rounded-xl px-4 text-sm disabled:opacity-50"
                disabled={uploadBusy}
                onClick={() => setUploadOpen(false)}
              >
                Cancel
              </button>
              <button
                className="gf-btn h-10 rounded-xl px-4 text-sm disabled:opacity-50"
                disabled={uploadBusy}
                onClick={doUpload}
              >
                {uploadBusy ? "Uploading…" : "Upload"}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      {editOpen ? (
        <div className="fixed inset-0 z-[150] flex items-start justify-center pt-20">
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={() => (editBusy ? null : setEditOpen(false))} />
          <div className="gf-panel-strong relative mx-4 w-full max-w-xl overflow-hidden rounded-2xl">
            <div className="flex items-center justify-between border-b border-white/10 px-5 py-4">
              <div>
                <h3 className="text-sm font-semibold text-white">Edit Template</h3>
                <p className="mt-1 text-xs text-zinc-500">Update template details.</p>
              </div>
              <button
                className="gf-btn h-9 rounded-xl px-3 text-sm"
                disabled={editBusy}
                onClick={() => setEditOpen(false)}
              >
                Close
              </button>
            </div>

            <div className="grid grid-cols-1 gap-4 px-5 py-5">
              <div>
                <label className="text-xs font-medium text-zinc-400">Name</label>
                <input
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  placeholder="Template name"
                  disabled={editBusy}
                />
              </div>
              <div>
                <label className="text-xs font-medium text-zinc-400">Category</label>
                <input
                  value={editCategory}
                  onChange={(e) => setEditCategory(e.target.value)}
                  className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                  placeholder="Platformer"
                  disabled={editBusy}
                />
              </div>

              <div>
                <label className="text-xs font-medium text-zinc-400">Description</label>
                <textarea
                  value={editDescription}
                  onChange={(e) => setEditDescription(e.target.value)}
                  className="mt-2 gf-input w-full resize-none rounded-xl px-3 py-2 text-sm"
                  rows={3}
                  placeholder="Short description"
                  disabled={editBusy}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-xs font-medium text-zinc-400">Tags</label>
                  <input
                    value={editTags}
                    onChange={(e) => setEditTags(e.target.value)}
                    className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                    placeholder="fps, sci-fi, multiplayer"
                    disabled={editBusy}
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-zinc-400">Price ($)</label>
                  <input
                    value={editPrice}
                    onChange={(e) => setEditPrice(e.target.value)}
                    className="mt-2 gf-input w-full rounded-xl px-3 py-2 text-sm"
                    placeholder="9.99"
                    disabled={editBusy}
                  />
                </div>
              </div>

              <div className="border-t border-white/10 pt-4 mt-2">
                <div className="text-xs font-medium text-zinc-400 mb-3">Media (optional)</div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="text-xs text-zinc-500">Preview image</label>
                    <input
                      type="file"
                      accept="image/*"
                      className="mt-1 gf-input w-full rounded-xl px-3 py-2 text-sm"
                      disabled={editBusy}
                      onChange={(e) => setEditPreviewImage(e.target.files?.[0] || null)}
                    />
                  </div>
                  <div>
                    <label className="text-xs text-zinc-500">Preview video</label>
                    <input
                      type="file"
                      accept="video/*"
                      className="mt-1 gf-input w-full rounded-xl px-3 py-2 text-sm"
                      disabled={editBusy}
                      onChange={(e) => setEditPreviewVideo(e.target.files?.[0] || null)}
                    />
                  </div>
                </div>
                <div className="mt-3">
                  <label className="text-xs text-zinc-500">Screenshots</label>
                  <input
                    type="file"
                    accept="image/*"
                    multiple
                    className="mt-1 gf-input w-full rounded-xl px-3 py-2 text-sm"
                    disabled={editBusy}
                    onChange={(e) => setEditScreenshots(Array.from(e.target.files || []))}
                  />
                </div>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 border-t border-white/10 px-5 py-4">
              <button
                className="gf-btn h-10 rounded-xl px-4 text-sm disabled:opacity-50"
                disabled={editBusy}
                onClick={() => setEditOpen(false)}
              >
                Cancel
              </button>
              <button
                className="gf-btn h-10 rounded-xl px-4 text-sm disabled:opacity-50"
                disabled={editBusy}
                onClick={doEdit}
              >
                {editBusy ? "Saving…" : "Save"}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </AdminShell>
  );
}
