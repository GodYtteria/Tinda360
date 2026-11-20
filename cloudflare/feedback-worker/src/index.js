import { storeFeedback } from './store.js';
import { MAXIMUM_BODY_BYTES, sanitizeBatch } from './validate.js';

const FEEDBACK_PATH = '/v1/feedback';
const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8' };

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

async function readLimitedText(request) {
  const declaredLength = Number(request.headers.get('content-length') ?? '0');
  if (declaredLength > MAXIMUM_BODY_BYTES) return null;
  if (request.body === null) return '';
  const reader = request.body.getReader();
  const chunks = [];
  let totalBytes = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > MAXIMUM_BODY_BYTES) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const buffer = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    buffer.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder('utf-8', { fatal: true }).decode(buffer);
}

async function isWithinRateLimit(request, environment) {
  if (environment.FEEDBACK_RATE_LIMITER === undefined) return true;
  const clientAddress = request.headers.get('cf-connecting-ip') ?? 'unknown';
  const { success } = await environment.FEEDBACK_RATE_LIMITER.limit({ key: clientAddress });
  return success;
}

export default {
  async fetch(request, environment) {
    const url = new URL(request.url);
    if (url.pathname !== FEEDBACK_PATH) return jsonResponse(404, { error: 'not found' });
    if (request.method !== 'POST') return jsonResponse(405, { error: 'method not allowed' });
    if (!(await isWithinRateLimit(request, environment))) {
      return jsonResponse(429, { error: 'too many requests' });
    }

    let text;
    try {
      text = await readLimitedText(request);
    } catch (error) {
      return jsonResponse(400, { error: 'body is not valid utf-8' });
    }
    if (text === null) return jsonResponse(413, { error: 'body too large' });

    let payload;
    try {
      payload = JSON.parse(text);
    } catch (error) {
      return jsonResponse(400, { error: 'body is not valid json' });
    }

    const batch = sanitizeBatch(payload);
    if (!batch.ok) return jsonResponse(400, { error: batch.reason });
    if (batch.accepted.length === 0) return jsonResponse(200, { accepted: [] });

    const receivedDay = new Date().toISOString().slice(0, 10);
    try {
      await storeFeedback(environment.FEEDBACK_DB, batch.accepted, receivedDay);
    } catch (error) {
      return jsonResponse(503, { error: 'storage unavailable' });
    }
    return jsonResponse(200, { accepted: batch.acceptedIdentifiers });
  },
};
