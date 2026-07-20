# 7교시: 공통 Module과 환경별 Root Module 나누기

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 파일을 `network.tf`와 `compute.tf`로 나누면 Module이 둘인가요? | 아니오. 한 디렉터리 안의 모든 `.tf`는 합쳐져 **하나의 Module**로 평가된다. 파일 분리는 가독성·소유권 표시일 뿐 경계가 아니다. Module 경계는 디렉터리 단위이고, `module` 블록으로 호출할 때 새 경계가 생긴다. |
| 같은 Child Module을 호출하면 dev와 prod가 같은 State를 쓰나요? | 아니오. State는 Child가 아니라 **Root Module + Backend** 단위로 분리된다. 같은 Child Module을 호출해도 dev·prod는 별도 Root, 별도 Backend key라서 별도 State를 가진다. 코드 재사용 경계(Module)와 장애·권한·승인 경계(State)는 다르다. |
| Child Module 안에 AWS Region과 Provider 인증을 고정해도 될까요? | 아니오. Provider Configuration(region·credential)은 **Root Module**에 둔다. Child는 `required_providers`로 소스·버전 요구만 선언한다. Child에 인증·Region을 고정하면 다른 계정/리전에서 재사용이 막히고 환경 분리가 깨진다. |
| Module로 옮긴 뒤 Plan에 destroy/create가 나오면 그대로 적용해도 될까요? | 아니오. 주소만 바뀐 리팩터링인데 destroy/create가 나오면 실제 리소스가 **재생성**된다. `moved` 블록으로 주소 이동을 선언한 뒤 Plan에서 destroy/create가 사라졌는지(이동만 남았는지) 확인하고 apply한다. |

## notes

### Root Module과 Child Module의 책임 경계
- **Root Module** = `terraform` 명령을 실행하는 그 디렉터리. Backend, Provider Configuration, 환경별 입력값, 실행·승인 책임을 진다.
- **Child Module** = `module` 블록으로 호출되는 재사용 단위. 반복되는 Resource 구조를 **입력(variables) → 출력(outputs) 계약**으로 묶는다.
- Module은 세 요소로 구성된다: 입력 변수(`variable`), 리소스/데이터 정의, 출력 값(`output`). 호출 측은 입력만 주고 출력만 받으며 내부 구현은 캡슐화된다.
- 코드를 재사용하는 경계(Module)와 장애·권한·승인 경계(State)는 별개다. 같은 Child Module을 써도 dev/prod는 별도 Root·별도 State여야 실패 영향과 접근 권한이 분리된다.

### source와 버전 고정
- `source`는 로컬 경로(`../../modules/service`), Terraform Registry(`namespace/name/provider`), Git(`git::https://...`), S3/GCS 등을 지원한다.
- Registry·Git Module은 `version`(또는 Git `ref`/tag)으로 **버전을 고정**한다. 고정하지 않으면 다음 `init`에서 다른 버전이 들어와 재현성이 깨진다.
- 로컬 경로 Module은 버전 인자가 없다. 같은 리포지토리에서 함께 변경되므로 커밋으로 버전을 관리한다.

### Provider 전달
- Child는 기본적으로 Root의 Provider Configuration을 **암묵 상속**한다. Region/인증을 Child에 고정하지 않는다.
- multi-region·multi-account처럼 alias Provider를 명시적으로 넘겨야 할 때만 `providers = { aws = aws.seoul }` 형태로 **명시 전달**한다.
- Module은 Provider의 모든 argument를 그대로 노출하는 wrapper가 아니라, "반복할 표준"과 "선택 가능한 차이(입력 변수)"를 나누는 인터페이스다. 과도하게 모든 것을 변수로 열면 표준화 이점이 사라진다.

### 환경 분리 — Workspace를 기본 해법으로 쓰지 않는 이유
- CLI Workspace는 같은 Backend·같은 자격증명 위에서 State만 복제한다. dev/prod처럼 **별도 계정·별도 자격증명·강한 접근제어**가 필요한 분리에는 부적합하다.
- 환경 분리의 기본은 **환경별 Root Module 디렉터리 + 환경별 Backend key + 환경별 IAM Role**이다. dev 실수가 prod 자격증명·State에 닿지 못하게 한다.

### 안전한 리팩터링 (`moved` 블록)
- 파일 이동이나 Module 추출로 리소스 **주소**가 바뀌면 Terraform은 옛 주소 destroy + 새 주소 create로 해석할 수 있다.
- `moved` 블록으로 이동을 선언하면 State 주소만 갱신되고 실제 리소스는 유지된다. Plan에서 destroy/create가 사라졌는지 반드시 확인한다.

```hcl
moved {
  from = terraform_data.service
  to   = module.service.terraform_data.this
}
```

### Module 반복
- 같은 Child Module을 여러 인스턴스로 만들 때 `count`(개수 기반) 또는 `for_each`(키 기반)를 쓴다. 추가/삭제가 잦으면 인덱스가 밀리는 `count`보다 `for_each`가 안전하다.
