/** Email allowlist for the developer console. Not a cafe `admin` role. */

export function parseSuperadminEmails(
  env: NodeJS.ProcessEnv = process.env,
): Set<string> {
  const raw = env.SUPERADMIN_EMAILS ?? '';
  const emails = new Set<string>();
  for (const part of raw.split(',')) {
    const email = part.trim().toLowerCase();
    if (email.includes('@')) emails.add(email);
  }
  return emails;
}

export function isSuperadminEmail(
  email: string | null | undefined,
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  if (!email) return false;
  return parseSuperadminEmails(env).has(email.trim().toLowerCase());
}

/** Firebase email/password sign-in. Google (`google.com`) never counts. */
export function isEmailPasswordSignIn(
  authProvider?: string | null,
): boolean {
  const value = (authProvider ?? '').toLowerCase();
  return value === 'password' || value === 'email';
}

type SuperadminToken = {
  email?: string | null;
  authProvider?: string | null;
  emailVerified?: boolean;
};

export function isSuperadminSession(
  token: SuperadminToken | null | undefined,
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  if (!token) return false;
  return (
    isSuperadminEmail(token.email, env) &&
    isEmailPasswordSignIn(token.authProvider) &&
    token.emailVerified === true
  );
}

export function isPrivilegedActor(
  actor: { role: 'employee' | 'admin' },
  token?: SuperadminToken | null,
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  return actor.role === 'admin' || isSuperadminSession(token, env);
}

export function locationCodeFromName(name: string): string {
  const slug = name
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);
  return slug || 'location';
}
