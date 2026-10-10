-- Run once in Supabase Dashboard > SQL Editor.
-- The FastAPI backend alone accesses these tables with SUPABASE_SECRET_KEY.

create extension if not exists pgcrypto;

create table if not exists public.app_settings (
    key text primary key,
    value text not null,
    updated_at timestamptz not null default now()
);

insert into public.app_settings (key, value)
values ('catvton_url', 'https://849e3e88c9974d2815.gradio.live/')
on conflict (key) do nothing;

create table if not exists public.chat_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    context_summary text not null default '',
    is_ready_for_suggestion boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.chat_sessions(id) on delete cascade,
    role text not null check (role in ('user', 'assistant')),
    content text not null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create table if not exists public.wardrobe_items (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    name text not null,
    category text not null,
    description text not null,
    image_path text,
    created_at timestamptz not null default now()
);

create table if not exists public.outfit_suggestions (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.chat_sessions(id) on delete cascade,
    message_id uuid not null references public.chat_messages(id) on delete cascade,
    name text not null,
    wardrobe_item_ids jsonb not null default '[]'::jsonb,
    reason text not null,
    created_at timestamptz not null default now()
);

create table if not exists public.user_photos (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    original_filename text not null,
    image_path text not null unique,
    created_at timestamptz not null default now()
);

create table if not exists public.tryon_results (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    person_photo_id uuid not null references public.user_photos(id) on delete cascade,
    wardrobe_item_id uuid not null references public.wardrobe_items(id) on delete cascade,
    result_path text not null unique,
    created_at timestamptz not null default now(),
    unique (user_id, person_photo_id, wardrobe_item_id)
);

create table if not exists public.tryon_jobs (
    id uuid primary key default gen_random_uuid(),
    user_id text not null,
    person_photo_id uuid not null references public.user_photos(id) on delete cascade,
    wardrobe_item_id uuid not null references public.wardrobe_items(id) on delete cascade,
    status text not null check (status in ('queued', 'processing', 'completed', 'failed')),
    result_id uuid references public.tryon_results(id) on delete set null,
    error text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists chat_messages_session_created_idx on public.chat_messages(session_id, created_at);
create index if not exists wardrobe_items_user_created_idx on public.wardrobe_items(user_id, created_at);
create index if not exists outfit_suggestions_session_created_idx on public.outfit_suggestions(session_id, created_at);
create index if not exists user_photos_user_created_idx on public.user_photos(user_id, created_at);
create index if not exists tryon_results_user_created_idx on public.tryon_results(user_id, created_at);
create index if not exists tryon_jobs_user_created_idx on public.tryon_jobs(user_id, created_at);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists chat_sessions_updated_at on public.chat_sessions;
create trigger chat_sessions_updated_at before update on public.chat_sessions
for each row execute function public.set_updated_at();

-- The API has no browser access yet. RLS blocks direct browser reads/writes;
-- the server's secret key bypasses RLS after it performs its own user checks.
alter table public.chat_sessions enable row level security;
alter table public.app_settings enable row level security;
alter table public.chat_messages enable row level security;
alter table public.wardrobe_items enable row level security;
alter table public.outfit_suggestions enable row level security;
alter table public.user_photos enable row level security;
alter table public.tryon_results enable row level security;
alter table public.tryon_jobs enable row level security;

grant usage on schema public to service_role;
grant all privileges on all tables in schema public to service_role;

drop trigger if exists app_settings_updated_at on public.app_settings;
create trigger app_settings_updated_at before update on public.app_settings
for each row execute function public.set_updated_at();

drop trigger if exists tryon_jobs_updated_at on public.tryon_jobs;
create trigger tryon_jobs_updated_at before update on public.tryon_jobs
for each row execute function public.set_updated_at();

-- Create this private bucket in Dashboard > Storage if it does not exist:
-- name: wardrobe
-- The backend uses the secret key to upload files and generate signed URLs.
