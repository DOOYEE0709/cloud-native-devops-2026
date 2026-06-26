# 2교시: 개발자가 많이 쓰는 GitHub 흐름

## 실습 확인 기록

> 2교시는 셸 실습보다 GitHub 협업 모델(개념) 중심.

| 명령/확인 | 결과 |
|---|---|
| 개발자 기본 흐름 | issue → branch → code → commit/push → PR → review → status check → merge |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| GitHub를 잘 쓴다는 의미는? | commit을 많이 하는 게 아니라, 변경을 reviewer·CI가 이해할 단위로 쪼개는 것 |
| `main` branch를 어떻게 유지? | 항상 배포 가능한 안정 상태로 유지 |
| PR을 작게 만드는 이유? | review 가능성↑, 충돌·drift 감소 |
| merge 전 무엇을 통과해야? | CI status check(test/lint/build) |
| Code owner의 역할? | 특정 파일 담당 reviewer를 자동 지정 |

## notes

### GitHub Flow 4원칙
- `main`은 항상 배포 가능 / branch는 짧게 / PR은 작게 / CI 통과해야 merge.

### PR 템플릿
```markdown
## What changed
## Why
## Verification
## Risk
```

### 좋은 PR vs 나쁜 PR
- 나쁨: 여러 기능 한 번에 / 테스트 없음 / 제목 `fix` / binary+코드 섞임.
- 좋음: 하나의 의도만 / 검증 명령 포함 / 변경 목적 드러나는 제목 / 산출물·코드 분리.

### Evidence Note
```markdown
# W3D3S2 Developer GitHub Flow
- issue: (예) week3 day3 노트 파일 생성
- branch: (예) feat/w3d3-notes
- PR title: docs: add week3 day3 lesson notes
- review point: 변경 의도가 한 가지인지, 검증 기록 포함 여부
- status check: lint/test/build 통과
```

### 메모 — Kanban(칸반)
- 정의: 작업을 카드로 만들어 보드의 열(상태) 사이를 옮기며 진행을 **시각화**하는 작업 관리 방식. 어원 일본어 看板(카드).
- 구조: `To Do → In Progress → Review → Done` 열, 카드 1장 = 보통 issue 1개(작업 단위).
- GitHub Flow와 연결: issue→To Do / branch·코드→In Progress / PR·review→Review / merge→Done.
- GitHub에선 **GitHub Projects** 보드가 칸반 역할 (issue/PR을 카드로 끌어와 상태별 관리).
- 핵심 규칙: ① 시각화(누가 어디까지 했는지 한눈에) ② WIP 제한(In Progress에 카드 과적 금지 — 동시 작업 과다 방지).

### 메모 — lesson-02 이미지
- (강의자료 갱신됨) 이미지가 `lesson-02-github-developer-flow.png`로 교체됨 = **Developer GitHub workflow** 다이어그램.
- 흐름이 본문과 그대로 일치: issue #123 → branch 생성 → 개발 환경 → PR 생성 → 코드 리뷰 → status checks → merge.
- (참고) 갱신 전 이미지는 worker 운영(queue→worker→retry) 그림이었음.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
