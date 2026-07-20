# 8교시: State와 Backend를 팀 운영 경계로 설계하기

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| S3에 State를 저장하면 자동으로 Locking도 켜지나요? | 아니오. 저장 위치와 Locking은 별개다. `use_lockfile = true`를 명시해야 `.tflock` 객체로 Lock이 걸린다. 켜지 않으면 두 사람의 apply가 동시에 실행돼 State가 손상될 수 있다. |
| State 읽기 권한은 단순 조회 권한인가요? | 아니오. State에는 resource attribute와 민감값(비밀번호, 토큰, 키)이 그대로 담길 수 있어 **읽기도 강한 권한**이다. 최소 권한, 저장 암호화, 접근 감사(CloudTrail 등)가 필요하다. |
| `terraform init -reconfigure`가 Local State를 자동으로 새 Backend에 복사하나요? | 아니오. `-reconfigure`는 기존 Backend 연결을 버리고 새 설정으로 **초기화만** 한다(복사 없음). State 복사는 `-migrate-state`가 한다. 새 Backend가 비어 있으면 기존 객체를 새로 만들려는 Plan이 날 수 있으므로 apply 전에 중단한다. |
| Lock이 오래됐으면 바로 `terraform force-unlock` 해도 되나요? | 아니오. 다른 apply/CI/HCP run이 아직 실행 중인지, 어떤 작업이 만든 Lock인지, API는 변경됐는데 State 기록 전 실패한 **부분 적용**은 아닌지, 누가 승인·재검증하는지 먼저 확인한다. 무단 해제는 경쟁 apply와 State 손상을 부른다. |
| Backend block에서 `var.environment` 같은 변수를 참조할 수 있나요? | 아니오. Backend block은 변수·resource attribute를 참조할 수 없다. Partial Configuration(`-backend-config` 파일)이나 CI 입력으로 채우되, credential은 넣지 말고 OIDC·환경변수·표준 credential chain으로 주입한다. |

## notes

### 세 상태를 함께 본다
- Configuration(원하는 상태) / State(Terraform 주소 ↔ 원격 identity의 binding + 관찰값) / 실제 원격 객체 — Plan은 이 셋을 비교한다.
- Console·다른 도구가 실제 객체만 바꾸면 State와 어긋나 **Drift**가 생긴다. `plan`이 예상치 못한 변경을 내면 대개 Drift 신호다.
- State는 인프라의 절대 진실이 아니라 "관리 중인 주소와 원격 ID의 binding"이다. 파일을 직접 편집하지 않고 `state list/show/pull` 같은 지원 명령만 쓴다.

### State 파일 내부와 명령
- State에는 `serial`(변경마다 증가하는 번호)과 `lineage`(State 계보 ID)가 있다. migration 전후로 이 값을 비교해 같은 State인지, 갱신됐는지 확인한다.
- 주요 명령: `state list`(관리 주소 목록), `state show <주소>`(주소↔실제 값·ID 확인), `state pull`(현재 State를 stdout으로 읽어 백업·진단), `state mv`(주소 이동), `state rm`(추적만 해제, 실제 객체는 유지), `import`(기존 객체를 State에 편입).
- `state push`는 State를 통째로 덮어쓸 수 있어 일반 운영에서 금지하고, 복구 승인 시에만 쓴다.
- 다른 State의 출력을 읽어야 하면 `terraform_remote_state` data source를 쓴다. State 전체가 아니라 `output`으로 노출한 값만 참조하도록 최소화한다.

### Local vs Remote Backend
- Remote(S3, GCS, azurerm, HCP Terraform 등)는 중앙 공유, IAM/RBAC 접근제어, 버전 복구가 가능하다. Local은 파일 전달 위험·덮어쓰기·별도 백업 부담이 있다.
- 단, State에는 민감값이 들어가므로 Remote라고 자동으로 안전한 게 아니다. 암호화·최소 권한·감사가 함께 있어야 한다.

### State 경계 설계
- 분리 축: 환경(dev/prod), 위험 등급(R1 Compute · R2 Data · R3 Domain · R4 Security), 팀 소유권, 변경 주기.
- 나누는 이유: 계정·승인·실패 영향 분리, 자동 복구 정책 분리, SPOF·break-glass 승인 분리, 잦은 앱 배포가 기반 리소스를 잠그지 않게 함.
- 경계는 코드만이 아니라 **Backend key와 IAM Role까지** 함께 나눠야 Blast Radius가 실제로 제한된다. 예) R1 자동 복구 Role이 R2~R4 Backend key를 읽거나 쓰지 못하게 IAM을 분리한다.

```text
state/
├── dev/services/replaceable.tfstate
├── prod/services/replaceable.tfstate
├── prod/foundation/data.tfstate
├── prod/foundation/domain.tfstate
└── prod/foundation/security.tfstate
```

### S3 Backend와 Locking
- 현재 공식 Locking은 `use_lockfile = true`(`.tflock` 객체) 방식이다. DynamoDB 기반 Lock은 deprecated이므로 새 설계에 옛 예제를 복붙하지 않는다.
- State bucket에는 **Versioning**을 켜 복구 지점을 남기고, 기본 암호화(KMS), public access 차단, TLS 강제, State 삭제 권한 제한(+break-glass)을 둔다.

```hcl
terraform {
  backend "s3" {
    bucket       = "organization-terraform-state"
    key          = "prod/foundation/domain/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
```

| 보호 항목 | 확인할 것 |
|---|---|
| 저장 암호화 | bucket 기본 암호화, KMS 키 권한 |
| 전송·접근 | TLS, public access 차단, 최소 IAM |
| Lock | `.tflock` Get/Put/Delete 권한, 충돌 동작 |
| 버전 | bucket versioning, 보존 기간, 복구 시험 |
| 감사 | CloudTrail data event 또는 조직 감사 정책 |
| 삭제 | State object 삭제 권한 제한, break-glass 승인 |

### Backend에는 변수를 못 쓴다
- Backend block은 `var.*`나 resource attribute를 참조할 수 없다. Partial Configuration 파일이나 CI 입력으로 채운다.
- credential을 `-backend-config`로 넘기면 `.terraform/`과 저장된 Plan에 남을 수 있다. 인증은 OIDC, 환경변수, 표준 credential chain으로 주입한다.

### 이전 vs 재설정
| 명령 | 의미 | 사용할 때 |
|---|---|---|
| `terraform init -migrate-state` | 기존 State를 새 Backend로 복사 시도 | Local→Remote 또는 Backend 이동 |
| `terraform init -reconfigure` | 기존 연결을 버리고 새 설정으로 초기화(복사 안 함) | 이미 대상 State가 있어 migration이 불필요할 때 |
| `terraform state pull` | 현재 State를 stdout으로 읽음 | 승인된 백업·진단 |
| `terraform state push` | State를 덮어쓸 수 있음 | 일반 운영 금지, 복구 승인 시에만 |

- `-reconfigure`를 migration 대신 쓰면 기존 State가 새 위치로 옮겨지지 않는다. 새 Backend가 비어 있으면 기존 객체를 새로 만드는 Plan이 날 수 있으므로 apply 전에 멈춘다.

### Migration Runbook
1. 모든 apply를 중지하고 변경 창구를 하나로 제한한다.
2. 현재 Backend, workspace, State serial, Resource 주소를 기록한다.
3. `terraform state pull` 결과를 승인된 암호화 위치에 백업한다.
4. 대상 bucket, key, versioning, encryption, Lock, IAM을 확인한다.
5. Backend 설정을 바꾸고 `terraform init -migrate-state`를 실행한다.
6. 새 Backend에서 `state list`와 `plan`을 확인한다.
7. no-change가 아니면 apply하지 않고 이전·새 State를 비교한다.
8. 복구 담당자, backup version ID, 검증 결과를 handoff에 남긴다.

### force-unlock 전 확인
- 다른 사람/CI apply가 실행 중인가, Lock ID가 어떤 State·작업이 만든 것인가, HCP/CI run이 대기·실행 중인가, API는 변경됐는데 State 기록 전 실패한 부분 적용인가, 누가 강제 해제를 승인하고 재검증하는가.

### GitOps와 Backend
- 예약 Drift 복구는 GitHub `concurrency`만으로 부족하다. 다른 CI·로컬 실행·HCP run이 같은 State를 건드릴 수 있으므로 **Backend Locking**이 필요하다. 위험 등급별 IAM 분리와 함께 설계한다.
