import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const upsertLocation = mutation({
  args: {
    busId: v.string(),
    driverName: v.string(),
    routeId: v.string(),
    latitude: v.number(),
    longitude: v.number(),
    timestamp: v.number(),
    status: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("buses")
      .withIndex("by_busId", (q) => q.eq("busId", args.busId))
      .first();

    const data = {
      ...args,
      lastUpdated: Date.now(),
    };

    if (existing) {
      await ctx.db.patch(existing._id, data);
      return existing._id;
    }

    return await ctx.db.insert("buses", data);
  },
});

export const updateStatus = mutation({
  args: {
    busId: v.string(),
    status: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("buses")
      .withIndex("by_busId", (q) => q.eq("busId", args.busId))
      .first();

    if (!existing) {
      return;
    }

    await ctx.db.patch(existing._id, {
      status: args.status,
      lastUpdated: Date.now(),
    });
  },
});

export const remove = mutation({
  args: { busId: v.string() },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("buses")
      .withIndex("by_busId", (q) => q.eq("busId", args.busId))
      .first();

    if (existing) {
      await ctx.db.delete(existing._id);
    }
  },
});

export const listActive = query({
  args: {},
  handler: async (ctx) => {
    const buses = await ctx.db.query("buses").collect();
    const now = Date.now();
    const staleAfterMs = 3 * 60 * 1000;

    return buses.filter(
      (bus) =>
        bus.status === "running" && now - bus.lastUpdated < staleAfterMs,
    );
  },
});

export const pruneStale = mutation({
  args: {},
  handler: async (ctx) => {
    const buses = await ctx.db.query("buses").collect();
    const now = Date.now();
    const staleAfterMs = 3 * 60 * 1000;
    let removed = 0;

    for (const bus of buses) {
      if (now - bus.lastUpdated >= staleAfterMs) {
        await ctx.db.delete(bus._id);
        removed += 1;
      }
    }

    return removed;
  },
});
