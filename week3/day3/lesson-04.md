# 4교시: Branch 전략 - dev, stage, prod

## 실습 확인 기록

> 개념 + 실습 질문 중심 (셸 실습 없음). 가정: W3D2 `order-worker` 변경을 운영에 반영.

| 질문 (order-worker promotion) | 답 |
|---|---|
| dev에서 먼저 확인할 것 | 기능 회귀, unit test 통과, dev 환경 정상 실행 |
| stage에서 확인할 것 | 운영 유사 환경 통합 동작, 연동(큐 등)·배포 절차 검증 |
| prod에 바로 들어가면 안 되는 이유 | 미검증 변경이 사용자/장애로 직결, 롤백 비용·데이터 손상 위험 |
| Docker image tag 고정 단계 | build 시점(dev)에 고정 → 같은 tag를 재build 없이 stage/prod로 promotion |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| dev/stage/prod branch 전략의 가장 큰 단점? | branch drift (세 branch가 서로 달라짐) + cherry-pick/conflict 증가 |
| main + Environment 전략의 장점? | 코드 이력 단순, 같은 commit을 환경별 gate로 promotion, CI/CD와 잘 맞음 |
| branch와 environment의 관계? | branch가 환경을 표현할 수 있으나 항상 정답 아님. 분리해서 생각 |
| 진짜 추적해야 하는 것? | 같은 commit·같은 image가 어떤 gate를 거쳐 dev→stage→prod로 올라가는지 |

## notes

### 전략 1: dev/stage/prod branch
- 흐름: `feature/* → dev → stage → prod`.
- 장점: 환경별 승인 명확, 운영팀 이해 쉬움, hotfix 경로 분리.
- 단점: branch drift, cherry-pick 증가, 오래된 branch conflict 증가.

### 전략 2: main + GitHub Environment
- 흐름: `feature/* → main → environment gate로 dev/stage/prod 배포`.
- 장점: 코드 이력 단순, environment approval로 환경 정책 분리, 같은 commit promotion.
- 단점: 초기 workflow/environment 설계 필요, "branch=환경" 사고에서 전환 필요.

### 선택 기준
- 초급 팀·환경 승인 가시화 → dev/stage/prod branch.
- CI/CD 성숙·자동화 중심 → main + environment.
- 릴리스 주기 길고 hotfix 많음 → Git Flow 일부. / 빠른 웹 서비스 → GitHub Flow.

### Evidence Note
```markdown
# W3D3S4 Branch Strategy
- selected model: main + GitHub Environment (자동화 중심 가정)
- dev gate: unit test, 기능 회귀 확인
- stage gate: 통합 동작, 배포 절차 검증, approval
- prod gate: 최종 approval, 같은 image tag promotion
- drift risk: main 단일화로 낮음 (branch 다중화 시 높음)
- image tag policy: build 시점 고정, 재build 없이 환경 promotion
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
