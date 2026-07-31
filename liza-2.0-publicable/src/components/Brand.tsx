import React from 'react';

export default function Brand({ compact = false }: { compact?: boolean }) {
  return <a className="brand" href="/">
    <span className="logo-mark" aria-label="Logotipo LIZA">L</span>
    {!compact && <span><strong>Consultorio Psicológico</strong><small>LIZA</small></span>}
  </a>;
}
