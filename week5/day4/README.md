# Week 5 Day 4 — AWS Storage/Database/Secrets/Cost 운영 경계

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Day3 요약 + storage/database 운영 지도 | compute(Day3)는 다시 만들면 되지만 **app 밖에 남는 데이터·credential·비용**은 삭제·공개 판단이 무거움. `App→S3(파일)/RDS(관계형)/Secrets(자격증명)→Cost/Audit`, 성공 기준=생성이 아니라 **접근·보존·복구·비용 evidence**, container는 stateless라 영속 데이터는 **밖으로**(S3/RDS/Secrets) |
| 2교시 | S3 bucket/object/public access | bucket(전역 유일 이름)/object(key), **URL 있어도 public 아님**(403이 정상), 접근 결정=**IAM+bucket policy+Block Public Access**(BPA가 우선), 기본은 **차단**, ACL 대신 policy(Object Ownership) |
| 3교시 | S3 versioning/lifecycle/storage class | 삭제=**delete marker**(비파괴적, version 잔존→비용), lifecycle=transition/expiration/**NoncurrentVersionExpiration**, storage class는 **접근 빈도**로(저장↔꺼내기 비용 반대), archive=법적보관·연1회, **미완성 multipart도 비용** |
| 4교시 | RDS 생성 전 운영 경계 | DB는 VPC/subnet group/SG 경계 안, **접속 실패는 password보다 network**(public→subnet→**SG inbound**→credential), **DB port `0.0.0.0/0` 금지**, gp3(용량과 IOPS 분리)가 기본·gp2는 레거시, RDS Proxy=다수 연결→소수 pool |
| 5교시 | RDS backup/snapshot/deletion protection | automated(retention 내)vs manual(직접 지울 때까지), **restore=새 DB 생성**(원본 안 덮음), **PITR=자동백업+log 재생으로 임의 시각**, RPO(데이터 손실)/RTO(다운타임), deletion protection=안전장치, 삭제 후 **snapshot이 비용으로 잔존** |
| 6교시 | Secrets Manager와 credential 운영 | secret은 값 숨김뿐 아니라 **누가 읽고(IAM)·언제 바뀌고(rotation)·어떻게 감사(CloudTrail)**, 런타임 `GetSecretValue`, **rotation≠backup**, RDS type 어려움=**rotation Lambda의 VPC/SG 배선**(4교시), 삭제=recovery window, 비용=저장+호출(**배포량 비례**), evidence는 값 아니라 name/권한 |
| 7교시 | Cost Explorer/tag/잔여 비용 점검 | **Cost Explorer=분석·Budget=알림, 둘 다 삭제 안 함**, tag는 **생성 시점+활성화**(backfill로 활성화 지연은 완화되나 untagged는 소급 불가), **잔여 비용 후보**(상시:ALB/NAT/EIP/RDS, 저장:EBS/snapshot/version/log), 데이터 ~24h 지연→두 번 확인, EIP는 안 쓸 때 과금 |
| 8교시 | 구름 EXP 배움일기 | 산출물=resource 생성이 아니라 **S3/RDS/Secrets/Cost의 접근·보존·복구·비용 evidence**, cleanup 단골 누락(snapshot·version·EIP·log·secret), Day5 통합 runbook으로 연결 |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 환경 변수·실습 확인 기록·확인 질문 답변·notes·Blocker Log |

## 핵심 한 줄
Day4의 산출물은 만든 resource가 **몇 개냐가 아니라**, 파일이 어디에(S3) → 관계형 데이터가 어디에(RDS) → password가 어디에(Secrets Manager) → 비용이 어떻게 추적·정리되는지(Cost Explorer/cleanup)까지 **연결된 운영 evidence**다. compute와 달리 **데이터·credential은 잘못 공개·삭제되면 복구와 책임 범위가 달라진다**.

## Day4에서 잡은 핵심 구분
- **compute ≠ data**: container는 stateless(죽으면 사라짐) → 영속 데이터·credential은 **밖으로**(S3/RDS/Secrets)
- **접근은 한 계층이 아니다**: S3=IAM+bucket policy+BPA, RDS=SG inbound+network, Secrets=IAM permission — 한 화면만 보고 판단 안 함
- **삭제 ≠ 사라짐 = 비용 끝 아님**: S3 version·delete marker, RDS snapshot·final snapshot, unattached EIP·EBS, retention 없는 log가 **잔존 비용**
- **restore = 새로 만드는 것**: RDS PITR/snapshot 복구는 **새 instance**(endpoint 바뀜, app 재연결) — 원본 즉시 복귀 아님
- **secret은 값 숨김이 전부가 아님**: 누가 읽고(IAM)·언제 바뀌고(rotation)·어떻게 감사되는지(CloudTrail)까지가 운영
- **Cost Explorer/Budget은 삭제를 안 한다**: 분석·알림일 뿐, 비용을 멈추는 건 언제나 **직접 cleanup**
- **tag는 생성 시점에**: 활성화 지연은 backfill로 완화돼도, 처음부터 untagged인 사용량은 소급 불가

## 자주 하는 오해 (Day4에서 잡은 것)
- **object URL이 있으면 public**으로 착각 (실제 접근은 IAM+policy+BPA가 결정, 403이 정상)
- **versioning suspend/삭제로 비용 끝**으로 착각 (이전 version 잔존 → lifecycle 없으면 계속 비용)
- **DB 접속 실패=password**로 착각 (대부분 **SG inbound/network**, credential은 맨 나중)
- **managed service니까 보안 신경 안 써도** 된다고 착각 (VPC/SG/public access/backup은 내 결정)
- **rotation을 backup으로** 착각 (rotation=교체, backup=복구, 목적 반대)
- **secret 값을 evidence로 캡처** (값은 숨기고 name/ARN 일부/권한 방향만)
- **Budget을 비용 차단 장치로** 착각 (알림일 뿐, cleanup은 별도)
- **"resource 지웠으니 비용 끝"** 착각 (snapshot·version·EIP·EBS·log가 남음 → 삭제 **후 검색 결과**가 evidence)

## 다음 연결 (Day5)
Day4에서 읽은 storage/database/secret/cost 경계는 **Day5 통합 운영 runbook**의 재료가 된다 — 어떤 데이터가 어디에 남고, 누가 접근·복구·감사하며, 삭제 전 무엇을 확인하는지를 하나의 절차로 묶는다. Day3의 logs/metrics/health 관찰 습관 위에, Day4의 **접근·보존·복구·비용 evidence**가 얹힌다.
