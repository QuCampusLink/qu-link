import { mutation, query } from "./_generated/server";
import type { MutationCtx, QueryCtx } from "./_generated/server";
import { v } from "convex/values";
import { firestoreStopSeeds } from "./stopsSeedData";

const STOP_ID_ALIASES: Record<string, string> = {
  male_hostel: "male_hostel",
  MALE_HOSTEL: "male_hostel",
  Male_Hostel: "male_hostel",
  female_hostel: "female_hostel",
  FEMALE_HOSTEL: "female_hostel",
  Female_Hostel: "female_hostel",
};

function normalizeStopId(stopId: string): string {
  return STOP_ID_ALIASES[stopId] ?? stopId;
}

async function findStopById(ctx: QueryCtx, stopId: string) {
  const normalized = normalizeStopId(stopId);
  const candidates = [
    normalized,
    stopId,
    stopId.toUpperCase(),
    stopId.toLowerCase(),
  ];
  const seen = new Set<string>();

  for (const id of candidates) {
    if (seen.has(id)) continue;
    seen.add(id);

    const stop = await ctx.db
      .query("stops")
      .withIndex("by_stopId", (q) => q.eq("stopId", id))
      .first();
    if (stop) {
      return stop;
    }
  }
  return null;
}

async function upsertStop(
  ctx: MutationCtx,
  stopId: string,
  routes: Record<string, number[]>,
) {
  const existing = await findStopById(ctx, stopId);
  if (existing) {
    await ctx.db.patch(existing._id, { routes, stopId });
    return `updated ${stopId}`;
  }
  await ctx.db.insert("stops", { stopId, routes });
  return `inserted ${stopId}`;
}

export const getSchedule = query({
  args: { stopId: v.string() },
  handler: async (ctx, args) => {
    const stop = await findStopById(ctx, args.stopId);

    if (!stop) {
      return null;
    }

    return {
      routes: stop.routes,
    };
  },
});

/** Import all stop schedules from outputfinal.json (stopsSeedData.ts). */
export const importAllFromFirestore = mutation({
  args: {},
  handler: async (ctx) => {
    const results: string[] = [];

    for (const seed of firestoreStopSeeds) {
      results.push(await upsertStop(ctx, seed.stopId, seed.routes));
    }

    return {
      count: results.length,
      stopIds: firestoreStopSeeds.map((s) => s.stopId),
      results,
    };
  },
});

export const listStopIds = query({
  args: {},
  handler: async (ctx) => {
    const stops = await ctx.db.query("stops").collect();
    return stops
      .map((s) => s.stopId)
      .sort((a, b) => a.localeCompare(b));
  },
});

/** Re-import hostel stops only (legacy helper). */
export const seedHostelSchedules = mutation({
  args: {},
  handler: async (ctx) => {
    const hostelStops = firestoreStopSeeds.filter((seed) =>
      seed.stopId === "male_hostel" || seed.stopId === "female_hostel",
    );
    const results: string[] = [];

    for (const seed of hostelStops) {
      results.push(await upsertStop(ctx, seed.stopId, seed.routes));
    }

    return results;
  },
});
