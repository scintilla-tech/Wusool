// k6 smoke test: liveness, readiness, and login for each role (login once per VU).
import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, CREDENTIALS, authHeaders, login } from './config.js';

export const options = {
  vus: 1,
  duration: '20s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
};

const ROOT = BASE_URL.replace('/api/v1', '');
let tokens = null;

export default function () {
  const live = http.get(`${ROOT}/health/live`);
  check(live, { 'live 200': (r) => r.status === 200 });

  const ready = http.get(`${ROOT}/health/ready`);
  check(ready, { 'ready 200': (r) => r.status === 200 });

  if (!tokens) {
    tokens = {};
    for (const role of ['admin', 'driver', 'student']) {
      tokens[role] = login(http, CREDENTIALS[role]);
      check(tokens[role], { [`${role} login`]: (t) => !!t });
    }
  }

  for (const role of ['admin', 'driver', 'student']) {
    if (tokens[role]) {
      const me = http.get(`${BASE_URL}/auth/me`, authHeaders(tokens[role]));
      check(me, { [`${role} me 200`]: (r) => r.status === 200 });
    }
  }
  sleep(1);
}
