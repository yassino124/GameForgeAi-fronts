import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,

  turbopack: {
    root: __dirname,
  },

  allowedDevOrigins: ["http://localhost:3000", "http://localhost:3001", "http://192.168.1.27:3001"],
};

export default nextConfig;
