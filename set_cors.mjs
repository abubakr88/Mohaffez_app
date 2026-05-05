import { Storage } from '@google-cloud/storage';

const storage = new Storage();
const bucket = storage.bucket('mohaffez-ba2ec.firebasestorage.app');

await bucket.setCorsConfiguration([
  {
    origin: ['http://localhost:*', 'https://app.mohafezy.com'],
    method: ['GET'],
    maxAgeSeconds: 3600,
  },
]);

console.log('CORS set successfully.');
