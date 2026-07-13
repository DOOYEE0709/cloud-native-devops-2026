# 1교시: IaC와 Terraform, 어디까지 맡길 것인가

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 적용 판단표 (도입 여부 판단)

대상 상황(하나 선택): 교육용 AWS VPC·EC2 환경 / 팀 공용 GitHub Repo 설정 / 매일 지우고 다시 만드는 테스트 환경 / 운영 DB Parameter 변경

> 선택한 상황: **교육용 AWS VPC·EC2 환경**

| 항목 | 판단 |
|---|---|
| 관리하려는 객체와 소유 팀 | VPC·Subnet·IGW·Route Table·Security Group·EC2. 소유는 교육/실습 팀(수강생 개인 계정 또는 공용 학습 계정) |
| 반복 생성 또는 변경 빈도 | 높음. 매 실습마다 만들고 지우고를 반복, 여러 수강생이 같은 구성을 각자 재현 |
| Terraform을 쓰면 줄어드는 수동 작업 | Console 클릭으로 VPC→Subnet→IGW→Route→SG→EC2 순서대로 만드는 반복 작업, AZ·CIDR 수동 입력 실수 |
| 잘못된 apply의 영향 | 교육용이라 범위는 제한적. 다만 SG를 0.0.0.0/0으로 열거나 EC2 인스턴스 타입을 크게 잡으면 노출·비용 사고 가능 |
| State에 들어갈 수 있는 민감정보 | EC2 key pair 이름, private IP, (사용 시) user_data 내 자격증명. `sensitive`는 출력만 가리고 State엔 그대로 저장됨 주의 |
| 비용 증가 가능성 | 낮게 유지 가능(t3.micro·프리티어, 실습 후 destroy). NAT Gateway·EIP·미삭제 EC2가 새어나가면 비용 발생 |
| 승인자와 복구 담당자 | 승인: 강사. 복구: 각 수강생이 `terraform destroy` 후 재`apply`로 재현. 학습 계정이라 Rollback 부담 작음 |
| Terraform 적용 / 다른 도구 / 수동 유지 | **Terraform 적용**. 단 EC2 내부 패키지·앱 설정은 cloud-init(user_data)로 분리, 실습 종료 시 반드시 `destroy` |

> 좋은 답은 "Terraform 쓰면 편해요"로 끝나지 않는다. 어떤 객체를 어떤 State에서 관리하고, 잘못된 변경을 누가 어디서 발견해 어떻게 복구할지까지 적는다.

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Terraform 코드와 실제 AWS 리소스 중 무조건 유일한 진실의 원천은? | 어느 쪽도 단독으로 유일한 진실이 아니다. 코드=원하는 상태, 실제 AWS 객체=실제 상태, State=둘의 binding. 세 가지가 어긋난 게 Drift. 하나로 단정하지 말고 세 층으로 나눠 봐야 한다. |
| `plan`이 성공하면 보안·비용 검토도 끝난 것인가? | 아니다. Plan은 생성·수정·교체·삭제 예정 변경을 보여줄 뿐, 보안·비용·사업적 타당성은 승인하지 않는다. 사람이 별도 기준으로 검토해야 한다. |
| EC2 내부 앱 설정을 전부 Terraform으로 관리하면 어떤 변경 경계가 섞이나? | 인프라 수명주기(EC2 생성·교체, 드물게 변경)와 OS 내부·앱 설정(배포마다 자주 변경)의 변경 주기가 섞인다. 앱 설정은 cloud-init·Ansible·이미지 빌드나 CI/CD가 적합하고, 같은 객체를 두 도구가 동시에 소유하면 충돌한다. |
| 이 리소스를 Terraform / 다른 도구 / 수동 중 무엇에 맡길지와 근거는? | (예: 교육용 VPC·Subnet·IAM Role → Terraform. 반복 생성·의존성 있고 Plan으로 검토 가능. 단 EC2 내부 앱 설정은 cloud-init로 분리, State는 원격 Backend, 삭제·복구 담당자 지정.) — 실제 대상 골라 확정 기입 |

## notes

**IaC의 핵심은 `Code`가 아니라 `변경 근거`.** Git에 파일이 있다는 사실만으로 재현성이 생기지 않는다. 버전·입력값·실행 환경·State 위치·승인 절차까지 함께 고정돼야 다른 사람이 같은 결과를 만든다.

**선언형 vs 명령형**
- 명령형: 원하는 결과에 도달하는 절차를 적는다 ("서버 만들고 이름 바꾸고 SG 붙인다").
- 선언형: 최종 상태를 적고 도구가 현재 상태와 비교해 필요한 작업을 계산한다 ("이 서버는 이 이름·이 SG를 가진 상태여야 한다").
- 선언형이라고 순서가 사라지는 건 아니다. Terraform은 참조 관계로 의존성 그래프를 만들어 순서를 계산하고, 그 순서가 의도와 맞는지는 Plan에서 확인한다.
- Workflow는 한 방향이 아니라 작성 → State/현재 비교 → Plan → 검토 → Apply → State 갱신 → 다시 비교의 **피드백 루프**.

**구성요소 경계 (하는 일 / 하지 않는 일)**
- Terraform Core: 설정 읽고 의존성·Plan 계산. AWS 리소스 세부 규칙은 직접 구현 안 함.
- Provider: 리소스 스키마 제공 + 외부 API 호출. 팀 비용·보안 정책은 결정 안 함.
- Configuration: 원하는 상태·참조 관계 표현. 실제 객체 존재 자체는 보장 안 함.
- State: Resource 주소 ↔ 실제 객체 identity의 **binding** + 관찰된 속성 저장. Secret 보관소·백업이 아님.
- Plan: 예정된 변경을 보여줌. 사업적 타당성 승인은 안 함.
- ⚠️ "State = 현재 인프라 그 자체"는 부정확. 코드(원하는 상태) / State(binding) / 실제 인프라(AWS) 세 가지가 어긋나는 게 **Drift**. State는 Day4에서 파일 직접 관찰.

**Terraform이 잘 맞는 신호** — 같은 구성 반복 생성, 변경 전 영향 검토 필요, 리소스 의존성 복잡, 여러 사람이 같은 인프라 관리, 삭제·복구 절차 필요.

**Terraform보다 다른 도구가 나은 영역**
- VM 내부 패키지·설정 → cloud-init / Ansible / 이미지 빌드
- 컨테이너 배포·복구 → Kubernetes
- Kubernetes 패키지 구성 → Helm
- 빌드·테스트·배포 승인 → CI/CD
- 장애 중 원인 탐색 → CLI·로그·관찰 도구
- 경계가 겹치면 **같은 객체를 두 도구가 동시에 소유하지 않게** 정한다.

**장점 뒤에 붙는 조건** — 장점은 자동으로 안 생긴다.
- 재현성 ← Provider·Module 버전·입력값 고정
- 변경 이력 ← Git diff + Plan 같이 리뷰
- 빠른 배포 ← 최소 권한·승인 단계 (없으면 잘못된 변경도 더 빨리 퍼짐)
- 협업 ← Remote Backend + Locking
- 복구 ← State·데이터 백업 + Rollback 절차 검증
- 요지: "자동화했으니 안전"이 아니라 "자동화했으니 같은 실수를 더 넓게 반복할 수도 있다".

**자주 나오는 오해**
- Terraform은 AWS 전용 → Provider로 API 기반 시스템 다양하게 관리.
- 선언형이면 실행 순서 몰라도 됨 → 의존성은 자동이지만 Resource 교체 영향은 Plan에서 검토.
- State는 지워도 다시 조회하면 됨 → binding 잃으면 중복 생성·잘못된 Import·삭제 위험.
- Git에 올리면 협업 준비 끝 → Backend·Locking·권한·승인·Secret 처리가 더 필요.
- `sensitive` 쓰면 Secret이 State에 안 남음 → 출력 표시만 제한, State 저장 여부와는 별개.

**공식 문서** — What is Terraform (`providers`, `Write/Plan/Apply`, `resource graph`), Core workflow (`review the final plan`), Language overview (`resources/blocks/arguments/expressions`).

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
