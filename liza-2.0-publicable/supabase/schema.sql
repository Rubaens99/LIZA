-- Consultorio Psicológico LIZA 2.0
-- Ejecuta este archivo completo en Supabase Dashboard > SQL Editor.
-- La service_role NUNCA se usa en el navegador.

create extension if not exists pgcrypto;
create type public.app_role as enum ('admin', 'patient');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '', phone text, birth_date date,
  role public.app_role not null default 'patient', created_at timestamptz not null default now()
);
create table public.questionnaires (
  id uuid primary key default gen_random_uuid(), title text not null, description text,
  questions jsonb not null default '[]'::jsonb, is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.questionnaire_assignments (
  id uuid primary key default gen_random_uuid(), patient_id uuid not null references public.profiles(id) on delete cascade,
  questionnaire_id uuid not null references public.questionnaires(id) on delete restrict,
  due_date date, can_retake boolean not null default false, status text not null default 'assigned' check (status in ('assigned','completed')),
  assigned_at timestamptz not null default now()
);
create table public.questionnaire_attempts (
  id uuid primary key default gen_random_uuid(), assignment_id uuid not null references public.questionnaire_assignments(id) on delete cascade,
  answers jsonb not null, score numeric not null, max_score numeric not null, submitted_at timestamptz not null default now()
);
create table public.clinical_records (
  patient_id uuid primary key references public.profiles(id) on delete cascade,
  initial_interview text, objectives text, conceptualization text, treatment text, clinical_notes text,
  updated_at timestamptz not null default now(), updated_by uuid references public.profiles(id)
);
create table public.appointments (
  id uuid primary key default gen_random_uuid(), patient_id uuid not null references public.profiles(id) on delete cascade,
  title text not null, starts_at timestamptz not null, notes text, created_at timestamptz not null default now()
);
create table public.blog_posts (
  id uuid primary key default gen_random_uuid(), title text not null, category text not null, body text not null,
  published boolean not null default false, published_at timestamptz, created_at timestamptz not null default now()
);
create index assignments_patient_idx on public.questionnaire_assignments(patient_id);
create index attempts_assignment_idx on public.questionnaire_attempts(assignment_id);
create index appointments_patient_idx on public.appointments(patient_id, starts_at);

-- Profile provisioning: user-controlled metadata is copied once; role is always patient.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles (id, full_name, phone, birth_date)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), nullif(new.raw_user_meta_data->>'phone',''), nullif(new.raw_user_meta_data->>'birth_date','')::date);
  return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Helper avoids RLS recursion. It is not exposed as a table and uses the caller's UID.
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role='admin'); $$;

alter table public.profiles enable row level security;
alter table public.questionnaires enable row level security;
alter table public.questionnaire_assignments enable row level security;
alter table public.questionnaire_attempts enable row level security;
alter table public.clinical_records enable row level security;
alter table public.appointments enable row level security;
alter table public.blog_posts enable row level security;

-- Profiles: patients access only themselves; admin accesses all. Role is protected below by column grants.
create policy "profile own read" on public.profiles for select using (id=auth.uid() or public.is_admin());
create policy "profile own update" on public.profiles for update using (id=auth.uid() or public.is_admin()) with check (id=auth.uid() or public.is_admin());
revoke update(role) on public.profiles from anon, authenticated;
grant update(full_name,phone,birth_date) on public.profiles to authenticated;

create policy "questionnaire active read" on public.questionnaires for select using (is_active or public.is_admin());
create policy "questionnaire admin write" on public.questionnaires for all using (public.is_admin()) with check (public.is_admin());
create policy "assignment patient read" on public.questionnaire_assignments for select using (patient_id=auth.uid() or public.is_admin());
create policy "assignment admin write" on public.questionnaire_assignments for insert with check (public.is_admin());
create policy "assignment admin update" on public.questionnaire_assignments for update using (public.is_admin()) with check (public.is_admin());
create policy "assignment admin delete" on public.questionnaire_assignments for delete using (public.is_admin());

-- Attempts contain questionnaire answers and scores: never readable by patients.
create policy "attempt admin only" on public.questionnaire_attempts for select using (public.is_admin());
create policy "attempt admin delete" on public.questionnaire_attempts for delete using (public.is_admin());

-- Strict clinical-record isolation: only admin. Patients have no select, insert, update or delete policy.
create policy "clinical admin only" on public.clinical_records for all using (public.is_admin()) with check (public.is_admin());
create policy "appointments patient read" on public.appointments for select using (patient_id=auth.uid() or public.is_admin());
create policy "appointments admin manage" on public.appointments for all using (public.is_admin()) with check (public.is_admin());
create policy "blog public read published" on public.blog_posts for select using (published or public.is_admin());
create policy "blog admin manage" on public.blog_posts for all using (public.is_admin()) with check (public.is_admin());

-- Only this controlled function inserts attempts. Score is calculated server-side from stored question options.
create or replace function public.submit_questionnaire_attempt(p_assignment_id uuid, p_answers jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_assignment public.questionnaire_assignments; v_questions jsonb; v_score numeric:=0; v_max numeric:=0; v_question_max numeric:=0; v_answer jsonb; v_question jsonb; v_value numeric; v_id uuid;
begin
  select * into v_assignment from public.questionnaire_assignments where id=p_assignment_id for update;
  if not found or v_assignment.patient_id<>auth.uid() then raise exception 'Cuestionario no disponible'; end if;
  if v_assignment.status='completed' and not v_assignment.can_retake then raise exception 'Este cuestionario no está habilitado para otra respuesta'; end if;
  select questions into v_questions from public.questionnaires where id=v_assignment.questionnaire_id and is_active=true;
  if v_questions is null then raise exception 'Cuestionario no disponible'; end if;
  for v_question in select * from jsonb_array_elements(v_questions) loop
    select value into v_answer from jsonb_array_elements(p_answers) where value->>'question_id'=v_question->>'id' limit 1;
    if v_answer is null then raise exception 'Falta una respuesta'; end if;
    v_value := (v_answer->>'value')::numeric;
    if not exists(select 1 from jsonb_array_elements(v_question->'options') o where (o->>'value')::numeric=v_value) then raise exception 'Respuesta no válida'; end if;
    v_score:=v_score+v_value;
    select max((o->>'value')::numeric) into v_question_max from jsonb_array_elements(v_question->'options') o;
    v_max:=v_max+v_question_max;
  end loop;
  insert into public.questionnaire_attempts(assignment_id,answers,score,max_score) values(p_assignment_id,p_answers,v_score,v_max) returning id into v_id;
  update public.questionnaire_assignments set status='completed' where id=p_assignment_id;
  return v_id;
end; $$;
revoke all on function public.submit_questionnaire_attempt(uuid,jsonb) from public;
grant execute on function public.submit_questionnaire_attempt(uuid,jsonb) to authenticated;

-- After creating the first LIZA account in Authentication, run this once with its UUID:
-- update public.profiles set role='admin' where id='PASTE-AUTH-USER-UUID-HERE';

-- Example questionnaire (safe to customize through the SQL editor or admin UI):
insert into public.questionnaires(title,description,questions) values ('Seguimiento de bienestar','Registro orientativo para el seguimiento mensual','[
 {"id":"q1","text":"¿Cómo describirías tu bienestar durante la última semana?","options":[{"label":"Muy bajo","value":0},{"label":"Bajo","value":1},{"label":"Moderado","value":2},{"label":"Alto","value":3}]},
 {"id":"q2","text":"¿Qué tan capaz te has sentido de aplicar tus herramientas?","options":[{"label":"Nada","value":0},{"label":"Poco","value":1},{"label":"Algo","value":2},{"label":"Mucho","value":3}]}
]'::jsonb);
