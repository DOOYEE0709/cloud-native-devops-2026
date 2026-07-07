# Week 5 Day 2 — AWS 네트워크 + EC2/ALB 실행과 장애 분석

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Day1 요약 + AWS 네트워크 실습 지도 | public subnet=**이름 아닌 route(IGW)**, 외부 접속 5요소(VPC·subnet·public IP·route·SG), traffic path 먼저 그리기, **ALB는 존재만으로 과금** |
| 2교시 | EC2 Console 실습 | launch=AMI·type·key·network·SG·storage·tag **선택 묶음**, key pair **재다운로드 불가**, 접속 3방식, Xshell/VSCode 터미널 `ssh`(`ec2-user`+`.pem`) |
| 3교시 | EC2 웹 서버 실행 | user data=**부팅 시 초기 셋업**(AMI별 `dnf`/`apt`), 성공=**running 아니라 HTTP 200**, 진단 3종(tcpdump·localhost·netstat), **ENI=SG 붙는 문** |
| 4교시 | Security Group 장애 분석 | 일부러 80 닫고·source 틀리고 복구, **timeout(앞단) vs refused(뒷단)**, port·source·direction·recheck 세트, **SSH 22 전체공개 금지→SSM** |
| 5교시 | Load Balancing 개념 | ALB·Listener·Target Group·**Health Check(=배포 gate)**, endpoint/backend 분리, **ALB DNS 있음≠정상(503)**, K8s Service/Ingress/readinessProbe 매핑 |
| 6교시 | ALB Console 실습 | TG 생성→EC2 등록→ALB→**target healthy+ALB DNS 응답**, EC2 direct 선행, **SG 2개**(user→ALB SG, ALB→EC2 SG), EC2 SG source를 ALB SG로 좁히기 |
| 7교시 | EC2/ALB 운영 관찰 | 요청 경로 **계층별 관찰**(사용자→ALB→target→EC2→SG→app→CloudTrail), 503 첫 확인=target reason, **CloudWatch(상태) vs CloudTrail(변경자)** |
| 8교시 | 구름 EXP 배움일기 | 끝은 접속 성공 아니라 **evidence 정리 + cleanup audit**, 삭제 순서(ALB→TG→EC2→EBS→SG), **EC2만 지우면 ALB·EBS 비용 잔여** |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 확인 기록(변수화된 명령)·확인 질문 답변·notes·Blocker Log |

## 핵심 한 줄
EC2/ALB 실습의 성공 증거는 **화면의 running/active(초록불)가 아니라 요청 경로 끝의 HTTP 응답**이다. 장애는 **app보다 먼저 network 계층**(Region→subnet route→public IP→SG→target health)을 보고, **timeout(앞단) vs connection refused(뒷단)**로 구간을 좁힌다. 실습의 마지막 단계는 접속 성공이 아니라 **cleanup audit**.

## Day2에서 몸으로 익힌 진단 도구 (3종 세트)
| 도구 | 명령 | 보는 것 | 없으면 |
|---|---|---|---|
| tcpdump | `sudo tcpdump -i any port 80` | 패킷이 **들어오나** | 안 들어옴 → 앞단(SG/route) |
| localhost 비교 | `curl localhost` vs `curl publicIP` | SG가 **어디서 거르나** | localhost만 됨 → SG/ENI |
| netstat/ss | `sudo ss -tlnp \| grep :80` | app이 **80 듣나** | 없음 → app down(refused) |

## 자주 하는 오해 (Day2에서 잡은 것)
- public subnet은 **이름이 아니라 route(IGW)** 로 판단
- **running ≠ HTTP 정상**, **ALB active ≠ 서비스 정상(503)**
- **timeout(SG/앞단) ≠ connection refused(app/뒷단)**
- SG는 **ENI에 붙어 밖→인스턴스 트래픽만** 검사 → localhost는 SG 통과 안 함
- **SSH 22 전체공개 금지** → key 관리 부담 없는 **SSM Session Manager**(inbound 0개, outbound 443)
- cleanup은 **EC2 하나로 안 끝남** → ALB·target group·EBS·EIP 별도 삭제

## 다음 연결 (Day3)
Day3는 EC2 직접 설치 대신 **container image를 service가 실행**한다. 오늘의 **ALB·target group·health check·port** 개념이 그대로 재등장하므로, 배움일기에 port·health check를 정리해두면 ECR/ECS/App Runner가 쉬워진다.
