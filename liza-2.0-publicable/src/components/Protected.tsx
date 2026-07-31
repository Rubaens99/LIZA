import React from 'react';
import { Navigate } from 'react-router-dom';
import { Profile, Role } from '../lib/types';
export default function Protected({ profile, role, children }: { profile: Profile | null; role: Role; children: React.ReactNode }) {
  if (!profile) return <Navigate to="/iniciar-sesion" replace />;
  if (profile.role !== role) return <Navigate to={profile.role === 'admin' ? '/admin' : '/paciente'} replace />;
  return <>{children}</>;
}
