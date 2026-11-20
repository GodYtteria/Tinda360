import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  MAXIMUM_EVENTS_PER_REQUEST,
  MAXIMUM_QUERY_LENGTH,
  sanitizeBatch,
  sanitizeEvent,
} from '../src/validate.js';

const validEvent = () => ({
  id: '0123456789abcdef0123456789abcdef',
  created_day: '2026-11-20',
  app_version: '1.0.0+1',
  locale: 'fil',
  query: 'magkano utang ni <CUSTOMER>',
  route_kind: 'answerIntent',
  tool: 'get_utang_list',
  confidence: 0.83,
  rating: 'down',
});

test('a valid event is kept with only the allowed fields', () => {
  const sanitized = sanitizeEvent({ ...validEvent(), device_id: 'abc', store_name: 'Aling Nena' });
  assert.deepEqual(sanitized, validEvent());
});

test('optional fields may be absent', () => {
  const { tool, confidence, rating, ...required } = validEvent();
  assert.deepEqual(sanitizeEvent(required), required);
});

test('a chosen tool is kept when valid', () => {
  const sanitized = sanitizeEvent({ ...validEvent(), chosen_tool: 'get_profit_margins' });
  assert.equal(sanitized.chosen_tool, 'get_profit_margins');
});

test('events with a bad required field are rejected', () => {
  const badValues = {
    id: ['', 'not-hex', 'ABCDEF0123456789', 42, null],
    created_day: ['20261120', '2026-11-20T10:00:00Z', 5],
    app_version: ['', 'x'.repeat(21), '1.0 0'],
    locale: ['', 'fil ph', 'x'.repeat(11)],
    query: ['', 'x'.repeat(MAXIMUM_QUERY_LENGTH + 1), 7, null],
    route_kind: ['', 'answer', 'ANSWERINTENT'],
  };
  for (const [field, values] of Object.entries(badValues)) {
    for (const value of values) {
      assert.equal(sanitizeEvent({ ...validEvent(), [field]: value }), null, `${field}=${value}`);
    }
    const { [field]: removed, ...withoutField } = validEvent();
    assert.equal(sanitizeEvent(withoutField), null, `${field} missing`);
  }
});

test('events with a bad optional field are rejected', () => {
  assert.equal(sanitizeEvent({ ...validEvent(), tool: 'drop table' }), null);
  assert.equal(sanitizeEvent({ ...validEvent(), chosen_tool: 5 }), null);
  assert.equal(sanitizeEvent({ ...validEvent(), confidence: 1.5 }), null);
  assert.equal(sanitizeEvent({ ...validEvent(), confidence: Number.NaN }), null);
  assert.equal(sanitizeEvent({ ...validEvent(), confidence: '0.5' }), null);
  assert.equal(sanitizeEvent({ ...validEvent(), rating: 'meh' }), null);
});

test('non-object candidates are rejected', () => {
  for (const candidate of [null, undefined, 'text', 5, [], [validEvent()]]) {
    assert.equal(sanitizeEvent(candidate), null);
  }
});

test('long digit runs are redacted and short amounts are kept', () => {
  const phone = sanitizeEvent({ ...validEvent(), query: 'tawagan si 0917 123 4567 at 0917-123-4567' });
  assert.equal(phone.query, 'tawagan si <NUMBER> at <NUMBER>');
  const amount = sanitizeEvent({ ...validEvent(), query: 'utang na lampas 500 o 123456' });
  assert.equal(amount.query, 'utang na lampas 500 o 123456');
});

test('a batch keeps valid events, drops invalid ones and duplicate ids', () => {
  const second = { ...validEvent(), id: 'fedcba9876543210' };
  const batch = sanitizeBatch({
    events: [validEvent(), { ...validEvent(), query: '' }, second, validEvent()],
  });
  assert.equal(batch.ok, true);
  assert.deepEqual(batch.acceptedIdentifiers, [validEvent().id, second.id]);
  assert.equal(batch.accepted.length, 2);
});

test('malformed batches are refused', () => {
  assert.equal(sanitizeBatch(null).ok, false);
  assert.equal(sanitizeBatch({}).ok, false);
  assert.equal(sanitizeBatch({ events: 'x' }).ok, false);
  assert.equal(sanitizeBatch({ events: [] }).ok, false);
  const tooMany = Array.from({ length: MAXIMUM_EVENTS_PER_REQUEST + 1 }, validEvent);
  assert.equal(sanitizeBatch({ events: tooMany }).ok, false);
});

test('a batch of only invalid events is accepted as empty', () => {
  const batch = sanitizeBatch({ events: [{ nope: true }] });
  assert.equal(batch.ok, true);
  assert.deepEqual(batch.accepted, []);
});

test('phone numbers with dots, slashes or brackets are redacted on the server', () => {
  for (const phone of ['0917.123.4567', '0917/123/4567', '(0917) 123-4567']) {
    const sanitized = sanitizeEvent({ ...validEvent(), query: `tawag ${phone} bukas` });
    assert.equal(sanitized.query, 'tawag <NUMBER> bukas', phone);
  }
});
