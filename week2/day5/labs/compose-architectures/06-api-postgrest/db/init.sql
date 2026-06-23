create role web_anon nologin;
create role app_user login password 'app_password';

create schema if not exists api;

create table if not exists api.tasks (
  id serial primary key,
  title text not null,
  status text not null default 'todo'
);

insert into api.tasks(title, status)
values
  ('read compose.yaml', 'done'),
  ('call api service by published port', 'todo')
on conflict do nothing;

grant usage on schema api to web_anon;
grant select on api.tasks to web_anon;
grant web_anon to app_user;
