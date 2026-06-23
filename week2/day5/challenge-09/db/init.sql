-- Set D: Event Processing Mini Platform — 결과 저장 table 초기화 (pgdata 비어있을 때 최초 1회)
create role web_anon nologin;
create role app_user login password 'app_password';

create schema if not exists api;

-- processor-worker가 처리한 이벤트 결과를 쌓는 table
create table if not exists api.results (
  id serial primary key,
  event text not null,
  processed_at timestamptz not null default now()
);

-- result-api(PostgREST, web_anon)는 읽기만, worker(postgres superuser)는 쓰기
grant usage on schema api to web_anon;
grant select on api.results to web_anon;
grant web_anon to app_user;
