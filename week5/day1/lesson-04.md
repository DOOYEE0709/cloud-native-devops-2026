# 4교시: AWS 서비스 운영 지도

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| AWS service를 외우는 법? | 알파벳순 암기 ❌. **운영 질문(어디서 실행/접속/저장/누가 접근/evidence/비용)으로 분류** |
| CloudWatch vs CloudTrail? | CloudWatch=app/resource 상태(metric·log·alarm), CloudTrail=**누가 어떤 API를 호출했나**(변경 audit) |
| "app이 500 응답" 어디서 보나? | CloudWatch(log stream error, 5xx metric). CloudTrail은 직접 원인 API가 아닐 수 있음 |
| "SG rule을 누가 바꿨나"는? | CloudTrail `AuthorizeSecurityGroupIngress` event |
| managed service면 책임이 없나? | ❌ 책임이 **사라지는 게 아니라 위치가 바뀜**(설정·접근·비용·데이터·backup·삭제보호는 여전히 내 몫) |
| RDS에서 사용자가 결정할 것은? | engine/version, public access 여부, backup retention, deletion protection, 비용 |

## notes

### AWS = 도구 목록이 아니라 운영 지도
service가 너무 많으니 **운영 질문으로 분류**한다.
| 운영 질문 | service 후보 |
|---|---|
| 어디서 실행되나 | EC2, ECS, Lambda, EKS |
| 어디로 접속되나 | VPC, subnet, SG, ALB, Route 53 |
| 파일/객체는 어디에 | S3 |
| block storage는 | EBS |
| 공유 파일시스템은 | EFS |
| database는 누가 운영 | RDS |
| image는 어디 저장 | ECR |
| 로그·지표는 어디서 | CloudWatch |
| 누가 무엇을 호출했나 | CloudTrail |
| 비용은 어디서 | Billing, Budget, Cost Explorer |

### Kubernetes → AWS 매핑
| Kubernetes | AWS |
|---|---|
| Pod/Deployment | EC2 / ECS / EKS |
| Service/Ingress | VPC / SG / ALB |
| Secret/RBAC | IAM / Secrets Manager |
| Logs/Metrics | CloudWatch / CloudTrail |

### CloudWatch vs CloudTrail (핵심 구분)
이름이 비슷하지만 **보는 증거가 다르다.**
| 구분 | CloudWatch | CloudTrail |
|---|---|---|
| 주 관심 | app/resource **상태** | AWS **API 활동** |
| 예시 | CPU metric, log group, alarm | `RunInstances`, `CreateBucket`, `AuthorizeSecurityGroupIngress` |
| 답하는 질문 | "서비스가 느린가/죽었나" | "**누가** 설정을 바꿨나" |

사례로 구분:
| 사건 | CloudWatch | CloudTrail |
|---|---|---|
| app 500 응답 | log error, 5xx metric | 직접 원인 API 아닐 수 있음 |
| Security Group rule 변경 | metric 변화 가능 | `AuthorizeSecurityGroupIngress` |
| EC2 생성 | 기본 metric 관찰 | `RunInstances` |
| ALB target unhealthy | target metric, health reason | target group 설정 변경 event |

> ⚠️ 흔한 실패: CloudTrail에서 app log를 찾음 / CloudWatch에서 변경자를 찾음. **질문이 다르면 봐야 할 곳이 다르다.**

### Managed service의 책임 = 사라지는 게 아니라 위치가 바뀜
AWS가 하드웨어·control plane 일부를 맡지만, 설정·접근·비용·데이터·backup·삭제보호는 사용자 몫.
| service | AWS가 줄여주는 것 | 내가 여전히 결정 |
|---|---|---|
| EC2 | 물리 서버 구매/설치 | OS patch, SG, instance type, EBS |
| S3 | storage 서버 운영 | public access, lifecycle, versioning |
| RDS | DB 설치/backup 기능 | engine, size, backup window, SG, deletion protection |
| ECS/App Runner | container 실행 제어 일부 | image, env, secret, scaling, logs |

### 운영 질문 체크리스트 (service를 만날 때)
```text
□ compute/network/storage/identity/observability/cost 중 어디?
□ Region 단위인가, global인가?
□ 삭제하면 data가 사라지나, 별도 storage가 남나?
□ 생성/수정/삭제를 CloudTrail에서 볼 수 있나?
□ 로그·metric은 CloudWatch 어디에 나오나?
```

### 한 줄 요약
AWS service는 이름이 아니라 **compute·network·storage·identity·observability·cost 질문에 붙여서** 읽는다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| 장애 원인을 CloudTrail에서 app 로그로 찾으려다 못 찾음 | app 상태·로그는 **CloudWatch**, "누가 바꿨나"는 CloudTrail — 질문에 맞는 곳으로 |
