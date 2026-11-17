// Run with Node.js to regenerate the independently encrypted Dart fixtures.
const {createCipheriv, pbkdf2Sync} = require('node:crypto');

const password = 'frasa uji e\u0301 🔐';
const createdAt = '2026-11-17T08:00:00.000Z';
const timestamp = Date.parse(createdAt) * 1000;
const record = (id, kind) => ({
  id, kind, parent_id: null, revision: 1,
  created_at_us: timestamp, updated_at_us: timestamp,
});
const entities = [
  {
    record: record('fixture-profile', 'profile'),
    data: {
      id: 'fixture-profile', singleton: 1, name: 'Rana 🔖',
      notifications_enabled: 0, week_starts_on: 7, default_buffer_us: null,
      quiet_start_min: null, quiet_end_min: null, active_hours: '{}',
      activity_preferences: '{}', onboarding_completed: 1, onboarding_step: 2,
      preferences: JSON.stringify({calendarZoneId: 'Asia/Jakarta', backupReminderDays: 14}),
    },
  },
  {
    record: record('fixture-task', 'task'),
    data: {
      id: 'fixture-task', title: 'Catatan cafe\u0301 ☕', category_id: null,
      description: null, priority: null, status: 'planned', initial_estimate_us: null,
      confirmed_remaining_us: null, remaining_actual_us: null,
      minimum_session_minutes: null, maximum_sessions: null, remaining_confirmed_at_us: null,
      deadline_us: Date.parse('2026-11-17T15:30:00.000Z') * 1000,
      deadline_zone: 'Asia/Jakarta', deadline_mode: 'localWallTime',
      deadline_local: '2026-11-17T22:30:00.000',
    },
  },
];
const counts = Object.fromEntries([
  'profile', 'category', 'eventSeries', 'eventOccurrence', 'task', 'subtask',
  'workSession', 'routine', 'routineOccurrence', 'timeLog', 'reminderRule',
  'statusHistory', 'trashEntry',
].map(kind => [kind, Number(kind === 'profile' || kind === 'task')]));
const manifest = {application: 'routina', schemaVersion: 9, createdAt, counts};

const fixtures = [
  ['legacyV1', {manifest, entities}],
  ['incorrectManifestV1', {manifest: {...manifest, counts: {...counts, task: 0}}, entities}],
  ['duplicateIdV1', {manifest, entities: [...entities, entities[1]]}],
];

for (const [index, [name, payload]] of fixtures.entries()) {
  // Fixture-only salt/nonce. Each payload gets a different key and nonce.
  const salt = Buffer.from(Array.from({length: 16}, (_, i) => 28 * index + i));
  const nonce = Buffer.from(Array.from({length: 12}, (_, i) => 28 * index + 16 + i));
  const header = Buffer.alloc(42);
  header.write('ROUTBKUP', 0, 'ascii');
  header[8] = header[9] = 1;
  header.writeUInt32BE(600000, 10);
  salt.copy(header, 14);
  nonce.copy(header, 30);
  const key = pbkdf2Sync(Buffer.from(password, 'utf8'), salt, 600000, 32, 'sha256');
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  cipher.setAAD(header);
  const body = Buffer.concat([cipher.update(JSON.stringify(payload), 'utf8'), cipher.final()]);
  const bytes = Buffer.concat([header, body, cipher.getAuthTag()]);
  console.log("const " + name + " = '" + bytes.toString('base64') + "';");
}
