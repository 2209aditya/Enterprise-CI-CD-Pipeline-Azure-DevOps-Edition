import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 50,                // virtual users
  duration: '2m',         // test duration
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% requests < 500ms
    http_req_failed: ['rate<0.01'],   // <1% errors
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  let res = http.get(`${BASE_URL}/api/v1/videos`);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);
}
