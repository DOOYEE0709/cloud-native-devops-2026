create role web_anon nologin;
create role app_user login password 'app_password';

create schema if not exists api;

create table if not exists api.services (
  id serial primary key,
  name text not null,
  role text not null
);

insert into api.services(name, role)
values
  ('frontend', 'static client'),
  ('gateway', 'reverse proxy'),
  ('api', 'REST endpoint'),
  ('db', 'stateful backing service')
on conflict do nothing;

grant usage on schema api to web_anon;
grant select on api.services to web_anon;
grant web_anon to app_user;
