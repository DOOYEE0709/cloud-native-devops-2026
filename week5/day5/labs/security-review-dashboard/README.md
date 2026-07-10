# W5D5S3 Security Review Dashboard Lab

이 실습은 추가 보안 서비스를 켜지 않고 AWS Console에서 바로 수행하는 보안 점검이다. 목표는 "보안 확인"이 아니라 확인한 화면, 값, 판단, 조치를 남기는 것이다.

## 준비
- 실습 Region을 하나로 고정한다. 예: `ap-northeast-2`
- root user가 아니라 수업용 IAM identity로 로그인한다.
- 계정 이메일, access key, token, password, MFA code가 캡처되지 않게 한다.
- 같은 resource를 여러 명이 공유하면 Security Group rule을 바꾸기 전에 owner를 확인한다.

## Dashboard Template
아래 표를 복사해서 채운다.

| Area | AWS Console path | Resource | 확인한 값 | Status | Risk | Action | Recheck evidence |
|---|---|---|---|---|---|---|---|
| Account MFA | IAM -> Dashboard/Security credentials | root 또는 IAM user |  |  |  |  |  |
| IAM permission | IAM -> Users/Roles -> Permissions |  |  |  |  |  |  |
| Access key | IAM -> Users -> Security credentials |  |  |  |  |  |  |
| SG inbound | EC2 -> Security Groups -> Inbound rules |  |  |  |  |  |  |
| Public endpoint | EC2 -> Instances 또는 Load Balancers |  |  |  |  |  |  |
| S3 public access | S3 -> Bucket -> Permissions |  |  |  |  |  |  |
| Secret hygiene | screenshots/markdown/git diff |  |  |  |  |  |  |
| Audit event | CloudTrail -> Event history |  |  |  |  |  |  |

Status는 `OK`, `Fix now`, `Accept until cleanup`, `Need owner decision` 중 하나로 쓴다.

## Step 1. Account and IAM
1. Console 상단에서 로그인 identity와 account를 확인한다.
2. IAM dashboard 또는 Security credentials에서 MFA 상태를 확인한다.
3. IAM Users 또는 Roles에서 수업용 identity의 attached policy를 확인한다.
4. `AdministratorAccess`가 있다면 왜 필요한지, 언제 줄일지 Action에 적는다.
5. IAM access key가 있다면 `Last used`와 목적을 확인한다. 목적이 없으면 비활성화 또는 삭제 계획을 적는다.

## Step 2. Security Group Exposure
1. EC2 -> Security Groups로 이동한다.
2. Week 5 실습에서 만든 SG를 선택한다.
3. Inbound rules에서 source가 `0.0.0.0/0` 또는 `::/0`인 rule을 찾는다.
4. 아래 기준으로 판단한다.

| Port | 판단 |
|---|---|
| 22 또는 3389 public | `Fix now`가 기본값이다. 내 IP로 제한하거나 삭제한다. |
| 80 또는 443 public | public web 실습이면 `Accept until cleanup` 가능하다. |
| 3306, 5432, 6379 public | `Fix now`가 기본값이다. |
| custom admin port public | owner 결정 없이는 유지하지 않는다. |

5. 수정했다면 같은 SG 화면에서 source가 바뀐 것을 Recheck evidence에 적는다.

## Step 3. Public Endpoint Inventory
1. EC2 Instances, Load Balancers, ECS/App Runner 등 Week 5에서 만든 public endpoint를 찾는다.
2. endpoint마다 purpose와 cleanup 시각을 적는다.
3. 더 이상 필요 없는 endpoint는 삭제, stop, SG 제한 중 하나를 선택한다.

## Step 4. S3 Public Access
1. S3 -> Buckets에서 Week 5 실습 bucket을 연다.
2. Permissions tab에서 Block Public Access 상태를 확인한다.
3. Bucket policy에 `Principal: "*"` 또는 broad access가 있는지 확인한다.
4. public access가 필요 없다면 Block Public Access를 유지하고 policy를 제거한다.
5. public hosting 실습 때문에 공개했다면 공개 목적과 cleanup 시각을 적는다.

## Step 5. Secret Hygiene
아래 항목을 최종 패킷에 넣기 전에 확인한다.

| 위치 | 확인 |
|---|---|
| screenshots | access key, token, password, account email이 보이지 않는다 |
| markdown notes | secret value를 붙여넣지 않았다 |
| terminal output | credential 전체 값이 남지 않았다 |
| git diff | `.env`, key file, token이 포함되지 않았다 |

로컬 repo에서는 다음 명령으로 흔한 credential 문자열을 빠르게 찾을 수 있다.

```bash
rg -n "AKIA|ASIA|aws_secret_access_key|password|token|BEGIN .*PRIVATE KEY" .
```

이 명령은 오탐이 있을 수 있으므로 결과를 보고 실제 secret인지 판단한다.

## Step 6. CloudTrail Audit Evidence
1. CloudTrail -> Event history로 이동한다.
2. 오늘 실습 시간대를 기준으로 필터링한다.
3. 아래 이벤트 중 하나 이상을 찾아 dashboard에 기록한다.

| Event name | 의미 |
|---|---|
| `AuthorizeSecurityGroupIngress` | SG inbound rule 추가 |
| `RevokeSecurityGroupIngress` | SG inbound rule 제거 |
| `AttachUserPolicy` | IAM policy 연결 |
| `CreateAccessKey` | access key 생성 |
| `PutBucketPolicy` | S3 bucket policy 변경 |
| `PutPublicAccessBlock` | S3 public access block 변경 |
| `ConsoleLogin` | Console 로그인 |

기록 형식:

```markdown
- eventTime:
- eventName:
- user:
- resource:
- 이 이벤트가 설명하는 판단:
```

## Pass Criteria
- IAM/MFA, IAM permission, SG inbound, S3 public access, CloudTrail audit가 모두 채워져 있다.
- public rule은 port와 source가 같이 적혀 있다.
- `Fix now` 항목은 조치 후 재확인 값이 있다.
- secret이 보이는 자료는 삭제하거나 가린 뒤 다시 저장했다.
- 실습 때문에 남기는 public endpoint는 cleanup 시각과 owner가 있다.

## Cleanup/Handoff
```markdown
# W5D5S3 security cleanup handoff
- 남겨둔 public endpoint:
- 남겨둔 public SG rule:
- 남겨둔 IAM admin 권한:
- 남겨둔 S3 public access:
- 유지 사유:
- cleanup 담당자:
- cleanup 예정 시각:
- 최종 재확인 화면:
```
