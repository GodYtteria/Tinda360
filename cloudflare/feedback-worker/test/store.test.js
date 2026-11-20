import assert from 'node:assert/strict';
import { test } from 'node:test';

import { feedbackRow, storeFeedback } from '../src/store.js';

const fullEvent = {
  id: '0123456789abcdef',
  created_day: '2026-11-20',
  app_version: '1.0.0',
  locale: 'fil',
  query: 'magkano utang ni <CUSTOMER>',
  route_kind: 'clarify',
  tool: 'get_utang_list',
  confidence: 0.4,
  chosen_tool: 'get_utang_risk',
  rating: 'up',
};

test('a full event maps to the column order of the insert', () => {
  assert.deepEqual(feedbackRow(fullEvent, '2026-11-21'), [
    '0123456789abcdef',
    '2026-11-21',
    '2026-11-20',
    '1.0.0',
    'fil',
    'magkano utang ni <CUSTOMER>',
    'clarify',
    'get_utang_list',
    0.4,
    'get_utang_risk',
    'up',
  ]);
});

test('missing optional fields become null, not undefined', () => {
  const { tool, confidence, chosen_tool, rating, ...required } = fullEvent;
  const row = feedbackRow(required, '2026-11-21');
  assert.deepEqual(row.slice(7), [null, null, null, null]);
  assert.equal(row.includes(undefined), false);
});

test('every event is bound once and sent as one batch', async () => {
  const bound = [];
  let batches = 0;
  const database = {
    prepare: (sql) => {
      assert.match(sql, /INSERT OR IGNORE INTO feedback/);
      return { bind: (...values) => (bound.push(values), { values }) };
    },
    batch: async (statements) => {
      batches += 1;
      assert.equal(statements.length, 2);
    },
  };
  const second = { ...fullEvent, id: 'fedcba9876543210' };
  await storeFeedback(database, [fullEvent, second], '2026-11-21');
  assert.equal(batches, 1);
  assert.deepEqual(bound.map((values) => values[0]), [fullEvent.id, second.id]);
});

test('a storage failure reaches the caller', async () => {
  const database = {
    prepare: () => ({ bind: () => ({}) }),
    batch: async () => {
      throw new Error('d1 down');
    },
  };
  await assert.rejects(storeFeedback(database, [fullEvent], '2026-11-21'), /d1 down/);
});
