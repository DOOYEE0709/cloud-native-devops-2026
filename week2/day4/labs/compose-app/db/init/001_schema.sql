create table if not exists app_event (
  id serial primary key,
  name text not null,
  created_at timestamptz not null default now()
);

insert into app_event (name)
values ('compose-init-ok')
on conflict do nothing;
