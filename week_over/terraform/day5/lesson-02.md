# 10교시: Import 실행 후 no-change Plan까지 맞추기

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| `Import successful` 메시지가 나오면 Terraform 전환이 끝난 건가요? | 아니오. Import 성공은 **binding이 생겼다**는 뜻일 뿐, 여기서부터가 실제 작업이다. ① `state list/show`로 주소·ID가 맞는지 검증하고, ② Configuration을 실제 운영 의도와 맞추고, ③ **변경 없음(no-change) 또는 승인 가능한 최소 Plan**을 만들어야 전환이 끝난다. binding이 성공해도 코드와 실제 객체가 다르면 다음 apply에서 수정·교체·삭제가 발생한다. |
| Import 직후 `terraform plan`에 나오는 차이를 어떻게 분류하나요? | 4가지로 나눈다. **update in-place(`~`)** = 관리 argument 누락·기본값 차이 → schema·운영 의도 확인. **replace(`-/+`)** = identity나 immutable argument 불일치 → apply 금지, ID/주소/config 재검토. **destroy(`-`)** = 코드·주소·`for_each` key 누락 → 소유권 확인 전 apply 금지. **계속 바뀌는 값** = 외부 controller 또는 정규화 → owner·Provider 이슈 조사. **no changes** = binding과 config 일치 → probe·handoff로 진행. |
| Plan의 `-/+`와 `+/-`는 무엇이 다르고, `create_before_destroy`는 안전을 보장하나요? | `-/+`는 **삭제 후 생성**(순단 위험 높음), `+/-`는 **생성 후 삭제**(위험을 낮추지만 0은 아님)이다. `create_before_destroy`는 교체 순서를 `+/-`로 바꾸는 lifecycle 규칙일 뿐, 새 객체가 실제 healthy해지고 traffic이 넘어갔는지까지 보장하지 않는다. RDS identifier·Route53 zone·고정 IP처럼 동시에 둘을 만들 수 없거나 identity가 중요한 객체에서는 오히려 실패할 수 있다. |
| Import 후 어떤 속성이 계속 바뀔 때 `ignore_changes`부터 쓰면 되나요? | 아니오. `ignore_changes`는 **첫 해결책이 아니다**. 외부 시스템이 실제로 소유하는 속성일 때만 owner와 관찰 경로를 문서화한 뒤 제한적으로 쓴다. RDS·DNS·ACM의 설정 차이를 조용히 숨기는 용도로 쓰면 안 된다 — 숨은 Drift가 그대로 방치된다. |
| 잘못 Import했을 때 `terraform state rm`을 쓰면 원격 객체가 삭제되나요? | 아니오. `state rm`은 **Terraform의 binding만 제거**하고 원격 객체도 Configuration도 삭제하지 않는다. 다만 `resource` 블록이 남아 있으면 다음 Plan이 그 객체를 **새로 생성하자고 제안**할 수 있다. 실행 전 State 백업과 주소·ID 기록이 필요하고, 실제 운영 객체에서는 즉시 apply하지 않는다. |
| 전환이 "끝났다"고 말하려면 무엇이 남아야 하나요? | **Handoff 문서**다. 다음 운영자가 소유권과 복구를 이어받도록 account/Region, Provider·버전, Terraform 주소, remote ID, Backend key·State owner, 위험 등급·의존성, Import run·승인자, 최종 Plan summary, 외부 owner·ignored 속성, health probe, 백업·rollback, 다음 허용 변경 창구를 남긴다. 이게 없으면 수동 변경이 재발한다. |

## notes

### `Import successful`부터가 시작이다
- binding 성공 ≠ 전환 완료. 오른쪽 **차이 검토판**을 본다: Configuration과 실제 객체가 다르면 다음 apply에서 update/replace/destroy가 발생.
- 실행 흐름: 검토한 Import Plan → `apply tfplan` → `state list/show`로 ID 확인 → 다시 `plan` → (누락 설정이면 config 보완 / 외부 owner면 소유권 분리 / replace·delete면 즉시 중단) → No changes면 handoff·관찰 전환.
- 완료 기준 = **no-change 또는 설명 가능한 최소 Plan**. 숨은 Drift를 방치하지 않는다.

### 저장 Plan으로 실행한다 (왜 `-out`인가)
```bash
terraform plan -out=tfplan
terraform apply tfplan
terraform state list
terraform state show terraform_data.legacy
```
- `apply tfplan`은 **검토한 그 Plan을 그대로** 실행. 검토 없이 `apply`만 치면 새로 계산된 Plan이 다른 변경을 포함할 수 있다.
- 실습 ID는 `legacy-service-001`. `terraform_data`는 교육용이라 실제 API 검증은 없지만 import block→Plan→State 주소 흐름은 동일하게 관찰된다.

### Import 후 Plan 차이 분류
| Plan 차이 | 원인 후보 | 행동 |
|---|---|---|
| update in-place `~` | 관리 argument 누락·기본값 차이 | schema·운영 의도 확인 |
| replace `-/+` | identity·immutable argument 불일치 | **apply 금지**, ID/주소/config 재검토 |
| destroy `-` | 코드·주소·for_each key 누락 | 소유권 확인 전 apply 금지 |
| 계속 바뀌는 값 | 외부 controller·정규화 | owner·Provider 이슈 조사 |
| no changes | binding과 config 일치 | probe·handoff 진행 |

### Plan 기호 — 신규 추가와 교체를 따로 읽는다
| action | 의미 | 순단 가능성 | 적용 전 확인 |
|---|---|---|---|
| `+` | 기존 유지 + 새 객체 추가 | 보통 직접 순단 없음 | 비용·연결·중복 역할 |
| `-/+` | 삭제 후 생성 | 높음 | 데이터·endpoint·복구 시간·maintenance window |
| `+/-` | 생성 후 삭제 | 낮출 수 있으나 0 아님 | 이름 충돌·traffic 전환·동시 비용·readiness |
| `~` | 제자리 수정 | 속성에 따라 재시작 | Provider/AWS 적용 방식 |
| `-` | 삭제 | 매우 높음 | 백업·의존 서비스·승인자 |
- `create_before_destroy` = 교체 순서를 `+/-`로 바꾸는 lifecycle. **healthy·traffic 전환까지는 보장 안 함.** RDS·Route53 zone·고정 IP에서는 실패 가능.

### 실습: 교체·신규 추가 비교 (관찰만, apply 금지)
- `-var='add_compute=true'` → `terraform_data.new_compute[0]`가 순수 `+`인지, legacy는 무변경인지 분리 기록.
- legacy에 `triggers_replace = ["replacement-experiment"]` 임시 추가 → `-/+` 관찰. legacy가 RDS·DNS였다면 필요한 probe·변경 창구 기록.
- 이어서 `lifecycle { create_before_destroy = true }` 추가 → 기호가 `+/-`로 바뀌는지 비교.
- 비교 후 임시 argument·lifecycle **모두 제거**하고 원복 → 다시 Plan해 no-change 확인.
- `ignore_changes`는 첫 해결책 아님. 외부 소유 속성일 때만 owner·관찰 경로 문서화 후 제한적으로.

### AWS 전환 추가 probe / 금지 신호
| 대상 | Import 후 probe | 금지 신호 |
|---|---|---|
| RDS | endpoint 연결·snapshot·backup 상태 | replacement, deletion protection 해제 |
| Route 53 | 권한 있는 DNS 조회·NS/TTL | hosted zone replacement/delete |
| ACM | 인증서 상태·validation·TLS handshake | validation record 삭제, listener 이탈 |
| KMS | key state·alias·decrypt canary | key policy 축소, deletion schedule |
| Compute | health check·instance/ASG 상태 | 데이터가 로컬에만 존재 |

### 잘못 Import했을 때 — `state rm`
```bash
terraform state rm terraform_data.legacy
```
- **binding만 제거**. 원격 객체·Configuration은 안 지움. resource 블록이 남으면 다음 Plan이 새 객체 생성을 제안.
- 실행 전 State 백업 + 주소·ID 기록 필수. 실제 운영 객체는 즉시 apply 금지.

### Handoff 문서 항목
account/Region · Provider·버전 · Terraform 주소 · remote ID · Backend key/State owner · 위험 등급·의존성 · Import run URL·승인자 · 최종 Plan summary · 외부 owner/ignored 속성 · health probe · 백업·rollback · 다음 허용 변경 창구.

### 실습 정리 (교육용만)
```bash
terraform state rm terraform_data.legacy
rm -f tfplan terraform.tfstate terraform.tfstate.backup
```
- **실제 원격 Resource에서는 State 파일을 shell로 삭제하지 않는다.** 승인된 Backend 복구 절차와 State 명령 사용.

### 공식 문서
- Import resources: https://developer.hashicorp.com/terraform/language/import
- Import block: https://developer.hashicorp.com/terraform/language/block/import
- State commands: https://developer.hashicorp.com/terraform/cli/commands/state

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
