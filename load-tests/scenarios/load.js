import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '1m',  target: 50 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(99)<2000'],
    errors: ['rate<0.05'],
  },
};

const BASE = 'https://api.estateflowai.co';
const HEADERS = { 'Origin': 'https://www.estateflowai.co' };

export default function () {
  const users = http.get(`${BASE}/api/users`, { headers: HEADERS });
  check(users, { 'users 200': (r) => r.status === 200 });
  errorRate.add(users.status !== 200);
  sleep(0.5);

  const products = http.get(`${BASE}/api/products`, { headers: HEADERS });
  check(products, { 'products 200': (r) => r.status === 200 });
  errorRate.add(products.status !== 200);
  sleep(0.5);

  const orders = http.get(`${BASE}/api/orders`, { headers: HEADERS });
  check(orders, { 'orders 200': (r) => r.status === 200 });
  errorRate.add(orders.status !== 200);
  sleep(1);
}
