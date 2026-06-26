# 1교시: Git 이론과 변경 이력 모델

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| `git status -sb` | `## main...origin/main`, `?? week3/day3/` → day3 폴더가 untracked |
| `git branch --show-current` | `main` |
| `git log --oneline -5` | 최근 commit `15af82d docs: add README ...` 등 docs 커밋 5개 |
| `git remote -v` | `origin` = `github.com/DOOYEE0709/cloud-native-devops-2026` (fetch/push) |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| Git은 파일 백업 도구인가? | 아니다. commit으로 이어진 변경 이력 그래프다. |
| `??` 의 의미는? | untracked file — 아직 git이 추적하지 않는 파일 |
| working tree와 staging area의 차이? | working tree=현재 파일 상태, staging area=다음 commit에 포함할 변경 |
| 인프라 엔지니어에게 Git이 중요한 이유? | Terraform/K8s manifest/workflow 변경을 누가·언제·무엇을 바꿨고 어떤 commit을 배포했는지 추적 |

## notes

```text
# W3D3S1 Git Model
- current branch: main
- modified files: 없음 (day3/ 폴더 전체가 untracked)
- remote: origin = github.com/DOOYEE0709/cloud-native-devops-2026
- latest commit: 15af82d docs: add README with lesson index for week3 day2
- tag use case: 배포한 특정 commit에 버전 고정 (예: 0.1.0)
```

핵심: working tree → staging → commit → branch → remote 흐름. Git 이력을 이해해야 GitHub Actions/배포 자동화도 안정적으로 다룰 수 있다.

### 강의 메모 — 서비스 분리와 데이터 의존성 (강사님구두 설명)
> 강의자료 갱신으로 lesson-01 이미지는 `lesson-01-git-history-model.png`(Git 이력 모델)로 교체됨.
> 아래는 갱신 전 이미지(서비스 분리/데이터 의존성)를 보며 강사님이 구두로 설명하신 내용 — 메모 자체는 유효.
- 그림 주제: 서비스별 데이터 책임(권장) vs 공유 DB 위험(비권장). data ownership / schema coupling / 접근 경계가 포인트.
- 강사님 코멘트: "function마다 try-catch를 하기에는 힘들다."
  - 의미: 데이터 의존성·결합이 강하면 실패 경로가 너무 많아져 함수마다 방어적 try-catch를 거는 건 비현실적.
  - 그래서 함수 단위 방어보다 **서비스 경계(ownership/boundary) 설계**로 실패 전파를 차단하는 게 우선.

### 메모 — `git status -sb` 옵션
- `-s` (`--short`): 짧은 형식. 안내문 없이 파일 상태를 2글자 코드로 표시.
- `-b` (`--branch`): 짧은 형식에서도 맨 위에 현재 branch/원격 상태 줄(`## main...origin/main`) 추가. (`-s` 단독은 branch 줄 없음)
- `-sb` = 둘 합침 → branch 상태 + 파일 상태를 한눈에. CI/스크립트에서 빠르게 보기 좋아 자주 씀.
- 2글자 코드는 `[staged][working tree]` 순서:
  - `??` untracked / ` M` 수정(미staged) / `M ` staged / `MM` staged 후 또 수정 / `A ` 새로 추가(staged)
- `git status`(기본)만 써도 틀린 건 아님. `-sb`는 같은 정보를 압축 + branch 상태까지 보여주는 빠른 버전.

### 강의 메모 — 쿠버네티스 맛보기 (1교시 시작 전 예고)
> 1교시 본 내용 아님. 다음에 배울 쿠버네티스 맛보기로 언급된 내용.
- resource request 예시: cpu 25m(추정, millicore), memory 32Mi(추정, 단위 기억 불확실). 이 정도 하드웨어 리소스가 부족할 수 있다.
- 부족하면 → EC2(더 큰 인스턴스)를 쓰면 된다.
- 다만 이 강의(다음 쿠버네티스 파트)에서는 **최대한 하드웨어 성능을 끌어다 쓰는 법**도 알려줄 예정.
  - 이걸 할 줄 알면 "어느 정도 쿠버네티스를 다룰 줄 안다"는 수준이 된다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
