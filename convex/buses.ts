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
    return buses.filter((bus) => bus.status === "running");
  },
});
