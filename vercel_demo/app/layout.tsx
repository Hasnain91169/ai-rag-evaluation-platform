import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "RAG Eval Trace Demo",
  description: "Vercel-hosted demo for trace-level RAG evaluation introspection"
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>): JSX.Element {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
