# 2교시: AWS 계정 안전장치

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| root user는 언제만 쓰나? | MFA 설정·계정 복구·꼭 필요한 account-level 작업만. EC2/S3/VPC 같은 일상 작업은 IAM으로 |
| MFA가 왜 필수인가? | password 하나 뚫려도 계정 탈취(비용/삭제/권한 사고)를 막는 2차 잠금 |
| Budget이 비용을 차단하나? | ❌ 아니다. **알림 장치**일 뿐. resource 삭제 책임은 사용자에게 |
| 오늘 access key를 왜 안 만드나? | 콘솔 중심 실습이라 불필요. 장기 key는 유출 시 자동 악용(비용/삭제) 대상 |
| 권한이 막히면 첫 행동은? | 무조건 관리자 권한 요구 X. 어떤 action/service 권한이 막혔고 수업에 꼭 필요한지 분리 → 최소 권한 출발점 |
| Region이 다른데 resource가 안 보이면? | 오른쪽 위 Region selector를 `ap-northeast-2`로 먼저 고정 |

## notes

### root user를 어떻게 볼 것인가
root = 계정 생성 시 생기는 최상위 identity. billing·계정 폐쇄 등 일부 account-level 작업만 root가 필요. **일상 작업(EC2/S3/VPC)은 root로 하지 않는 게 원칙.**
| identity | 수업 기준 |
|---|---|
| root user | MFA 설정, 복구 정보 확인, 꼭 필요한 account-level 작업만 |
| IAM user | 개인 실습 Console 로그인용 |
| IAM role | 운영·cloud service 간 **권한 위임**에 주로 사용 |
| access key | 오늘은 만들지 않는 것이 기본값 |

### MFA
root·IAM user 모두 설정 가능, 특히 **root MFA가 중요**. device 하나만 등록하고 복구 수단 없으면 분실 시 접근 불가 → 복구 절차를 계정 정책에 남긴다.
```text
Console → IAM → Security credentials → Multi-factor authentication
```

### IAM User vs IAM Role (질문에서 나온 것)
| | IAM User | IAM Role |
|---|---|---|
| 정체 | 영구 identity(사람) | 잠깐 **맡는(assume)** 권한 껍데기 |
| credential | 장기(비번, access key) | **임시**(STS 발급, 만료됨) |
| 누가 | 특정 사람 | 사람·서비스·타 계정이 assume |
| 비유 | 내 사원증 | 빌리는 **방문증**(시간 지나면 반납) |

- **유효시간**: 임시 credential은 **기본 1시간**, 설정 **15분~최대 12시간**(role chaining은 최대 1시간). 만료되면 다시 assume(재발급). → "30분"이 아니라 기본 1시간.
- IAM user 장기 key는 안 지우면 영원히 유효(유출 위험) ↔ **Role은 알아서 만료**돼 더 안전.

### Terraform / CI가 Role을 쓰는 이유
Terraform이 AWS를 바꾸려면 credential이 필요한데, **장기 access key를 박는 대신 Role을 assume**하는 게 정석.
```hcl
provider "aws" {
  region = "ap-northeast-2"
  assume_role { role_arn = "arn:aws:iam::123456789012:role/terraform-deploy" }
}
```
요즘 베스트는 **GitHub Actions → OIDC로 Role assume → 임시 credential로 apply** (access key를 CI Secret에 저장 불필요).
- 장기 key를 코드/CI에 안 남김(위 access key 유출 위험 회피)
- 임시라 만료됨 / 누가 언제 assume 했는지 **CloudTrail에 기록**(감사)
> 이게 2교시 "access key 새로 안 만들기" 원칙의 **실전판**.

### Budget vs Billing vs Cost Explorer (헷갈림)
| 도구 | 역할 |
|---|---|
| Billing dashboard | 월 누적 비용, forecast 확인 |
| **Budgets** | 비용/사용량 기준 **알림 설정**(차단 아님!) |
| Cost Explorer | service별 비용 **분석**(첫 활성화·데이터 지연 가능) |
| Tag | 비용 추적용 `Course`/`Owner`/`Purpose` |

> ⚠️ **Budget은 알림일 뿐 비용을 막지 않는다.** 삭제는 내가 해야 함.

### Access key 위험
CLI/SDK로 AWS API 호출할 때 쓰는 장기 credential. 콘솔 실습엔 불필요. 필요해지는 날에도 `.env`·README·screenshot·GitHub·메신저에 **남기지 않는다.**
```text
Access key 유출 → GitHub/README leak → 무단 API 호출 → 비용 폭탄 / resource 삭제
```

### 비용 사고 예시 (첫날 조심)
| 상황 | 위험 | 예방 |
|---|---|---|
| ALB 삭제 안 함 | traffic 없어도 시간 비용 | Day2 종료 전 cleanup |
| RDS 방치 | instance/storage 비용 지속 | 삭제 계획 먼저 |
| NAT Gateway 무심코 생성 | 초보 실습에 큰 비용 | W5는 기본 생성 금지 |
| access key 유출 | 자동 API 호출 사고 | key 미생성, CloudTrail 확인 |

### 계정 안전 Checklist (첫날 잠그기)
```text
□ root user MFA 설정됨
□ 실습 중 root user 사용 안 함
□ 오늘 Region 정함 (ap-northeast-2)
□ Budget/비용 알림 확인
□ access key 새로 안 만듦
□ 모든 resource에 tag
□ 종료 전 cleanup 시간 확보
```

### 한 줄 요약
AWS 실습은 **root/MFA/Budget/access key를 먼저 잠그고** 시작한다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| Budget을 걸었는데 비용이 계속 나감 | Budget은 **알림 장치**지 차단이 아님 → 실제 resource를 직접 cleanup해야 비용 멈춤 |
