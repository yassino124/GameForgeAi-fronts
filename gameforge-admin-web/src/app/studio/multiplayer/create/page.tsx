"use client";

import { Suspense, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import UserShell from "@/app/_components/UserShell";
import { useMultiplayerSocket } from "@/lib/multiplayer";
import { readAuthToken } from "@/lib/stores/authStore";
import { useToast } from "@/app/_components/ToastProvider";

function CreateRoomHandler() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const name = searchParams.get("name");
  const token = readAuthToken();
  const { socket, connected, error } = useMultiplayerSocket(token);
  const toast = useToast();

  useEffect(() => {
    if (!token) {
      toast.error("Sign in required", "Please sign in to use Multiplayer");
      router.replace("/signin");
      return;
    }

    if (error) {
      toast.error("Multiplayer connection failed", error);
      router.replace("/studio/multiplayer");
      return;
    }

    if (!socket || !connected) return;

    const timeout = window.setTimeout(() => {
      toast.error("Multiplayer timeout", "Could not connect to Multiplayer server");
      router.replace("/studio/multiplayer");
    }, 8000);

    socket.emit("room:create", { name });

    const handleRoom = (payload: any) => {
      const room = payload?.data?.room ?? payload?.room ?? payload;
      const rid = room?.roomId;
      if (rid) {
        window.clearTimeout(timeout);
        router.replace(`/studio/multiplayer/${rid}`);
      }
    };

    socket.on("room:created", handleRoom);
    socket.on("room:update", handleRoom);

    socket.on("mp:error", (err) => {
      window.clearTimeout(timeout);
      toast.error("Error", err?.message || "Failed to create room");
      router.back();
    });

    return () => {
      window.clearTimeout(timeout);
      socket.off("room:created", handleRoom);
      socket.off("room:update", handleRoom);
      socket.off("mp:error");
    };
  }, [socket, connected, name, router, toast, token, error]);

  return (
    <div className="flex flex-col items-center gap-6">
      <div className="w-16 h-16 border-4 border-blue-500/20 border-t-blue-500 rounded-full animate-spin" />
      <div className="text-center">
        <p className="font-black tracking-widest text-blue-400 uppercase italic text-xl">Architecting Reality</p>
        <p className="text-zinc-500 text-sm mt-2 uppercase tracking-widest font-bold">Initializing Multiplayer Instance...</p>
      </div>
    </div>
  );
}

export default function StudioCreateRoomPage() {
  return (
    <UserShell title="Multiplayer" subtitle="Creating Room">
      <div className="gf-app h-[calc(100vh-200px)] flex items-center justify-center rounded-3xl">
        <Suspense fallback={<div>Loading...</div>}>
          <CreateRoomHandler />
        </Suspense>
      </div>
    </UserShell>
  );
}
