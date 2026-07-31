import React, { FormEvent, useState } from 'react';
import { supabase } from '../lib/supabase';

export function AuthForm({ mode }: { mode: 'login' | 'register' }) {
  const [message, setMessage] = useState(''); const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault(); setBusy(true); setMessage(''); const data = new FormData(e.currentTarget);
    const email = String(data.get('email')); const password = String(data.get('password'));
    const result = mode === 'login'
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({ email, password, options: { data: { full_name: String(data.get('full_name')), phone: String(data.get('phone') || ''), birth_date: String(data.get('birth_date') || '') } } });
    setBusy(false);
    if (result.error) setMessage(result.error.message);
    else setMessage(mode === 'register' ? 'Cuenta creada. Revisa tu correo para confirmar el registro antes de iniciar sesión.' : 'Sesión iniciada.');
  }
  return <form className="card auth-form" onSubmit={submit}>
    <p className="eyebrow">{mode === 'login' ? 'Acceso seguro' : 'Primer paso'}</p>
    <h1>{mode === 'login' ? 'Iniciar sesión' : 'Crear cuenta'}</h1>
    {mode === 'register' && <><label>Nombre completo<input name="full_name" required autoComplete="name" /></label><label>Teléfono<input name="phone" autoComplete="tel" /></label><label>Fecha de nacimiento<input name="birth_date" type="date" /></label></>}
    <label>Correo electrónico<input name="email" type="email" required autoComplete="email" /></label>
    <label>Contraseña<input name="password" type="password" minLength={8} required autoComplete={mode === 'login' ? 'current-password' : 'new-password'} /></label>
    <button className="button" disabled={busy}>{busy ? 'Procesando…' : mode === 'login' ? 'Entrar' : 'Registrarme'}</button>
    {message && <p className="notice">{message}</p>}
  </form>;
}
