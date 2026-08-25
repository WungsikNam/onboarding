# Slack RAG Bot

회사 문서를 기반으로 Slack DM 질문에 답하는 RAG(검색 증강 생성) 봇입니다.
문서 임베딩은 OpenAI, 답변 생성은 Anthropic Claude Haiku를 사용합니다.

## 구조

```
slack-rag-bot/
  docs/            회사 문서를 넣는 곳 (.md, .txt)
  src/
    ingest.js      문서 → 청크 분할 → 임베딩 → 벡터 저장 (배치 처리 + 중복 스킵)
    vectorStore.js 로컬 JSON 기반 코사인 유사도 검색
    rag.js         검색 + Claude Haiku 답변 생성
    cache.js       동일 질문 24시간 캐싱
    rateLimiter.js 유저당 일일 질문 횟수 제한
    index.js       Slack Bolt 서버 (DM 이벤트 처리)
  data/            벡터 스토어/캐시/사용량 저장 (자동 생성, git 미포함)
```

## 설치 및 실행

1. 의존성 설치
   ```
   npm install
   ```

2. 환경 변수 설정
   ```
   cp .env.example .env
   ```
   `.env`에 아래 값을 채웁니다.
   - `SLACK_BOT_TOKEN`: Slack Bot User OAuth Token (`xoxb-...`)
   - `SLACK_APP_TOKEN`: Slack App-Level Token (`xapp-...`, Socket Mode용)
   - `OPENAI_API_KEY`: 문서/질문 임베딩용
   - `ANTHROPIC_API_KEY`: 답변 생성용 (Claude Haiku)

3. 문서 넣고 인덱싱
   `docs/` 폴더에 실제 회사 문서(.md, .txt)를 넣은 뒤:
   ```
   npm run ingest
   ```
   이미 임베딩된 조각은 해시로 감지해 다시 임베딩하지 않으므로, 문서를 추가/수정한 뒤
   다시 실행해도 새로 바뀐 부분만 비용이 발생합니다.

4. 봇 실행
   ```
   npm start
   ```

## Slack 앱 설정

1. https://api.slack.com/apps 에서 새 앱 생성
2. **Socket Mode** 활성화 → App-Level Token 생성 (`connections:write` 스코프)
3. **OAuth & Permissions**에서 Bot Token Scopes에 아래 추가
   - `im:history`
   - `chat:write`
4. **Event Subscriptions**에서 Socket Mode 사용 시 아래 이벤트 구독
   - `message.im`
5. 앱을 워크스페이스에 설치하고 Bot Token(`xoxb-...`)을 `.env`에 저장
6. 봇에게 DM을 보내면 답변이 옵니다.

## 동작 방식

1. 사용자가 봇에게 DM으로 질문
2. 일일 사용량 제한 확인 (기본 30회/일, `RATE_LIMIT_PER_DAY`로 조정 가능)
3. 동일 질문이 24시간 내 캐시에 있으면 즉시 응답
4. 질문을 임베딩 → 저장된 문서 조각 중 가장 유사한 상위 N개 검색 (`TOP_K`)
5. 검색된 문서만을 근거로 Claude Haiku가 답변 생성 (문서에 없는 내용은 추측하지 않음)
6. 답변을 캐시에 저장 후 Slack으로 응답

## 비용 절감 포인트

- 임베딩은 문서 청크 단위 해시로 중복을 감지해 스킵
- 임베딩 요청은 배치로 묶어서 호출
- 동일 질문은 캐싱해 재호출 방지
- 유저당 일일 질문 횟수 제한
