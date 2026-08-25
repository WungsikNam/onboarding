import "dotenv/config";
import pkg from "@slack/bolt";
import { answerQuestion } from "./rag.js";
import { getCached, setCached } from "./cache.js";
import { checkAndConsume } from "./rateLimiter.js";

const { App } = pkg;

const app = new App({
  token: process.env.SLACK_BOT_TOKEN,
  appToken: process.env.SLACK_APP_TOKEN,
  socketMode: true,
});

app.event("message", async ({ event, client }) => {
  if (event.channel_type !== "im") return;
  if (event.subtype || event.bot_id) return;

  const question = event.text?.trim();
  if (!question) return;

  const { allowed, limit } = checkAndConsume(event.user);
  if (!allowed) {
    await client.chat.postMessage({
      channel: event.channel,
      text: `오늘의 질문 한도(${limit}회)를 모두 사용했습니다. 내일 다시 시도해 주세요.`,
    });
    return;
  }

  const cached = getCached(question);
  if (cached) {
    await client.chat.postMessage({ channel: event.channel, text: cached });
    return;
  }

  try {
    const answer = await answerQuestion(question);
    setCached(question, answer);
    await client.chat.postMessage({ channel: event.channel, text: answer });
  } catch (err) {
    console.error("답변 생성 실패:", err);
    await client.chat.postMessage({
      channel: event.channel,
      text: "답변을 생성하는 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.",
    });
  }
});

(async () => {
  await app.start();
  console.log("Slack RAG bot이 시작되었습니다 (Socket Mode).");
})();
