import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { describe, it } from 'node:test';

const require = createRequire(import.meta.url);
const { assertImportDatabaseUrl } = require('../scripts/import-preview.cjs') as {
  assertImportDatabaseUrl: (databaseUrl: string) => URL;
};

describe('import-preview DATABASE_URL', () => {
  it('accepts local CafeFlow Postgres', () => {
    const parsed = assertImportDatabaseUrl(
      'postgresql://postgres@127.0.0.1:5432/cafeflow',
    );
    assert.equal(parsed.hostname, '127.0.0.1');
    assert.equal(parsed.pathname, '/cafeflow');
  });

  it('accepts a remote URL with sslmode=require without hardcoding the host', () => {
    const parsed = assertImportDatabaseUrl(
      'postgresql://owner:secret@db.example.internal/neondb?sslmode=require',
    );
    assert.equal(parsed.hostname, 'db.example.internal');
    assert.equal(parsed.pathname, '/neondb');
  });

  it('rejects a remote URL without SSL', () => {
    assert.throws(
      () =>
        assertImportDatabaseUrl(
          'postgresql://owner:secret@db.example.internal/neondb',
        ),
      /sslmode=require/,
    );
  });

  it('rejects a non-postgres URL', () => {
    assert.throws(
      () => assertImportDatabaseUrl('mysql://127.0.0.1:3306/cafeflow'),
      /postgresql:\/\//,
    );
  });
});
