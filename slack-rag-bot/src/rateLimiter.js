import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const LIMIT_PATH = path.join(__dirname, "..", "data", "rate-limit.json");
const DAILY_LIMIT = Number(process.env.RATE_LIMIT_PER_DAY || 30);

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function load() {
  if (!fs.existsSync(LIMIT_PATH)) return {};
  return JSON.parse(fs.readFileSync(LIMIT_PATH, "utf-8"));
}

function persist(store) {
  fs.mkdirSync(path.dirname(LIMIT_PATH), { recursive: true });
  fs.writeFileSync(LIMIT_PATH, JSON.stringify(store, null, 2));
}

export function checkAndConsume(userId) {
  const store = load();
  const day = todayKey();
  if (store.day !== day) {
    store.day = day;
    store.counts = {};
  }
  store.counts = store.counts || {};
  const used = store.counts[userId] || 0;

  if (used >= DAILY_LIMIT) {
    return { allowed: false, remaining: 0, limit: DAILY_LIMIT };
  }

  store.counts[userId] = used + 1;
  persist(store);
  return { allowed: true, remaining: DAILY_LIMIT - (used + 1), limit: DAILY_LIMIT };
}
