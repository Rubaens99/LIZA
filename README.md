# Consultorio Psicológico LIZA 2.0

Aplicación React + Vite conectada a Supabase Auth y PostgreSQL con Row Level Security (RLS). Los enlaces oficiales se conservan para [TikTok](https://www.tiktok.com/@psicologeando.con.liza?_r=1&_t=ZS-98TefeOYUKK) y [Facebook](https://www.facebook.com/share/1HaP7qypdn/).

## Puesta en marcha

1. Crea un proyecto en [Supabase](https://supabase.com/dashboard) y ejecuta por completo `supabase/schema.sql` en **SQL Editor**.
2. En **Authentication > URL Configuration**, añade `http://localhost:5173` como Site URL y Redirect URL durante desarrollo. Configura un proveedor de correo real antes de producción.
3. Copia `.env.example` como `.env.local`, completa la URL del proyecto y su clave pública `anon`. No uses la clave `service_role` en este proyecto.
4. Instala dependencias con `npm install` y ejecuta `npm run dev`.
5. Registra la cuenta de LIZA desde la página. En Supabase > Authentication copia el UUID de esa usuaria y ejecuta la línea de promoción a admin comentada al final de `supabase/schema.sql`. Luego inicia sesión: se redirigirá a `/admin`.

## Rutas

- `/`: sitio público y blog publicado.
- `/registro` y `/iniciar-sesion`: Supabase Auth.
- `/paciente`: cuestionarios asignados y citas del paciente autenticado.
- `/admin`: gestión de pacientes, asignaciones, citas, publicaciones y resultados.
- `/admin/paciente/:id`: expediente clínico editable, exclusivamente para administración.

## Seguridad clínica

- Todas las tablas tienen RLS activado.
- Los pacientes **no pueden leer** `clinical_records` ni `questionnaire_attempts` (respuestas o puntuaciones); ni siquiera mediante llamadas manuales a la API.
- Las respuestas se ingresan solamente mediante la función SQL `submit_questionnaire_attempt`, que valida que la asignación corresponde al paciente y calcula la calificación del lado del servidor.
- El rol se asigna en la base de datos y no está presente en el frontend. La clave pública de Supabase puede estar en el navegador: RLS es lo que protege los datos.
- Para producción, restringe los dominios de redirección, habilita confirmación de correo, MFA para administradores, copias de seguridad, bitácora de acceso y revisa la normativa aplicable (privacidad y expedientes clínicos) con asesoría profesional.

## Logotipo

El adjunto original no está disponible dentro de este directorio de trabajo. La interfaz usa una marca temporal integrada (`src/components/Brand.tsx`) en los tonos solicitados. Cuando tengas el archivo del logo, colócalo como `public/logo-liza.png` y sustituye el `span.logo-mark` del componente `Brand` por una etiqueta `img`; no afecta autenticación ni seguridad.
