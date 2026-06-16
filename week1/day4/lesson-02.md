# 2교시: 토스 - 프론트엔드 플랫폼과 개발 생산성

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| frontend 실행 조건 4개 이상을 쓸 수 있는가? | Node.js version, package manager(npm/yarn/pnpm), build command(`npm run build`), dev server command(`npm run dev`), port, API endpoint, environment variable이 실행 조건이다. |
| build tooling이 팀 생산성 문제가 되는 이유를 설명할 수 있는가? | 팀원마다 Node.js 버전이 다르거나 package manager가 다르면 build 결과가 달라지거나 실패한다. 공통 실행 조건이 없으면 "내 컴퓨터에서는 됩니다"가 반복된다. |
| frontend 장애 1개를 빠진 실행 조건 1개와 연결할 수 있는가? | blank page → router 설정 또는 build output 경로 오류. API 연결 실패 → environment variable의 API_URL 설정 오류. |
| 프론트엔드 플랫폼에서 AI 시대에 달라지는 점은 무엇인가? | AI coding assistant, 자동 테스트 생성, 디자인-to-code 등이 추가되지만 build, test, preview, 공식 문서 확인, 보안 검토는 여전히 사람이 검증해야 한다. |

## notes

### 프론트엔드 구성요소

| 구성요소 | 역할 | 실패 증상 |
|---|---|---|
| UI component | 화면 요소 재사용 | 깨진 레이아웃, UX 불일치 |
| Router | 어떤 페이지를 열지 결정 | 잘못된 화면, blank page |
| State | 현재 화면 데이터 보관 | stale data, missing data |
| Build tool | source를 실행 가능한 asset으로 변환 | build failure |
| Package manager | 라이브러리 설치 | version conflict |
| Environment config | API endpoint와 flag 선택 | 잘못된 backend 연결 |

### 로컬 실행 조건 템플릿

```text
Runtime: (예: Node.js 20.x)
Package manager: (예: npm / yarn / pnpm)
Install command: (예: npm install)
Run command: (예: npm run dev)
Port: (예: 3000)
API endpoint: (예: http://localhost:8080)
Build output: (예: dist/ 또는 .next/)
Known risk: (예: Node.js 버전 불일치)
```

### 핵심 관점

현대 프론트엔드는 HTML/CSS만이 아니다. routing, state, design system, build tool, package manager, test, preview, release pipeline이 함께 움직인다.

프론트엔드 질문: "화면을 만들 수 있는가"가 아니라 "모든 개발자가 같은 조건으로 같은 화면을 실행할 수 있는가"

### Docker 연결

```text
runtime과 package 상태가 다르면 onboarding이 실패한다.
→ Docker는 Node.js 버전, 패키지, build 명령, 환경변수를 image로 묶어
  누구나 같은 조건으로 실행할 수 있게 한다.
```

### 중요

```text
"프론트엔드가 하나일 때는 설치가 대충 되어도 넘어갈 수 있습니다.
하지만 서비스와 팀이 늘어나면 화면 개발도 운영 문제가 됩니다.
핵심 질문은 '화면을 만들 수 있는가'가 아니라
'모든 개발자가 같은 조건으로 같은 화면을 실행할 수 있는가'입니다."
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
