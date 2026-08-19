export type AuthenticatedUser = {
  uid: string;
  email?: string;
  name?: string;
  authProvider?: string;
  emailVerified?: boolean;
};
