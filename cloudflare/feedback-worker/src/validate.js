export const MAXIMUM_EVENTS_PER_REQUEST = 50;
export const MAXIMUM_BODY_BYTES = 64 * 1024;
export const MAXIMUM_QUERY_LENGTH = 300;

const MAXIMUM_VERSION_LENGTH = 20;
const MAXIMUM_LOCALE_LENGTH = 10;
const MINIMUM_DIGIT_RUN_TO_REDACT = 7;
const NUMBER_PLACEHOLDER = '<NUMBER>';

const IDENTIFIER_PATTERN = /^[a-f0-9]{16,64}$/;
const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const VERSION_PATTERN = /^[0-9A-Za-z.+-]+$/;
const LOCALE_PATTERN = /^[A-Za-z_-]+$/;
const TOOL_PATTERN = /^(get_[a-z_]{3,40}|no_tool)$/;
const LONG_DIGIT_RUN_PATTERN = new RegExp(
  `\\d(?:[\\s-]?\\d){${MINIMUM_DIGIT_RUN_TO_REDACT - 1},}`,
  'g',
);

const ROUTE_KINDS = new Set(['answerIntent', 'outOfScope', 'askModel', 'clarify']);
const RATINGS = new Set(['up', 'down']);

function isBoundedString(value, maximumLength, pattern) {
  return (
    typeof value === 'string' &&
    value.length > 0 &&
    value.length <= maximumLength &&
    (pattern === undefined || pattern.test(value))
  );
}

function optionalTool(value) {
  if (value === undefined || value === null) return { ok: true, value: undefined };
  return typeof value === 'string' && TOOL_PATTERN.test(value)
    ? { ok: true, value }
    : { ok: false };
}

export function sanitizeEvent(candidate) {
  if (candidate === null || typeof candidate !== 'object' || Array.isArray(candidate)) {
    return null;
  }
  if (!isBoundedString(candidate.id, 64, IDENTIFIER_PATTERN)) return null;
  if (!isBoundedString(candidate.created_day, 10, DAY_PATTERN)) return null;
  if (!isBoundedString(candidate.app_version, MAXIMUM_VERSION_LENGTH, VERSION_PATTERN)) {
    return null;
  }
  if (!isBoundedString(candidate.locale, MAXIMUM_LOCALE_LENGTH, LOCALE_PATTERN)) return null;
  if (!isBoundedString(candidate.query, MAXIMUM_QUERY_LENGTH)) return null;
  if (!ROUTE_KINDS.has(candidate.route_kind)) return null;

  const tool = optionalTool(candidate.tool);
  const chosenTool = optionalTool(candidate.chosen_tool);
  if (!tool.ok || !chosenTool.ok) return null;

  const hasConfidence = candidate.confidence !== undefined && candidate.confidence !== null;
  if (
    hasConfidence &&
    (typeof candidate.confidence !== 'number' ||
      !Number.isFinite(candidate.confidence) ||
      candidate.confidence < 0 ||
      candidate.confidence > 1)
  ) {
    return null;
  }

  const hasRating = candidate.rating !== undefined && candidate.rating !== null;
  if (hasRating && !RATINGS.has(candidate.rating)) return null;

  const sanitized = {
    id: candidate.id,
    created_day: candidate.created_day,
    app_version: candidate.app_version,
    locale: candidate.locale,
    query: candidate.query.replace(LONG_DIGIT_RUN_PATTERN, NUMBER_PLACEHOLDER),
    route_kind: candidate.route_kind,
  };
  if (tool.value !== undefined) sanitized.tool = tool.value;
  if (hasConfidence) sanitized.confidence = candidate.confidence;
  if (chosenTool.value !== undefined) sanitized.chosen_tool = chosenTool.value;
  if (hasRating) sanitized.rating = candidate.rating;
  return sanitized;
}

export function sanitizeBatch(payload) {
  if (payload === null || typeof payload !== 'object' || !Array.isArray(payload.events)) {
    return { ok: false, reason: 'events must be an array' };
  }
  if (payload.events.length === 0) return { ok: false, reason: 'no events' };
  if (payload.events.length > MAXIMUM_EVENTS_PER_REQUEST) {
    return { ok: false, reason: 'too many events' };
  }
  const accepted = [];
  const acceptedIdentifiers = [];
  const seen = new Set();
  for (const candidate of payload.events) {
    const sanitized = sanitizeEvent(candidate);
    if (sanitized === null || seen.has(sanitized.id)) continue;
    seen.add(sanitized.id);
    accepted.push(sanitized);
    acceptedIdentifiers.push(sanitized.id);
  }
  return { ok: true, accepted, acceptedIdentifiers };
}
