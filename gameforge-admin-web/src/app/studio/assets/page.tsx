"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Search, Plus, Trash2, Download, Upload, Link as LinkIcon,
  Image as ImageIcon, Package, Code2, Headphones, Layers,
  RefreshCw, X, AlertCircle, FolderPlus,
} from "lucide-react";
import UserShell from "@/app/_components/UserShell";
import { API_BASE_URL, apiFetch, apiFetchForm } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";

type Asset = {
  _id?: string; id?: string; name: string; type: string;
  size?: number; unityPath?: string; tags?: string[]; status?: string; storageKey?: string;
};

const TYPE_FILTERS = ["All", "texture", "model", "audio", "shader", "other"] as const;

function typeIcon(t: string) {
  switch (t) {
    case "texture": return <ImageIcon size={16} />;
    case "model":   return <Package size={16} />;
    case "audio":   return <Headphones size={16} />;
    case "shader":  return <Code2 size={16} />;
    default:        return <Layers size={16} />;
  }
}

function fmtSize(s?: number) {
  if (!s) return "";
  if (s >= 1024 * 1024) return `${(s / 1024 / 1024).toFixed(1)} MB`;
  if (s >= 1024) return `${(s / 1024).toFixed(1)} KB`;
  return `${s} B`;
}

export default function AssetsLibraryPage() {
  const { token } = useAuthToken();
  const [assets,      setAssets]      = useState<Asset[]>([]);
  const [collections, setCollections] = useState<any[]>([]);
  const [loading,     setLoading]     = useState(false);
  const [error,       setError]       = useState<string | null>(null);
  const [search,      setSearch]      = useState("");
  const [typeFilter,  setTypeFilter]  = useState<string>("All");
  const [colFilter,   setColFilter]   = useState<string>("All");
  const [urlInput,    setUrlInput]    = useState("");
  const [urlType,     setUrlType]     = useState("texture");
  const [showUrlDlg,  setShowUrlDlg]  = useState(false);
  const [showColDlg,  setShowColDlg]  = useState(false);
  const [newColName,  setNewColName]  = useState("");
  const [uploading,   setUploading]   = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => { load(); }, [token, typeFilter, colFilter]);

  async function load() {
    if (!token) return;
    setLoading(true); setError(null);
    try {
      const qp = new URLSearchParams();
      if (typeFilter !== "All") qp.set("type", typeFilter);
      if (colFilter  !== "All") qp.set("collectionId", colFilter);
      if (search.trim()) qp.set("q", search.trim());
      qp.set("limit", "50");
      const [ar, cr] = await Promise.all([
        apiFetch<any>(`/assets?${qp}`, { token }),
        apiFetch<any>("/assets/collections/list", { token }),
      ]);
      const items = Array.isArray(ar) ? ar : (Array.isArray(ar?.items) ? ar.items : []);
      const cols  = Array.isArray(cr) ? cr : [];
      setAssets(items);
      setCollections(cols);
    } catch (e: any) {
      setError(e.message ?? "Failed to load");
    } finally { setLoading(false); }
  }

  async function uploadFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file || !token) return;
    setUploading(true);
    try {
      const form = new FormData();
      form.append("file", file);
      form.append("type", guessType(file.name));
      await apiFetchForm("/assets/upload", { token, form });
      await load();
    } catch (e: any) { setError(e.message); } finally { setUploading(false); }
    e.target.value = "";
  }

  async function uploadByUrl() {
    if (!urlInput.trim() || !token) return;
    setUploading(true);
    try {
      await apiFetch("/assets/upload-url", {
        method: "POST", token,
        body: { url: urlInput.trim(), type: urlType },
      });
      setUrlInput(""); setShowUrlDlg(false);
      await load();
    } catch (e: any) { setError(e.message); } finally { setUploading(false); }
  }

  async function deleteAsset(asset: Asset) {
    const id = asset._id ?? asset.id;
    if (!id || !token) return;
    if (!confirm(`Delete "${asset.name}"?`)) return;
    try {
      await apiFetch(`/assets/${id}`, { method: "DELETE", token });
      setAssets(prev => prev.filter(a => (a._id ?? a.id) !== id));
    } catch (e: any) { setError(e.message); }
  }

  async function downloadAsset(asset: Asset) {
    const id = asset._id ?? asset.id;
    if (!id || !token) return;
    try {
      const res = await apiFetch<any>(`/assets/${id}/download-url`, { token });
      const url = res?.url ?? res?.data?.url;
      if (!url) return;

      const resolved = (() => {
        const s = String(url).trim();
        if (!s) return '';
        if (/^https?:\/\//i.test(s)) return s;
        const origin = API_BASE_URL.replace(/\/api\/?$/i, '');
        return s.startsWith('/') ? `${origin}${s}` : `${origin}/${s}`;
      })();
      if (!resolved) return;

      const headers = (() => {
        try {
          const u = new URL(resolved);
          const apiOrigin = new URL(API_BASE_URL).origin;
          if (u.origin === apiOrigin) {
            return { Authorization: `Bearer ${token}` };
          }
        } catch {
          // ignore
        }
        return undefined;
      })();

      const resp = await fetch(resolved, { headers });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const blob = await resp.blob();
      const objUrl = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = objUrl;
      a.download = asset.name || 'asset';
      a.click();
      URL.revokeObjectURL(objUrl);
    } catch (e: any) { setError(e.message); }
  }

  async function createCollection() {
    if (!newColName.trim() || !token) return;
    try {
      await apiFetch("/assets/collections", {
        method: "POST", token,
        body: { name: newColName.trim() },
      });
      setNewColName(""); setShowColDlg(false);
      await load();
    } catch (e: any) { setError(e.message); }
  }

  function guessType(name: string) {
    const ext = name.split(".").pop()?.toLowerCase() ?? "";
    if (["png","jpg","jpeg","webp","svg","gif"].includes(ext)) return "texture";
    if (["mp3","wav","ogg","flac"].includes(ext)) return "audio";
    if (["glb","gltf","fbx","obj"].includes(ext)) return "model";
    if (["glsl","hlsl","shader"].includes(ext)) return "shader";
    return "other";
  }

  const filtered = useMemo(() =>
    assets.filter(a => !search || a.name.toLowerCase().includes(search.toLowerCase())),
    [assets, search]
  );

  return (
    <UserShell title="Asset Vault" subtitle="Manage and export your Unity game assets">
      <div className="space-y-6 pb-20">

        {/* Toolbar */}
        <div className="flex flex-wrap gap-3 items-center">
          {/* Search */}
          <div className="relative flex-1 min-w-[200px]">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
            <input
              className="w-full bg-white/[0.03] border border-white/5 rounded-2xl pl-10 pr-4 py-3 text-sm text-white placeholder:text-zinc-600 focus:outline-none focus:border-white/20 transition-colors"
              placeholder="Search assets…"
              value={search}
              onChange={e => { setSearch(e.target.value); load(); }}
            />
          </div>

          {/* Type filter */}
          <div className="flex bg-white/[0.03] border border-white/5 p-1 rounded-2xl gap-1">
            {TYPE_FILTERS.map(f => (
              <button key={f} onClick={() => setTypeFilter(f)}
                className={`px-3 py-1.5 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
                  typeFilter === f ? "bg-white text-black" : "text-zinc-500 hover:text-white"
                }`}>{f}</button>
            ))}
          </div>

          {/* Collection filter */}
          <select
            value={colFilter}
            onChange={e => setColFilter(e.target.value)}
            className="bg-white/[0.03] border border-white/5 rounded-2xl px-4 py-3 text-sm text-zinc-400 focus:outline-none focus:border-white/20"
          >
            <option value="All">All collections</option>
            {collections.map(c => (
              <option key={c._id ?? c.id} value={c._id ?? c.id}>{c.name}</option>
            ))}
          </select>

          {/* Actions */}
          <button onClick={() => setShowColDlg(true)}
            className="flex items-center gap-2 px-4 py-3 rounded-2xl bg-white/[0.03] border border-white/5 text-sm text-zinc-400 hover:text-white transition-all">
            <FolderPlus size={15} /> Collection
          </button>
          <button onClick={() => setShowUrlDlg(true)}
            className="flex items-center gap-2 px-4 py-3 rounded-2xl bg-white/[0.03] border border-white/5 text-sm text-zinc-400 hover:text-white transition-all">
            <LinkIcon size={15} /> URL
          </button>
          <button
            onClick={() => fileRef.current?.click()}
            disabled={uploading}
            className="flex items-center gap-2 px-4 py-3 rounded-2xl bg-blue-500 text-white text-sm font-bold hover:bg-blue-400 transition-all disabled:opacity-50"
          >
            <Upload size={15} /> {uploading ? "Uploading…" : "Upload"}
          </button>
          <input ref={fileRef} type="file" className="hidden" onChange={uploadFile} />
          <button onClick={load} className="p-3 rounded-2xl bg-white/[0.03] border border-white/5 text-zinc-500 hover:text-white transition-colors">
            <RefreshCw size={15} />
          </button>
        </div>

        {/* Error */}
        <AnimatePresence>
          {error && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className="flex items-center gap-3 p-4 rounded-2xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
              <AlertCircle size={16} />
              {error}
              <button onClick={() => setError(null)} className="ml-auto"><X size={14} /></button>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Grid */}
        {loading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-4">
            {Array.from({ length: 12 }).map((_, i) => (
              <div key={i} className="aspect-square rounded-3xl animate-pulse bg-white/5" />
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-48 border border-dashed border-white/5 rounded-3xl gap-4">
            <span className="text-4xl">📦</span>
            <p className="text-zinc-500 text-sm">Vault Empty — upload or link your first asset</p>
            <button onClick={() => fileRef.current?.click()}
              className="flex items-center gap-2 px-4 py-2 rounded-2xl bg-blue-500 text-white text-sm font-bold hover:bg-blue-400 transition-all">
              <Plus size={14} /> Upload Asset
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
            {filtered.map((a, i) => {
              const id = a._id ?? a.id ?? i;
              return (
                <motion.div key={String(id)}
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: i * 0.02 }}
                  className="group relative bg-white/[0.02] border border-white/5 rounded-3xl overflow-hidden hover:border-white/15 transition-all"
                >
                  {/* Icon area */}
                  <div className="aspect-square flex flex-col items-center justify-center gap-2 bg-zinc-900/40 text-zinc-400">
                    {typeIcon(a.type)}
                    <span className="text-[9px] font-black uppercase tracking-widest text-zinc-600">{a.type}</span>
                  </div>

                  {/* Hover overlay */}
                  <div className="absolute inset-0 bg-black/80 opacity-0 group-hover:opacity-100 transition-all flex flex-col justify-between p-3">
                    <div className="flex justify-end gap-1">
                      <button onClick={() => downloadAsset(a)}
                        className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-zinc-400 hover:text-white transition-colors">
                        <Download size={12} />
                      </button>
                      <button onClick={() => deleteAsset(a)}
                        className="p-1.5 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400 transition-colors">
                        <Trash2 size={12} />
                      </button>
                    </div>
                    <div>
                      <p className="text-[10px] font-bold text-white truncate">{a.name}</p>
                      {a.size && <p className="text-[9px] text-zinc-500">{fmtSize(a.size)}</p>}
                      {a.unityPath && <p className="text-[8px] text-zinc-600 truncate mt-1">{a.unityPath}</p>}
                    </div>
                  </div>

                  {/* Bottom label */}
                  <div className="px-3 py-2 border-t border-white/5">
                    <p className="text-[10px] font-bold text-zinc-400 truncate">{a.name}</p>
                  </div>
                </motion.div>
              );
            })}
          </div>
        )}

        {/* URL upload dialog */}
        <AnimatePresence>
          {showUrlDlg && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xl flex items-center justify-center p-6">
              <div className="bg-zinc-900 border border-white/10 rounded-3xl p-8 w-full max-w-md space-y-4">
                <div className="flex justify-between items-center">
                  <h3 className="text-white font-bold">Upload from URL</h3>
                  <button onClick={() => setShowUrlDlg(false)}><X size={18} className="text-zinc-500" /></button>
                </div>
                <input
                  className="w-full bg-white/[0.05] border border-white/10 rounded-2xl px-4 py-3 text-sm text-white placeholder:text-zinc-600 focus:outline-none"
                  placeholder="https://example.com/texture.png"
                  value={urlInput} onChange={e => setUrlInput(e.target.value)}
                />
                <select value={urlType} onChange={e => setUrlType(e.target.value)}
                  className="w-full bg-white/[0.05] border border-white/10 rounded-2xl px-4 py-3 text-sm text-zinc-400 focus:outline-none">
                  <option value="texture">Texture</option>
                  <option value="model">Model</option>
                  <option value="audio">Audio</option>
                  <option value="shader">Shader</option>
                  <option value="other">Other</option>
                </select>
                <button onClick={uploadByUrl} disabled={uploading || !urlInput.trim()}
                  className="w-full py-3 rounded-2xl bg-blue-500 text-white font-bold text-sm disabled:opacity-50 hover:bg-blue-400 transition-all">
                  {uploading ? "Uploading…" : "Upload"}
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Collection dialog */}
        <AnimatePresence>
          {showColDlg && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xl flex items-center justify-center p-6">
              <div className="bg-zinc-900 border border-white/10 rounded-3xl p-8 w-full max-w-md space-y-4">
                <div className="flex justify-between items-center">
                  <h3 className="text-white font-bold">New Collection</h3>
                  <button onClick={() => setShowColDlg(false)}><X size={18} className="text-zinc-500" /></button>
                </div>
                <input
                  className="w-full bg-white/[0.05] border border-white/10 rounded-2xl px-4 py-3 text-sm text-white placeholder:text-zinc-600 focus:outline-none"
                  placeholder="Collection name…"
                  value={newColName} onChange={e => setNewColName(e.target.value)}
                  onKeyDown={e => e.key === "Enter" && createCollection()}
                />
                <button onClick={createCollection} disabled={!newColName.trim()}
                  className="w-full py-3 rounded-2xl bg-blue-500 text-white font-bold text-sm disabled:opacity-50 hover:bg-blue-400 transition-all">
                  Create
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </UserShell>
  );
}
