import type { Metadata } from "next";
import { Geist, Geist_Mono, Inter } from "next/font/google";
import "./globals.css";
import ClientLayout from "@/app/_components/ClientLayout";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800", "900"],
});

export const metadata: Metadata = {
  title: "GameForge — Build & Ship Games with AI",
  description: "Create, configure, and publish games across all platforms in minutes. No code needed. GameForge is the fastest game studio on the planet.",
  keywords: ["game development", "no-code", "AI game builder", "WebGL", "game studio"],
  openGraph: {
    title: "GameForge — Build & Ship Games with AI",
    description: "From prompt to published game in under 3 minutes.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body
        className={`${geistSans.variable} ${geistMono.variable} ${inter.variable} antialiased cursor-none`}
      >
        <ClientLayout>{children}</ClientLayout>
      </body>
    </html>
  );
}
