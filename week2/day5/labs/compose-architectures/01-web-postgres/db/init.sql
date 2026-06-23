create role web_anon nologin;
create role app_user login password 'app_password';

create schema if not exists api;

create table if not exists api.products (
  id serial primary key,
  name text not null,
  price integer not null,
  stock integer not null
);

insert into api.products(name, price, stock)
values
  ('local-market-starter-kit', 39000, 12),
  ('commerce-cache-demo', 12000, 3),
  ('compose-architecture-map', 24000, 7)
on conflict do nothing;

grant usage on schema api to web_anon;
grant select on api.products to web_anon;
grant web_anon to app_user;
