/**
 * Parses Firebase stop schedules and writes Convex seed data.
 * Primary source: old firebase output/outputfinal.json
 * Run: node scripts/import-firestore-stops.mjs
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const outputFinalPath = path.join(root, "old firebase output", "outputfinal.json");

/** Map Firestore doc IDs to app stop IDs used in bus_service.dart */
const STOP_ID_ALIASES = {
  Male_Hostel: "male_hostel",
  Female_Hostel: "female_hostel",
};

function normalizeStopId(docId) {
  return STOP_ID_ALIASES[docId] ?? docId;
}

function loadFromOutputFinal() {
  const raw = JSON.parse(fs.readFileSync(outputFinalPath, "utf8"));
  const stops = [];

  for (const [docId, value] of Object.entries(raw)) {
    const routes = value?.routes ?? value;
    if (!routes || typeof routes !== "object") {
      throw new Error(`Invalid stop entry for ${docId}`);
    }
    stops.push({
      stopId: normalizeStopId(docId),
      firestoreId: docId,
      routes,
    });
  }

  return stops;
}

const stops = loadFromOutputFinal();
stops.sort((a, b) => a.stopId.localeCompare(b.stopId));

const jsonOut = path.join(root, "data", "convex_stops_import.json");
fs.writeFileSync(jsonOut, JSON.stringify(stops, null, 2));

const tsOut = path.join(root, "convex", "stopsSeedData.ts");
const tsBody = `/** Auto-generated from old firebase output/outputfinal.json. Do not edit by hand. */
export type StopSeed = { stopId: string; routes: Record<string, number[]> };

export const firestoreStopSeeds: StopSeed[] = ${JSON.stringify(
  stops.map(({ stopId, routes }) => ({ stopId, routes })),
  null,
  2,
)};
`;

fs.writeFileSync(tsOut, tsBody);

console.log(`Source: ${outputFinalPath}`);
console.log(`Parsed ${stops.length} stops`);
console.log(`Wrote ${jsonOut}`);
console.log(`Wrote ${tsOut}`);
for (const s of stops) {
  const routeCount = Object.keys(s.routes).length;
  console.log(`  ${s.stopId} (${s.firestoreId}): ${routeCount} routes`);
}
