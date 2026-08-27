import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CACHE_PATH = path.join(__dirname, "..", "data", "cache.json");
const TTL_MS = 24 * 60 * 60 * 1000;

function normalize(question) {
  return question.trim().toLowerCase().replace(/\s+/g, " ");
}

function load() {
  if (!fs.existsSync(CACHE_PATH)) return {};
  return JSON.parse(fs.readFileSync(CACHE_PATH, "utf-8"));
}

function persist(store) {
  fs.mkdirSync(path.dirname(CACHE_PATH), { recursive: true });
  fs.writeFileSync(CACHE_PATH, JSON.stringify(store, null, 2));
}

export function getCached(question) {
  const store = load();
  const entry = store[normalize(question)];
  if (!entry) return null;
  if (Date.now() - entry.timestamp > TTL_MS) return null;
  return entry.answer;
}

export function setCached(question, answer) {
  const store = load();
  store[normalize(question)] = { answer, timestamp: Date.now() };
  persist(store);
}
