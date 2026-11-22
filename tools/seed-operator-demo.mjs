import { setTimeout as delay } from 'node:timers/promises';

const origin = 'http://127.0.0.1:8090';
const [username, sourcePort] = process.argv.slice(2);
const port = Number(sourcePort);
if (!username || !Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('The local operator demo requires a username and simulator port.');
}

let password = '';
for await (const chunk of process.stdin) password += chunk;
password = password.trimEnd();

async function request(path, options = {}) {
  const response = await fetch(origin + '/telemetry' + path, {
    ...options,
    redirect: 'error',
    signal: AbortSignal.timeout(2000)
  });
  if (!response.ok) throw new Error(`Demo setup ${path} returned HTTP ${response.status}.`);
  return response;
}

const login = await request('/auth/login', {
  method: 'POST',
  headers: { Origin: origin, 'Content-Type': 'application/json' },
  body: JSON.stringify({ username, password })
});
const { csrf, user } = await login.json();
const cookie = login.headers.get('set-cookie')?.split(';', 1)[0];
if (!csrf || !cookie || user?.role !== 'operator') throw new Error('Operator demo authentication failed.');
const headers = { Origin: origin, Cookie: cookie, 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' };

const benchCheck = {
  schemaVersion: 1,
  name: 'INA226 bench check',
  steps: [
    { id: 'read-calibration', type: 'registerRead', command: { type: 'i2c_read', addr: '0x40', reg: '0x05', len: 2 } },
    {
      id: 'check-calibration',
      type: 'if',
      condition: { op: '==', left: { step: 'read-calibration' }, right: { constant: 0x0a00, unit: 'hex' } },
      then: [{ id: 'calibration-ok', type: 'message', message: 'Calibration matches the bench profile.' }],
      else: [{ id: 'calibration-different', type: 'message', message: 'Calibration differs from the bench profile.' }]
    },
    { id: 'capture-telemetry', type: 'delay', durationMs: 1500 },
    { id: 'read-bus-voltage', type: 'registerRead', command: { type: 'i2c_read', addr: '0x40', reg: '0x02', len: 2 } }
  ]
};

try {
  const deadline = Date.now() + 5000;
  let ready = false;
  while (Date.now() < deadline) {
    const { latest } = await (await request('/latest', { headers })).json();
    ready = latest?.packet?.device_id === 'portfolio-simulator' &&
      latest.network?.remote_address === '127.0.0.1' && latest.network?.remote_port === port;
    if (ready) break;
    await delay(100);
  }
  if (!ready) throw new Error('The local simulator did not produce telemetry from its assigned port.');
  await request('/sequences', { method: 'POST', headers, body: JSON.stringify(benchCheck) });
} finally {
  await request('/auth/logout', { method: 'POST', headers });
}
