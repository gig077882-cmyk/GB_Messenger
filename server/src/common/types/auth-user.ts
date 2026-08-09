export interface AuthUser {
  id: string;
  email: string;
}

export interface AuthenticatedSocketUser extends AuthUser {
  deviceId?: string;
}
