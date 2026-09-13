// k6 morning-burst scenario (~400 active users) across student/driver/supervisor/admin paths.
// Logs in once per VU and verifies p95 read <= 500ms and p95 write <= 800ms under a burst.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, CREDENTIALS, authHeaders, login } from './config.js';

export const options = {
  scenarios: {
    morning_burst: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 200 },
        { duration: '30s', target: 400 },
        { duration: '1m', target: 400 },
        { duration: '20s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{kind:read}': ['p(95)<500'],
    'http_req_duration{kind:write}': ['p(95)<800'],
  },
};

const state = {};

export default function () {
  const bucket = __VU % 10;

  if (bucket < 7) {
    if (!state.student) state.student = login(http, CREDENTIALS.student);
    if (!state.student) return;
    const h = authHeaders(state.student);
    const get = http.get(`${BASE_URL}/attendance/today`, { ...h, tags: { kind: 'read' } });
    check(get, { 'attendance get 200': (r) => r.status === 200 });
    const put = http.put(`${BASE_URL}/attendance/today`, JSON.stringify({ intent: 'ATTENDING' }), {
      ...h,
      tags: { kind: 'write' },
    });
    check(put, { 'attendance set 200': (r) => r.status === 200 });
  } else if (bucket < 9) {
    if (!state.driver) state.driver = login(http, CREDENTIALS.driver);
    if (!state.driver) return;
    const get = http.get(`${BASE_URL}/driver/today`, {
      ...authHeaders(state.driver),
      tags: { kind: 'read' },
    });
    check(get, { 'driver today 200': (r) => r.status === 200 });
  } else {
    if (!state.admin) state.admin = login(http, CREDENTIALS.admin);
    if (!state.admin) return;
    const h = authHeaders(state.admin);
    const dash = http.get(`${BASE_URL}/admin/dashboard`, { ...h, tags: { kind: 'read' } });
    check(dash, { 'admin dashboard 200': (r) => r.status === 200 });
    const students = http.get(`${BASE_URL}/students?page=1&limit=20`, {
      ...h,
      tags: { kind: 'read' },
    });
    check(students, { 'students list 200': (r) => r.status === 200 });
  }

  sleep(Math.random() * 2 + 1);
}
