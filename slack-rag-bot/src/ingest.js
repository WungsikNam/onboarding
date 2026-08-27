import "dotenv/config";
import fs from "fs";
import path from "path";
import crypto from "crypto";
import { fileURLToPath } from "url";
import OpenAI from "openai";
import { loadStore, saveStore } from "./vectorStore.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DOCS_DIR = path.join(__dirname, "..", "docs");
const EMBEDDING_MODEL = "text-embedding-3-small";
const CHUNK_SIZE = 800;
const CHUNK_OVERLAP = 100;
const BATCH_SIZE = 50;

function hash(text) {
  return crypto.createHash("sha256").update(text).digest("hex");
}

function chunkText(text) {
  const chunks = [];
  let start = 0;
  while (start < text.length) {
    const end = Math.min(start + CHUNK_SIZE, text.length);
    chunks.push(text.slice(start, end).trim());
    if (end === text.length) break;
    start = end - CHUNK_OVERLAP;
  }
  return chunks.filter(Boolean);
}

function loadDocs() {
  if (!fs.existsSync(DOCS_DIR)) return [];
  return fs
    .readdirSync(DOCS_DIR)
    .filter((f) => f.endsWith(".md") || f.endsWith(".txt"))
    .map((file) => ({
      file,
      text: fs.readFileSync(path.join(DOCS_DIR, file), "utf-8"),
    }));
}

async function embedBatch(client, texts) {
  const res = await client.embeddings.create({
    model: EMBEDDING_MODEL,
    input: texts,
  });
  return res.data.map((d) => d.embedding);
}

async function main() {
  const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  const existing = loadStore();
  const existingHashes = new Set(existing.map((e) => e.hash));

  const docs = loadDocs();
  const candidates = [];
  for (const { file, text } of docs) {
    const chunks = chunkText(text);
    chunks.forEach((chunk, i) => {
      const chunkHash = hash(chunk);
      if (existingHashes.has(chunkHash)) return;
      candidates.push({ file, chunkIndex: i, text: chunk, hash: chunkHash });
    });
  }

  if (candidates.length === 0) {
    console.log(`새로 임베딩할 문서 조각이 없습니다. (기존 ${existing.length}개 유지)`);
    return;
  }

  console.log(`${candidates.length}개의 새 조각을 임베딩합니다. (스킵된 중복: ${docs.length ? "확인됨" : 0})`);

  const newEntries = [];
  for (let i = 0; i < candidates.length; i += BATCH_SIZE) {
    const batch = candidates.slice(i, i + BATCH_SIZE);
    const embeddings = await embedBatch(client, batch.map((b) => b.text));
    batch.forEach((item, j) => {
      newEntries.push({
        id: `${item.file}#${item.chunkIndex}`,
        text: item.text,
        embedding: embeddings[j],
        hash: item.hash,
        source: item.file,
      });
    });
    console.log(`  진행: ${Math.min(i + BATCH_SIZE, candidates.length)}/${candidates.length}`);
  }

  const merged = [...existing, ...newEntries];
  saveStore(merged);
  console.log(`완료. 총 ${merged.length}개 조각이 저장되었습니다.`);
}

main().catch((err) => {
  console.error("ingest 실패:", err);
  process.exit(1);
});
