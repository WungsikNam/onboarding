import "dotenv/config";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";
import { loadStore, search } from "./vectorStore.js";

const EMBEDDING_MODEL = "text-embedding-3-small";
const CLAUDE_MODEL = "claude-haiku-4-5-20251001";
const TOP_K = Number(process.env.TOP_K || 4);

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

async function embedQuery(question) {
  const res = await openai.embeddings.create({
    model: EMBEDDING_MODEL,
    input: question,
  });
  return res.data[0].embedding;
}

function buildPrompt(question, chunks) {
  const context = chunks
    .map((c, i) => `[문서 ${i + 1}: ${c.source}]\n${c.text}`)
    .join("\n\n");

  return `아래는 회사 문서에서 검색된 내용입니다. 이 내용만을 근거로 질문에 답하세요.
문서에 답이 없으면 "문서에서 관련 내용을 찾지 못했습니다"라고 답하세요. 추측하지 마세요.

# 검색된 문서
${context}

# 질문
${question}`;
}

export async function answerQuestion(question) {
  const store = loadStore();

  if (store.length === 0) {
    return "아직 학습된 문서가 없습니다. 관리자가 docs/ 에 문서를 넣고 `npm run ingest`를 실행해야 합니다.";
  }

  const queryEmbedding = await embedQuery(question);
  const chunks = search(store, queryEmbedding, TOP_K);

  const message = await anthropic.messages.create({
    model: CLAUDE_MODEL,
    max_tokens: 1024,
    messages: [{ role: "user", content: buildPrompt(question, chunks) }],
  });

  return message.content
    .filter((block) => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}
