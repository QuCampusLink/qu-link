import { query } from "./_generated/server";
import { v } from "convex/values";

export const getSchedule = query({
  args: { stopId: v.string() },
  handler: async (ctx, args) => {
    const stop = await ctx.db
      .query("stops")
      .withIndex("by_stopId", (q) => q.eq("stopId", args.stopId.toUpperCase()))
      .first();

    if (!stop) {
      return null;
    }

    return {
      routes: stop.routes,
    };
  },
});
