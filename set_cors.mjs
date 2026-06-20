import { Storage } from '@google-cloud/storage';

const storage = new Storage();
const bucket = storage.bucket('mohaffez-ba2ec.firebasestorage.app');

await bucket.setCorsConfiguration([
  {
    origin: [
      'http://localhost:*',
      'https://app.mohafezy.com',
      'https://admin.mohafezy.com',
      'https://mohafezy.com',
    ],
    method: ['GET', 'HEAD', 'POST', 'PUT', 'DELETE'],
    responseHeader: [
      'Content-Type',
      'Content-Length',
      'Authorization',
      'x-goog-resumable',
      'x-goog-upload-command',
      'x-goog-upload-offset',
      'x-goog-upload-status',
      'x-goog-upload-url',
    ],
    maxAgeSeconds: 3600,
  },
]);

console.log('CORS set successfully.');
