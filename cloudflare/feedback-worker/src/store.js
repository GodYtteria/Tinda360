const INSERT_FEEDBACK = `INSERT OR IGNORE INTO feedback
  (id, received_day, created_day, app_version, locale, query, route_kind,
   tool, confidence, chosen_tool, rating)
  VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)`;

export function feedbackRow(event, receivedDay) {
  return [
    event.id,
    receivedDay,
    event.created_day,
    event.app_version,
    event.locale,
    event.query,
    event.route_kind,
    event.tool ?? null,
    event.confidence ?? null,
    event.chosen_tool ?? null,
    event.rating ?? null,
  ];
}

export async function storeFeedback(database, events, receivedDay) {
  const statement = database.prepare(INSERT_FEEDBACK);
  await database.batch(
    events.map((event) => statement.bind(...feedbackRow(event, receivedDay))),
  );
}
