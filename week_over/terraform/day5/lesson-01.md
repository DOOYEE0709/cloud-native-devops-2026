# 9교시: 기존 리소스를 조사하고 Import 주소 설계하기

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Console에 이미 있는 RDS나 Route 53 Record를 찾았다고 바로 `terraform import`를 실행해도 되나요? | 아니오. Import는 **명령보다 Inventory가 먼저**다. ① 어느 State가 소유할지(단일 소유권), ② 사람·다른 State·controller 중 누가 계속 그 객체를 바꾸는지, ③ Import 후 첫 Plan이 replace/delete를 제안하면 멈출 수 있는지를 먼저 확인한다. RDS·Route53·ACM·KMS는 SPOF Gate(위험 민감 리소스 가이드)를 먼저 통과해야 한다. |
| Import는 무엇을 하고, 무엇을 하지 않나요? | **하는 일**: 기존 원격 객체의 identity를 Resource 주소에 연결하고, State에 binding과 관찰값을 기록해 이후 Plan 비교의 출발점을 만든다. **하지 않는 일**: 안전한 운영 코드를 자동 보장하지 않고, 하위 객체를 자동 편입하지 않으며, 기존 수동 변경자를 차단하지도, 데이터 백업·Rollback을 대신하지도 않는다. 즉 Import는 "binding"만 만들 뿐, 정합성·안전은 사람이 코드로 맞춰야 한다. |
| 같은 원격 객체를 두 개의 주소에 Import해도 되나요? | 안 된다. Terraform은 원격 API가 같은 객체임을 항상 안전하게 감지하지 못하기 때문에, 한 객체는 **하나의 State·하나의 주소**에만 binding한다. 다른 State에 같은 ID가 이미 있으면 Import를 멈추고 소유권부터 해결한다. |
| Import 후 첫 Plan에 replace/delete가 나오면 그대로 apply해도 되나요? | 안 된다. Import는 주소만 연결했을 뿐이라, 코드가 실제 객체와 다르면 Plan이 destroy/create나 in-place replace를 제안한다. 여기서 apply하면 운영 객체가 재생성·삭제된다. **apply를 멈추고** read-only/computed 값·기본값·민감 설정·하위 Resource를 현재 Provider 문서에 맞춰 코드를 정합화한 뒤, no-change에 가까운 Plan을 만든 다음 진행한다. |
| `-generate-config-out`로 생성된 Configuration을 그대로 써도 되나요? | 아니오. 생성된 설정은 초안 보조일 뿐 정답이 아니다. read-only/computed 값, 기본값, 민감 설정, 분리되어야 할 하위 Resource가 뒤섞여 있으므로 현재 Provider 버전 문서와 맞춰 **전부 다시 검토·재작성**한다. |
| `import` block과 `terraform import` CLI는 어떻게 다른가요? | `import` block은 코드로 남아 **리뷰·반복 가능한 Plan**을 만드는 기본 방식이다. `terraform import ADDRESS ID`는 State에 직접 binding하는 즉시 명령으로, 기존 운영·복구 사례를 이해하는 용도로 쓴다. 어느 쪽이든 Import ID의 형식은 Resource마다 다르므로 Provider의 Import section에서 identity 형식을 먼저 확인한다. |

## notes

### Import는 명령이 아니라 조사(Inventory) 작업이다
- 기존 객체 → 코드로 바로 끌어오지 않는다. `소유권·위험·ID 조사대`를 거쳐 Terraform 주소에 하나씩 연결한다.
- 흐름: 기존 원격 객체 → 계정·Region·owner 조사 → R1~R4 위험 분류 → Provider 문서에서 identity 확인 → Resource 주소·State 선택 → `resource` + `import` 블록 작성 → Import Plan 검토 → (replace/delete면 중단하고 코드 정합화 / 승인 가능하면) Import Apply.
- 오늘 반드시 가져갈 5가지: **단일 소유권 / 정확한 identity / 안정적인 주소 / 위험 등급 / 사전 백업**. 각각의 실패 위험과 evidence가 있다.

### Import Inventory — Import 전에 채우는 표
- AWS account/Region (대상 좌표)
- 실제 Resource 종류·이름 (Console/API 기준)
- Provider Resource type/version (Registry 기준)
- Import ID/identity (공식 문서 형식 — 이름을 ID로 추측 금지)
- 현재 변경 주체 (사람 / 다른 State / controller)
- 대상 State·Backend key (단일 소유권)
- 위험 등급 (R1~R4)
- 데이터·서비스 의존성 (사용자·downstream)
- 백업·복구 담당자 (승인된 evidence)
- RDS·Route53·ACM·KMS는 위험 민감 리소스 가이드의 **SPOF Gate**를 먼저 통과. 수업에서는 실제 운영 객체 대신 교육용 객체나 읽기 전용 Inventory로 대체 가능.

### 주소를 먼저 설계한다
```hcl
import {
  to = aws_s3_bucket.logs
  id = "existing-log-bucket"
}

resource "aws_s3_bucket" "logs" {
  bucket = "existing-log-bucket"
}
```
- 단일 Resource: `aws_s3_bucket.logs` — type과 local name 확인.
- `for_each` instance: `aws_s3_bucket.this["logs"]` — **key가 장기적으로 안정적인가**(key가 바뀌면 destroy/create).
- Module 내부: `module.storage.aws_s3_bucket.this` — Module input/output과 source version 확인.
- 기존 주소 이동: `moved` 블록 병행 — **Import와 주소 이동을 한 번에 섞지 않는다**.
- 주소는 이후 수명주기·리팩터링의 기준이므로 안정적으로 설계한다. 같은 객체를 두 주소에 Import하지 않는다.

### 선언적 Import vs CLI Import vs 설정 생성
- `import` block → 코드 리뷰·반복 가능한 Plan → **수업 기본 방식**.
- `terraform import ADDRESS ID` → State에 직접 binding → 기존 운영·복구 사례 이해용.
- `-generate-config-out` → import block 기반 설정 생성 보조 → **생성 코드 전부 재검토**.

### 사전 Stop 조건 (하나라도 걸리면 Import 중지)
| 발견 | 행동 |
|---|---|
| 대상 객체 owner 불명 | Import 중지 |
| 다른 State에 같은 ID 존재 | 중지 후 소유권 해결 |
| replace/delete 동반 | apply 금지, schema 정합화 |
| R2~R4인데 백업·승인 없음 | Import 중지 |
| Provider 버전과 문서 불일치 | lock/version 확인 후 재조사 |
| State 백업 복구 불가 | 먼저 복구 훈련부터 |

### 실습 개요 (labs/import-hands-on)
- 원격 비용 없이 `terraform_data` identity를 Import하는 랩. `init → fmt -check → validate → plan` 순서.
- Plan에서 `1 to import` 표시·대상 주소·ID를 찾고, **apply하지 않고** `import-plan-review.md`를 먼저 작성한다.

### Evidence 수준
- 0: ID와 import 명령만 있고 owner·State·위험 근거 없음.
- 1: 주소·문서는 확인했지만 백업·Stop 조건 누락.
- 2: 좌표·owner·identity·주소·위험 등급·백업·Plan Gate를 모두 연결.

### 공식 문서
- Import overview: https://developer.hashicorp.com/terraform/language/import
- Import block: https://developer.hashicorp.com/terraform/language/block/import
- Resource addressing: https://developer.hashicorp.com/terraform/cli/state/resource-addressing

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
