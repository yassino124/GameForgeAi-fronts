"use client";

import { useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { apiFetch } from "@/lib/api";
import { useAuthToken } from "@/lib/stores/authStore";
import { normalizeImageUrl } from "@/lib/media";

const SELECTED_PROJECT_KEY = "wowlabs:selectedProjectId";
const SELECTED_TEMPLATE_KEY = "wowlabs:selectedTemplateId";

export type LabsTemplate = {
  id: string;
  name: string;
  category?: string;
  description?: string;
  tags: string[];
  previewImageUrl?: string;
};

export type LabsProject = {
  id: string;
  name: string;
  description?: string;
  status?: string;
  previewImageUrl?: string;
};

function asRecord(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function pickApiList(raw: unknown): unknown[] {
  if (Array.isArray(raw)) return raw;
  const obj = asRecord(raw);
  if (!obj) return [];

  if (Array.isArray(obj.data)) return obj.data;
  if (Array.isArray(obj.items)) return obj.items;

  const dataObj = asRecord(obj.data);
  if (!dataObj) return [];
  if (Array.isArray(dataObj.items)) return dataObj.items;

  return [];
}

function normalizeTemplate(raw: unknown): LabsTemplate | null {
  const obj = asRecord(raw);
  if (!obj) return null;
  const id = asString(obj.id) || asString(obj._id);
  const name = asString(obj.name) || asString(obj.title);
  if (!id || !name) return null;
  const tags = Array.isArray(obj.tags) ? obj.tags.filter((t): t is string => typeof t === "string") : [];
  return {
    id,
    name,
    category: asString(obj.category) || undefined,
    description: asString(obj.description) || undefined,
    tags,
    previewImageUrl: normalizeImageUrl(
      asString(obj.previewImageUrl) ||
        asString(obj.thumbnailUrl) ||
        asString(obj.iconUrl) ||
        asString(obj.imageUrl),
    ),
  };
}

function normalizeProject(raw: unknown): LabsProject | null {
  const obj = asRecord(raw);
  if (!obj) return null;
  const id = asString(obj.id) || asString(obj._id);
  const name = asString(obj.name);
  if (!id || !name) return null;
  return {
    id,
    name,
    description: asString(obj.description) || undefined,
    status: asString(obj.status) || undefined,
    previewImageUrl: normalizeImageUrl(
      asString(obj.previewImageUrl) ||
        asString(obj.thumbnailUrl) ||
        asString(obj.iconUrl) ||
        asString(obj.imageUrl),
    ),
  };
}

function readLocalStorage(key: string): string {
  if (typeof window === "undefined") return "";
  try {
    return window.localStorage.getItem(key) || "";
  } catch {
    return "";
  }
}

function writeLocalStorage(key: string, value: string) {
  if (typeof window === "undefined") return;
  try {
    if (!value) {
      window.localStorage.removeItem(key);
      return;
    }
    window.localStorage.setItem(key, value);
  } catch {
    // ignore
  }
}

export function buildModuleHref(baseHref: string, selectedProjectId?: string, selectedTemplateId?: string) {
  const qp = new URLSearchParams();
  if (selectedProjectId) qp.set("projectId", selectedProjectId);
  if (selectedTemplateId) qp.set("templateId", selectedTemplateId);
  const suffix = qp.toString();
  return suffix ? `${baseHref}?${suffix}` : baseHref;
}

export function useLabsContext(options?: { withProjects?: boolean; withTemplates?: boolean }) {
  const withProjects = options?.withProjects !== false;
  const withTemplates = options?.withTemplates !== false;

  const { token, hydrated } = useAuthToken();

  const [selectedProjectId, setSelectedProjectIdState] = useState("");
  const [selectedTemplateId, setSelectedTemplateIdState] = useState("");

  const projectsQuery = useQuery<LabsProject[]>({
    queryKey: ["wow-labs", "projects", token],
    enabled: withProjects && hydrated && Boolean(token),
    queryFn: async () => {
      const raw = await apiFetch<unknown>("/projects", { method: "GET", token: token || undefined });
      const list = pickApiList(raw);
      return (Array.isArray(list) ? list : [])
        .map(normalizeProject)
        .filter((x): x is LabsProject => Boolean(x));
    },
  });

  const templatesQuery = useQuery<LabsTemplate[]>({
    queryKey: ["wow-labs", "templates", token],
    enabled: withTemplates && hydrated,
    queryFn: async () => {
      const raw = await apiFetch<unknown>("/templates", { method: "GET", token: token || undefined });
      const list = pickApiList(raw);
      return (Array.isArray(list) ? list : [])
        .map(normalizeTemplate)
        .filter((x): x is LabsTemplate => Boolean(x));
    },
  });

  const projects = withProjects ? projectsQuery.data || [] : [];
  const templates = withTemplates ? templatesQuery.data || [] : [];
  const loading =
    (withProjects && (projectsQuery.isLoading || projectsQuery.isFetching)) ||
    (withTemplates && (templatesQuery.isLoading || templatesQuery.isFetching));

  const selectedProject = useMemo(
    () => projects.find((p) => p.id === selectedProjectId) || null,
    [projects, selectedProjectId],
  );
  const selectedTemplate = useMemo(
    () => templates.find((t) => t.id === selectedTemplateId) || null,
    [templates, selectedTemplateId],
  );

  function setSelectedProjectId(next: string) {
    setSelectedProjectIdState(next);
    writeLocalStorage(SELECTED_PROJECT_KEY, next);
  }

  function setSelectedTemplateId(next: string) {
    setSelectedTemplateIdState(next);
    writeLocalStorage(SELECTED_TEMPLATE_KEY, next);
  }

  useEffect(() => {
    if (!hydrated) return;

    const queryParams =
      typeof window !== "undefined" ? new URLSearchParams(window.location.search) : new URLSearchParams();
    const queryProjectId = queryParams.get("projectId") || "";
    const queryTemplateId = queryParams.get("templateId") || "";

    const localProjectId = readLocalStorage(SELECTED_PROJECT_KEY);
    const localTemplateId = readLocalStorage(SELECTED_TEMPLATE_KEY);

    if (withProjects) {
      const preferredProjectId = queryProjectId || localProjectId;
      const projectExists = projects.some((p) => p.id === preferredProjectId);
      const nextProjectId = projectExists ? preferredProjectId : projects[0]?.id || "";
      if (nextProjectId !== selectedProjectId) {
        setSelectedProjectId(nextProjectId);
      }
    }

    if (withTemplates) {
      const preferredTemplateId = queryTemplateId || localTemplateId;
      const templateExists = templates.some((t) => t.id === preferredTemplateId);
      const nextTemplateId = templateExists ? preferredTemplateId : templates[0]?.id || "";
      if (nextTemplateId !== selectedTemplateId) {
        setSelectedTemplateId(nextTemplateId);
      }
    }
  }, [
    hydrated,
    projects,
    selectedProjectId,
    selectedTemplateId,
    setSelectedProjectId,
    setSelectedTemplateId,
    templates,
    withProjects,
    withTemplates,
  ]);

  async function reload() {
    await Promise.all([
      withProjects ? projectsQuery.refetch() : Promise.resolve(),
      withTemplates ? templatesQuery.refetch() : Promise.resolve(),
    ]);
  }

  return {
    token,
    loading,
    projects,
    templates,
    selectedProjectId,
    selectedTemplateId,
    selectedProject,
    selectedTemplate,
    setSelectedProjectId,
    setSelectedTemplateId,
    reload,
  };
}
