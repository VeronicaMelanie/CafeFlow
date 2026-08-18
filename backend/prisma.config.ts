import 'dotenv/config';
import { defineConfig } from 'prisma/config';

// prisma generate does not connect to the database. A placeholder lets Render
// build without exposing DATABASE_URL at build time. Runtime still requires
// the real URL in db.ts.
const datasourceUrl =
  process.env.DATABASE_URL ??
  'postgresql://prisma:prisma@127.0.0.1:5432/prisma';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: datasourceUrl,
  },
});
