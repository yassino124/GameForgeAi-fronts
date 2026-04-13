"use client";

import { useEffect, useMemo, useState } from "react";
import AdminShell from "@/app/_components/AdminShell";
import ConfirmDialog from "@/app/_components/ConfirmDialog";
import { apiFetch } from "@/lib/api";
import { getToken } from "@/lib/auth";

type GameFeedPost = {
  id?: string;
  _id?: string;
  title?: string;
  name?: string;
  description?: string;
  tags?: string[];
  creatorUsername?: string;
  creator?: string;
  creatorId?: string;
  creatorUserId?: string;
  likeCount?: number;
  commentCount?: number;
  playCount?: number;
  remixCount?: number;
  shareCount?: number;
  createdAt?: string;
  updatedAt?: string;
  kind?: string;
};

function postId(p: GameFeedPost) {
  return String(p?.id || p?._id || "");
}

function cx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export default function FeedAdminPage() {
  const token = useMemo(() => getToken(), []);
  const [items, setItems] = useState<GameFeedPost[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");

  const [selected, setSelected] = useState<GameFeedPost | null>(null);
  const [detailsLoading, setDetailsLoading] = useState(false);
  const [detailsError, setDetailsError] = useState<string | null>(null);

  const [editTitle, setEditTitle] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [editTags, setEditTags] = useState("");
  const [saving, setSaving] = useState(false);
  const [confirm, setConfirm] = useState<null | { id: string; action: "delete" }>(null);

  async function load() {
    if (!token) return;
    setLoading(true);
    setError(null);
    try {
      const res = await apiFetch<any>(`/game-feed?limit=200`, { method: "GET", token });
      const data = Array.isArray(res)
        ? res
        : Array.isArray(res?.data)
          ? res.data
          : Array.isArray(res?.items)
            ? res.items
            : Array.isArray(res?.data?.items)
              ? res.data.items
              : [];
      setItems(data as GameFeedPost[]);
    } catch (e: any) {
      setError(e?.message || "Failed to load game feed");
      setItems([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    const t = setInterval(load, 8000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((p) => {
      const id = postId(p);
      const title = String(p?.title || p?.name || "").toLowerCase();
      const creator = String(p?.creatorUsername || p?.creator || "").toLowerCase();
      return id.toLowerCase().includes(q) || title.includes(q) || creator.includes(q);
    });
  }, [items, search]);

  async function openDetails(p: GameFeedPost) {
    const id = postId(p);
    if (!id || !token) return;
    setSelected(p);
    setDetailsError(null);
    setDetailsLoading(true);
    try {
      const res = await apiFetch<any>(`/game-feed/${encodeURIComponent(id)}`, { method: "GET", token });
      const data = (res && typeof res === "object" && "data" in res) ? (res as any).data : res;
      const next = (data && typeof data === "object" && "post" in data) ? data.post : data;
      setSelected(next as GameFeedPost);
      setEditTitle(String((next as any)?.title || (next as any)?.name || ""));
      setEditDescription(String((next as any)?.description || ""));
      const tags = Array.isArray((next as any)?.tags) ? (next as any).tags : [];
      setEditTags(tags.join(", "));
    } catch (e: any) {
      setDetailsError(e?.message || "Failed to load post details");
    } finally {
      setDetailsLoading(false);
    }
  }

  function closeDetails() {
    setSelected(null);
    setDetailsError(null);
  }

  async function saveEdits() {
    if (!selected || !token) return;
    const id = postId(selected);
    if (!id) return;

    setSaving(true);
    setDetailsError(null);
    try {
      const tags = editTags
        .split(",")
        .map((t) => t.trim())
        .filter(Boolean);

      await apiFetch(`/game-feed/${encodeURIComponent(id)}`, {
        method: "PATCH",
        token,
        body: {
          title: editTitle.trim(),
          description: editDescription.trim(),
          tags,
        },
      });

      await openDetails({ ...selected, id } as any);
      await load();
    } catch (e: any) {
      setDetailsError(e?.message || "Failed to save");
    } finally {
      setSaving(false);
    }
  }

  async function deletePost() {
    if (!selected || !token) return;
    const id = postId(selected);
    if (!id) return;

    setSaving(true);
    setDetailsError(null);
    try {
      await apiFetch(`/game-feed/${encodeURIComponent(id)}`, { method: "DELETE", token });
      closeDetails();
      await load();
    } catch (e: any) {
      setDetailsError(e?.message || "Failed to delete");
    } finally {
      setSaving(false);
    }
  }

  return (
    <AdminShell
      title="Game Feed"
      subtitle="Full control: view, edit, delete posts"
      right={
        <button
          onClick={load}
          className="px-3 py-2 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-sm"
        >
          Refresh
        </button>
      }
    >
      <div className="p-6 space-y-6">

        <div className="flex items-center gap-3">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by title, creator, id..."
            className="w-full px-3 py-2 rounded-lg bg-black/30 border border-white/10 focus:outline-none focus:ring-2 focus:ring-indigo-500/40"
          />
        </div>

        {error && (
          <div className="p-3 rounded-lg border border-red-500/30 bg-red-500/10 text-red-200 text-sm">
            {error}
          </div>
        )}

        <div className="rounded-xl border border-white/10 overflow-hidden">
          <div className="grid grid-cols-12 gap-3 px-4 py-3 text-xs uppercase tracking-wider text-zinc-400 bg-white/5">
            <div className="col-span-4">Title</div>
            <div className="col-span-3">Creator</div>
            <div className="col-span-1 text-right">Plays</div>
            <div className="col-span-1 text-right">Likes</div>
            <div className="col-span-1 text-right">Comments</div>
            <div className="col-span-2 text-right">Actions</div>
          </div>

          {loading ? (
            <div className="p-6 text-zinc-400 text-sm">Loading…</div>
          ) : filtered.length === 0 ? (
            <div className="p-6 text-zinc-400 text-sm">No posts.</div>
          ) : (
            <div className="divide-y divide-white/5">
              {filtered.map((p, idx) => {
                const id = postId(p);
                const title = String(p?.title || p?.name || "(untitled)");
                const creator = String(p?.creatorUsername || p?.creator || "—");
                const rowKey = `${id || "no-id"}-${idx}`;
                return (
                  <div key={rowKey} className="grid grid-cols-12 gap-3 px-4 py-3 text-sm items-center">
                    <div className="col-span-4 font-medium text-white/90 truncate" title={title}>{title}</div>
                    <div className="col-span-3 text-zinc-300 truncate" title={creator}>{creator}</div>
                    <div className="col-span-1 text-right text-zinc-300">{Number(p?.playCount || 0)}</div>
                    <div className="col-span-1 text-right text-zinc-300">{Number(p?.likeCount || 0)}</div>
                    <div className="col-span-1 text-right text-zinc-300">{Number(p?.commentCount || 0)}</div>
                    <div className="col-span-2 text-right">
                      <button
                        onClick={() => openDetails(p)}
                        className="px-3 py-1.5 rounded-lg bg-indigo-500/15 border border-indigo-500/30 hover:bg-indigo-500/25 text-indigo-200 text-xs"
                      >
                        Details
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
          <div className="w-full max-w-3xl rounded-2xl border border-white/10 bg-[#0B0D16] shadow-2xl overflow-hidden">
            <div className="flex items-center justify-between px-5 py-4 bg-white/5 border-b border-white/10">
              <div>
                <div className="text-white font-bold">Post Details</div>
                <div className="text-zinc-400 text-xs">{postId(selected)}</div>
              </div>
              <button onClick={closeDetails} className="px-3 py-1.5 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-sm">Close</button>
            </div>

            <div className="p-5 space-y-4">
              {detailsError && (
                <div className="p-3 rounded-lg border border-red-500/30 bg-red-500/10 text-red-200 text-sm">
                  {detailsError}
                </div>
              )}

              {detailsLoading ? (
                <div className="text-zinc-400 text-sm">Loading details…</div>
              ) : (
                <>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <label className="text-xs text-zinc-400">Title</label>
                      <input
                        value={editTitle}
                        onChange={(e) => setEditTitle(e.target.value)}
                        className="w-full px-3 py-2 rounded-lg bg-black/30 border border-white/10 focus:outline-none focus:ring-2 focus:ring-indigo-500/40 text-sm"
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="text-xs text-zinc-400">Tags (comma separated)</label>
                      <input
                        value={editTags}
                        onChange={(e) => setEditTags(e.target.value)}
                        className="w-full px-3 py-2 rounded-lg bg-black/30 border border-white/10 focus:outline-none focus:ring-2 focus:ring-indigo-500/40 text-sm"
                      />
                    </div>
                    <div className="md:col-span-2 space-y-2">
                      <label className="text-xs text-zinc-400">Description</label>
                      <textarea
                        value={editDescription}
                        onChange={(e) => setEditDescription(e.target.value)}
                        rows={4}
                        className="w-full px-3 py-2 rounded-lg bg-black/30 border border-white/10 focus:outline-none focus:ring-2 focus:ring-indigo-500/40 text-sm"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                    <div className="p-3 rounded-xl bg-white/5 border border-white/10">
                      <div className="text-xs text-zinc-400">Plays</div>
                      <div className="text-lg font-bold">{Number((selected as any)?.playCount || 0)}</div>
                    </div>
                    <div className="p-3 rounded-xl bg-white/5 border border-white/10">
                      <div className="text-xs text-zinc-400">Likes</div>
                      <div className="text-lg font-bold">{Number((selected as any)?.likeCount || 0)}</div>
                    </div>
                    <div className="p-3 rounded-xl bg-white/5 border border-white/10">
                      <div className="text-xs text-zinc-400">Comments</div>
                      <div className="text-lg font-bold">{Number((selected as any)?.commentCount || 0)}</div>
                    </div>
                    <div className="p-3 rounded-xl bg-white/5 border border-white/10">
                      <div className="text-xs text-zinc-400">Remixes</div>
                      <div className="text-lg font-bold">{Number((selected as any)?.remixCount || 0)}</div>
                    </div>
                    <div className="p-3 rounded-xl bg-white/5 border border-white/10">
                      <div className="text-xs text-zinc-400">Shares</div>
                      <div className="text-lg font-bold">{Number((selected as any)?.shareCount || 0)}</div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between gap-3 pt-2">
                    <button
                      onClick={() => setConfirm({ id: postId(selected), action: "delete" })}
                      disabled={saving}
                      className={cx(
                        "px-4 py-2 rounded-lg border text-sm",
                        saving
                          ? "bg-white/5 border-white/10 text-zinc-500"
                          : "bg-red-500/10 border-red-500/30 hover:bg-red-500/20 text-red-200",
                      )}
                    >
                      Delete
                    </button>

                    <button
                      onClick={saveEdits}
                      disabled={saving}
                      className={cx(
                        "px-4 py-2 rounded-lg border text-sm",
                        saving
                          ? "bg-white/5 border-white/10 text-zinc-500"
                          : "bg-indigo-500/15 border-indigo-500/30 hover:bg-indigo-500/25 text-indigo-200",
                      )}
                    >
                      Save
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      )}

      <ConfirmDialog
        open={Boolean(confirm)}
        title="Delete feed post?"
        description={confirm?.id ? `Post: ${confirm.id}` : undefined}
        confirmText="Delete"
        confirmTone="danger"
        busy={saving}
        onCancel={() => setConfirm(null)}
        onConfirm={async () => {
          if (!confirm) return;
          setConfirm(null);
          await deletePost();
        }}
      />
    </AdminShell>
  );
}
