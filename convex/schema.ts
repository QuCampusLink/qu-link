import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  buses: defineTable({
    busId: v.string(),
    driverName: v.string(),
    routeId: v.string(),
    latitude: v.number(),
    longitude: v.number(),
    timestamp: v.number(),
    status: v.string(),
    lastUpdated: v.number(),
  }).index("by_busId", ["busId"]),

  stops: defineTable({
    stopId: v.string(),
    routes: v.any(),
  }).index("by_stopId", ["stopId"]),
});
