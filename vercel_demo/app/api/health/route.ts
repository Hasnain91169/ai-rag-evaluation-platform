import { NextResponse } from "next/server";

import { getStoreMode } from "@/lib/store";

export const runtime = "nodejs";

export async function GET(): Promise<NextResponse> {
  const mode = await getStoreMode();
  return NextResponse.json({ status: "ok", mode, timestamp: new Date().toISOString() });
}
