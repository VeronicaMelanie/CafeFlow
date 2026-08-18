import 'dotenv/config';
import { prisma } from './db.js';
import { createApp } from './app.js';
import { getFirebaseAuth } from './firebase.js';
import { createFirebaseTokenVerifier } from './auth/verifyToken.js';

const port = Number(process.env.PORT) || 3000;
const host = process.env.HOST || '0.0.0.0';
const app = createApp(createFirebaseTokenVerifier(getFirebaseAuth()));

const server = app.listen(port, host, () => {
  console.log(`CafeFlow API listening on http://${host}:${port}`);
});

async function shutdown() {
  server.close();
  await prisma.$disconnect();
}

process.on('SIGINT', () => {
  void shutdown();
});
process.on('SIGTERM', () => {
  void shutdown();
});
