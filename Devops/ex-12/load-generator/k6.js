import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  vus: 40,
  duration: '15m',
};

export default function () {
  const url = 'http://frontend.exercise-12.svc.cluster.local/order';
  const payload = JSON.stringify({
    order_id: `ord-${Math.floor(Math.random() * 1000000)}`,
    amount: parseFloat((Math.random() * 500).toFixed(2))
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  http.post(url, payload, params);
  
  // Sleep 10ms to avoid overloading CPU, but generate high transaction rate
  sleep(0.01);
}
