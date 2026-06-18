# Week 2 Day 2 — Docker Volume, Bind Mount, Network

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Day 1 DB container 재생성과 데이터 소실 확인 | volume 없는 container 삭제 시 데이터 사라짐, writable layer |
| 2교시 | named volume과 database persistence | volume 생성/mount, container 교체 후 데이터 보존 확인 |
| 3교시 | volume 명령과 cleanup 위험 | `volume ls/inspect/rm`, dangling volume, 삭제 판단 |
| 4교시 | bind mount와 host path 주의 | host 파일 실시간 반영, `:ro`, 개발 환경 활용 |
| 5교시 | Docker network 기본 | default bridge vs custom bridge, `network create/inspect` |
| 6교시 | container name DNS와 DB client container | `--network`로 container name 접속, `--rm` 일회성 container |
| 7교시 | port publish와 network 차이 | host 접속(`localhost:15432`) vs container 접속(`name:5432`) |
| 8교시 | storage/network 통합 실험 | volume + network 동시 연결, container 교체 후 데이터 보존, cleanup audit |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 기록 및 notes |
| `assets/` | 실습 확인 스크린샷 |
| `linux-command-maker.xlsx` | Linux 명령어 참조 시트 |
