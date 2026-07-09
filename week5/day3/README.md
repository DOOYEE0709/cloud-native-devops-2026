# Week 5 Day 3 — 컨테이너 실행 서비스(ECR/ECS/App Runner) + CloudWatch 관찰

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Day2 요약 + 컨테이너 실행 서비스 매핑 | **Registry(저장)·Runtime(실행)·CloudWatch(관찰)** 분리, 운영 루프 `image→service→health→logs→update→rollback`, **push≠배포**, desired vs running, **추상화를 AWS에 맡기면 ECS/App Runner·플랫폼팀이 K8s 쌓으면 EKS** |
| 2교시 | ECR 실습 | URI=`account.dkr.ecr.region.amazonaws.com/repo`, login=**임시 token**(get-login-password→docker login, username 고정 `AWS`·`--password-stdin`), push 흐름 auth→build→tag→push→verify, **`latest` 대신 `v1/v2`**(rollback 증명) |
| 3교시 | ECS 또는 App Runner 맛보기 | ECS 계층 `image→Task Def→Service→Desired→Health/Logs`, **port mapping이 health의 핵심**, **hello-world는 web server 아님**(nginx), **IAM Role=키 없이 임시자격**(Credential Provider Chain), **ECS 로그는 opt-in**(awslogs 안 켜면 로그 없음) |
| 4교시 | Container service와 ALB 연결 | `User→ALB→Listener→TG→Task→Container Port`, **port 3곳 일치**(app listen·portMappings·TG), target unhealthy 원인(port·health path·SG·stopped), **desired 1의 위험**, Serverless/VPC·RDS Proxy 판단 |
| 5교시 | 배포 변경과 rollback preview | 변경 단위=**image tag + task def revision**, rollback은 감이 아니라 **변경 전 evidence**(`image=v1,revision=3,target=healthy,curl=200`), 실패 시나리오 분리(pull·crash·port·health path·env·latency) |
| 6교시 | CloudWatch Logs 기본 | log group(묶음)/log stream(task 단위 흐름), container는 **stdout/stderr**가 기본 출구, **"로그 없음"의 90%는 time range/Region 오판**, stream 없으면 app 아니라 **task 실행 여부**부터 |
| 7교시 | CloudWatch Metrics와 Alarm | **Logs=무슨 일**/Metrics=**얼마나 자주·크게**, namespace·dimension, 좋은 metric=**다음 행동으로 연결**, INSUFFICIENT_DATA, **노이즈 없는 alarm은 없다→threshold를 반복 튜닝** |
| 8교시 | 구름 EXP 배움일기 | 산출물=URL 아니라 **image·service·health·logs·metrics·cleanup 연결된 evidence**, cleanup 단골 누락=**service만 지우고 ECR image·ALB 남김**(ALB는 존재만으로 과금), Day4 data/secret 질문으로 연결 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 확인 기록·확인 질문 답변·notes·Blocker Log |

## 핵심 한 줄
Day3의 산출물은 실행된 container **URL 하나가 아니라**, image가 어떤 tag로 ECR에 있고 → 어떤 service가 그것을 실행하며 → health/logs/metrics로 어떻게 관찰하고 → 문제 시 어떤 revision으로 rollback하는지까지 **연결된 운영 evidence**다. **Registry(ECR)·Runtime(ECS/App Runner)·Observability(CloudWatch)** 를 분리해서 본다.

## Day3에서 잡은 핵심 구분
- **저장 ≠ 실행 ≠ 관찰**: ECR(저장) · ECS/App Runner(실행) · CloudWatch(관찰) — push 성공은 배포 성공이 아니다
- **desired count ≠ running count**: 안 맞으면 pull 실패·health 실패·리소스 부족 의심
- **port는 3곳이 일치**해야 함: app listen · task def portMappings · target group Port
- **Logs ≠ Metrics**: Logs=무슨 일이 있었나(text), Metrics=얼마나 자주·크게(number over time)
- **인증은 키가 아니라 신원**: IAM Role(EC2 instance profile·ECS task role·Lambda execution role)로 **임시 token** 자동 획득 → 코드에 secret key 안 둠

## 자주 하는 오해 (Day3에서 잡은 것)
- **ECR push = 배포**로 착각 (실행은 ECS/App Runner가 pull해서 별도로)
- **hello-world를 web service로** 착각 (한 번 출력하고 종료 → health check 실패, nginx 같은 web 이미지 필요)
- **ECS 로그가 자동으로 켜진다**고 착각 (awslogs 드라이버는 opt-in, 안 켜면 죽은 task 로그를 못 되살림)
- **"로그가 없다"** = 대부분 time range/Region 오판, 또는 task가 실제로 안 뜬 것
- **service 생성 = 정상**으로 착각 (desired/running·deployment status·health·logs를 함께)
- **alarm은 한 번 만들면 끝**으로 착각 (첫 threshold는 출발점, noise↔miss 사이에서 반복 튜닝)
- cleanup은 **service 삭제로 안 끝남** → ECR image·ALB/target group·log retention 별도 (ALB는 존재만으로 과금)

## 다음 연결 (Day4)
container가 실행되면 곧 **data와 secret** 문제가 온다 — 파일은 어디에(S3), 관계형 데이터는 어디에(RDS), password는 어디에(Secrets Manager), 비용은 어떻게 추적(Cost Explorer). Day4는 app **밖에 남는 데이터·권한·복구·비용의 경계**를 읽는다. Day3의 logs/metrics/health 관찰 습관이 그대로 이어진다.
