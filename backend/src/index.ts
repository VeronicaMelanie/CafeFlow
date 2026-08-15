import 'dotenv/config';
import { prisma } from './db';
import { createApp } from './app';
import { getFirebaseAuth } from './firebase';
import { createFirebaseTokenVerifier } from './auth/verifyToken';

const port = Number(process.env.PORT) || 3000;
const app = createApp(createFirebaseTokenVerifier(getFirebaseAuth()));

const server = app.listen(port, () => {
  console.log(`CafeFlow API listening on http://127.0.0.1:${port}`);
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
