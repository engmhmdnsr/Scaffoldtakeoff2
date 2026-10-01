/* Supabase Schema for Scaffold Takeoff */

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

/* Profiles table linked to auth.users */
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text,
  full_name text,
  created_at timestamptz default now()
);

/* Projects table storing per-user scaffold calculations */
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade default auth.uid(),
  title text not null,
  scaffold_data jsonb default '{}'::jsonb,
  takeoff_rows jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

/* Project files table for attachments or exported reports */
create table if not exists public.project_files (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects on delete cascade,
  user_id uuid not null references auth.users on delete cascade default auth.uid(),
  file_name text not null,
  storage_path text not null,
  created_at timestamptz default now()
);

/* Updated at trigger for projects */
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_projects_updated on public.projects;
create trigger on_projects_updated
  before update on public.projects
  for each row execute procedure public.handle_updated_at();

/* Profile creation trigger when new user signs up */
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

/* Enable Row Level Security (RLS) on all tables */
alter table public.profiles enable row level security;
alter table public.projects enable row level security;
alter table public.project_files enable row level security;

/* RLS Policies for profiles */
drop policy if exists "Profiles select own" on public.profiles;
create policy "Profiles select own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "Profiles update own" on public.profiles;
create policy "Profiles update own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

/* RLS Policies for projects */
drop policy if exists "Projects select own" on public.projects;
create policy "Projects select own" on public.projects
  for select using (auth.uid() = user_id);

drop policy if exists "Projects insert own" on public.projects;
create policy "Projects insert own" on public.projects
  for insert with check (auth.uid() = user_id);

drop policy if exists "Projects update own" on public.projects
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Projects delete own" on public.projects
  for delete using (auth.uid() = user_id);

/* RLS Policies for project_files */
drop policy if exists "Project files select own" on public.project_files;
create policy "Project files select own" on public.project_files
  for select using (auth.uid() = user_id);

drop policy if exists "Project files insert own" on public.project_files
  for insert with check (auth.uid() = user_id);

drop policy if exists "Project files update own" on public.project_files
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Project files delete own" on public.project_files
  for delete using (auth.uid() = user_id);

/* Storage bucket setup for project-exports */
insert into storage.buckets (id, name, public)
values ('project-exports', 'project-exports', false)
on conflict (id) do nothing;

/* Storage RLS policies per user folder: user_id/* */
drop policy if exists "User can view own exports" on storage.objects;
create policy "User can view own exports" on storage.objects
  for select using (bucket_id = 'project-exports' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "User can upload own exports" on storage.objects;
create policy "User can upload own exports" on storage.objects
  for insert with check (bucket_id = 'project-exports' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "User can update own exports" on storage.objects;
create policy "User can update own exports" on storage.objects
  for update using (bucket_id = 'project-exports' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "User can delete own exports" on storage.objects;
create policy "User can delete own exports" on storage.objects
  for delete using (bucket_id = 'project-exports' and (storage.foldername(name))[1] = auth.uid()::text);
