import { NextResponse } from "next/server";

import { getStoreMode, listTraces } from "@/lib/store";

export const runtime = "nodejs";

export async function GET(): Promise<NextResponse> {
  const traces = await listTraces(20);
  const mode = await getStoreMode();
  return NextResponse.json({ traces, mode });
}
