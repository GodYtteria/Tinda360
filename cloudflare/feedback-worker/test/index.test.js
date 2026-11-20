import assert from 'node:assert/strict';
import { test } from 'node:test';

import worker from '../src/index.js';
import { MAXIMUM_BODY_BYTES } from '../src/validate.js';

const FEEDBACK_URL = 'https://feedback.example.test/v1/feedback';

const validEvent = {
  id: '0123456789abcdef',
  created_day: '2026-11-20',
  app_version: '1.0.0',
  locale: 'fil',
  query: 'magkano utang ni <CUSTOMER>',
  route_kind: 'answerIntent',
};

function recordingDatabase() {
  const stored = [];
  return {
    stored,
    prepare: () => ({ bind: (...values) => values }),
    batch: async (statements) => {
      stored.push(...statements);
    },
  };
}

function streamOf(chunks) {
  return new ReadableStream({
    start(controller) {
      for (const chunk of chunks) controller.enqueue(chunk);
      controller.close();
    },
  });
}

function streamingRequest(chunks) {
  return new Request(FEEDBACK_URL, {
    method: 'POST',
    body: streamOf(chunks),
    duplex: 'half',
  });
}

test('an endless body without a declared length stops being read at the limit', { timeout: 5000 }, async () => {
  const database = recordingDatabase();
  const chunk = new Uint8Array(16 * 1024).fill(0x20);
  let pulledBytes = 0;
  const endless = new ReadableStream({
    pull(controller) {
      pulledBytes += chunk.byteLength;
      controller.enqueue(chunk);
    },
  });
  const request = new Request(FEEDBACK_URL, { method: 'POST', body: endless, duplex: 'half' });
  assert.equal(request.headers.get('content-length'), null);
  const response = await worker.fetch(request, { FEEDBACK_DB: database });
  assert.equal(response.status, 413);
  assert.equal(database.stored.length, 0);
  assert.ok(pulledBytes <= MAXIMUM_BODY_BYTES + 4 * chunk.byteLength);
});

test('a streamed body split across chunks within the limit is stored', async () => {
  const database = recordingDatabase();
  const bytes = new TextEncoder().encode(JSON.stringify({ events: [validEvent] }));
  const middle = Math.floor(bytes.byteLength / 2);
  const request = streamingRequest([bytes.slice(0, middle), bytes.slice(middle)]);
  const response = await worker.fetch(request, { FEEDBACK_DB: database });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { accepted: [validEvent.id] });
  assert.equal(database.stored.length, 1);
});

test('a declared length over the limit is refused before reading', async () => {
  const request = new Request(FEEDBACK_URL, {
    method: 'POST',
    body: 'x',
    headers: { 'content-length': String(MAXIMUM_BODY_BYTES + 1) },
  });
  const response = await worker.fetch(request, { FEEDBACK_DB: recordingDatabase() });
  assert.equal(response.status, 413);
});

test('an empty body is refused as invalid json', async () => {
  const request = new Request(FEEDBACK_URL, { method: 'POST' });
  const response = await worker.fetch(request, { FEEDBACK_DB: recordingDatabase() });
  assert.equal(response.status, 400);
});
