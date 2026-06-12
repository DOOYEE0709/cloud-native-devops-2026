// ── 한국 개발자 실무형 프롬프트 더미 데이터 (10개) ──
const posts = [
  {
    author: "@jiwon_dev",
    tags: ["#JavaScript", "#Refactor"],
    prompt: "너는 10년차 시니어 프론트엔드 엔지니어야. 아래 자바스크립트 코드를 Clean Code 원칙(단일 책임, 의미 있는 네이밍, 중복 제거)에 맞춰 리팩토링해줘. 리팩토링 후에는 (1) 변경 이유, (2) 개선된 점, (3) 추가로 고려할 사항을 bullet point로 각각 정리해줘. 코드에는 간결한 JSDoc 주석도 달아줘.",
    hearts: 84,
    comments: [
      { user: "@minsu_kr", text: "실무에서 진짜 자주 쓰는 프롬프트ㅋㅋ 저장함" },
      { user: "@hazel.io", text: "before/after 비교까지 시키면 더 좋아요!" },
    ],
  },
  {
    author: "@backend_kim",
    tags: ["#FastAPI", "#JWT"],
    prompt: "너는 백엔드 보안 전문가야. FastAPI에서 JWT 기반 인증 미들웨어를 구현하는 보일러플레이트 코드를 작성해줘. 다음 조건을 반드시 포함해: (1) access token / refresh token 분리, (2) 토큰 만료 시 401 응답, (3) 잘못된 서명 시 403 응답, (4) HTTPException을 활용한 커스텀 에러 메시지, (5) 의존성 주입(Depends)으로 라우터에 적용하는 예시.",
    hearts: 62,
    comments: [
      { user: "@api_queen", text: "refresh token 로직도 같이 물어보면 굿" },
    ],
  },
  {
    author: "@db_master",
    tags: ["#MySQL", "#SQL"],
    prompt: "너는 MySQL DBA 전문가야. 실무에서 슬로우 쿼리를 분석할 때 사용하는 EXPLAIN 결과 분석 가이드라인을 표 형태로 만들어줘. 각 컬럼(id, select_type, type, key, rows, Extra)의 의미와 위험 신호(예: type=ALL, Using filesort, Using temporary)를 정리하고, 개선 방향 체크리스트도 포함해줘. 마지막에 실제 최적화 전후 쿼리 예시도 넣어줘.",
    hearts: 51,
    comments: [
      { user: "@slow_query_kim", text: "type: ALL 나올 때마다 식은땀 나는데 이거 저장!" },
      { user: "@dba_lee", text: "Using filesort 케이스도 추가해달라고 하세요~" },
    ],
  },
  {
    author: "@devops_park",
    tags: ["#Docker", "#DevOps"],
    prompt: "너는 컨테이너 최적화 전문 DevOps 엔지니어야. Python FastAPI 앱을 위한 멀티스테이지 Dockerfile을 작성해줘. 조건: (1) builder 스테이지에서 의존성 설치 후 runtime 스테이지로 복사, (2) 비루트 유저(non-root user)로 실행, (3) .dockerignore 예시 포함, (4) 최종 이미지는 python:3.11-slim 기반, (5) 각 레이어 캐싱 전략 주석으로 설명. 최종 이미지 용량이 왜 작아지는지도 설명해줘.",
    hearts: 97,
    comments: [
      { user: "@k8s_choi", text: "multi-stage 안 쓰면 이미지가 너무 커져서..ㅠ" },
    ],
  },
  {
    author: "@spring_jung",
    tags: ["#Spring", "#Java"],
    prompt: "너는 Spring Boot 전문가야. Spring Boot 3.x에서 전역 예외 처리기(Global Exception Handler)를 작성해줘. 조건: (1) @RestControllerAdvice 사용, (2) ErrorResponse DTO 설계(timestamp, status, code, message, path 필드 포함), (3) BusinessException 커스텀 예외 클래스와 ErrorCode enum 설계, (4) @Valid 유효성 검사 실패 처리, (5) 예상치 못한 서버 오류 처리. 각 클래스 역할을 한 줄 주석으로 설명해줘.",
    hearts: 73,
    comments: [
      { user: "@java_lover", text: "ErrorResponse DTO 구조도 같이 뽑아주더라" },
      { user: "@spring_newbie", text: "완전 구세주 프롬프트 감사합니다" },
    ],
  },
  {
    author: "@react_ahn",
    tags: ["#React", "#TypeScript"],
    prompt: "너는 React + TypeScript 전문가야. 재사용 가능한 커스텀 훅 useFetch를 만들어줘. 조건: (1) 제네릭 타입으로 응답 데이터 타입 지정 가능, (2) loading / error / data 상태 관리, (3) 컴포넌트 언마운트 시 AbortController로 요청 취소, (4) 의존성 배열 기반 자동 재요청, (5) 실제 사용 예시 컴포넌트 코드 포함. 타입 안정성을 최대한 보장하도록 작성해줘.",
    hearts: 115,
    comments: [
      { user: "@ts_love", text: "제네릭 타입으로 만들어달라고 하면 더 재사용하기 좋아요" },
    ],
  },
  {
    author: "@infra_yoon",
    tags: ["#Terraform", "#AWS"],
    prompt: "너는 AWS 인프라 전문 Terraform 엔지니어야. AWS ECS Fargate + ALB 인프라를 Terraform으로 작성해줘. 조건: (1) VPC, 서브넷, 보안그룹 모듈 분리, (2) ECS 클러스터 / 태스크 정의 / 서비스 리소스 포함, (3) ALB + 타겟 그룹 + 리스너 설정, (4) variables.tf / outputs.tf 분리, (5) 각 리소스에 실무 수준 주석. 태스크 정의에서 환경변수 주입 방법도 보여줘.",
    hearts: 44,
    comments: [
      { user: "@cloud_han", text: "security group 규칙도 같이 물어보면 완성도 up" },
      { user: "@devops_park", text: "나도 이거 쓰고 있음 ㄹㅇ 시간 절약됨" },
    ],
  },
  {
    author: "@algo_shin",
    tags: ["#Python", "#CodeReview"],
    prompt: "너는 Python 코드 리뷰 전문가야. 아래 파이썬 함수를 (1) 가독성, (2) 성능, (3) 예외 처리, (4) 타입 힌트, (5) 테스트 가능성 다섯 가지 관점에서 각각 bullet point로 피드백해줘. 각 항목마다 심각도(🔴 critical / 🟡 warning / 🟢 suggestion)를 표시하고, 최종적으로 개선된 전체 코드를 제시해줘.",
    hearts: 38,
    comments: [
      { user: "@clean_code", text: "코드 리뷰 받기 민망할 때 AI한테 먼저 돌려보기ㅋㅋ" },
    ],
  },
  {
    author: "@sql_choi",
    tags: ["#PostgreSQL", "#성능"],
    prompt: "너는 PostgreSQL 성능 최적화 전문가야. SQLAlchemy ORM에서 N+1 쿼리 문제가 발생하는 코드 예시를 보여주고, (1) joinedload를 사용한 즉시 로딩, (2) 서브쿼리(subqueryload), (3) 순수 SQL JOIN 세 가지 방법으로 각각 개선하는 코드를 작성해줘. 각 방법의 EXPLAIN ANALYZE 예상 결과 차이와 언제 어떤 방법을 쓰는 게 좋은지 실무 기준으로 정리해줘.",
    hearts: 59,
    comments: [
      { user: "@orm_hater", text: "ORM 믿다가 DB 날린 경험 있어서 공감 100%" },
      { user: "@db_master", text: "EXPLAIN ANALYZE 결과도 같이 보여달라고 하면 좋아요" },
    ],
  },
  {
    author: "@git_lee",
    tags: ["#Git", "#협업"],
    prompt: "너는 개발 문화 전도사야. 5인 스타트업 팀을 위한 Git 협업 가이드를 팀 위키용 마크다운 문서로 작성해줘. 포함할 내용: (1) Conventional Commits 기반 커밋 메시지 컨벤션 표, (2) Git Flow vs Trunk Based Development 장단점 비교 표, (3) 이 팀에 맞는 브랜치 전략 추천 및 이유, (4) PR 템플릿(변경 이유, 테스트 방법, 스크린샷, 체크리스트), (5) 코드 리뷰 에티켓 5가지. 실제로 팀에서 바로 쓸 수 있도록 구체적으로 작성해줘.",
    hearts: 91,
    comments: [
      { user: "@pm_na", text: "이거 팀장한테 바로 드렸더니 칭찬받음ㄷㄷ" },
    ],
  },
];

const feed = document.getElementById("feed");

// 카드 렌더링
posts.forEach((post) => {
  const card = document.createElement("div");
  card.className = "card";

  // 작성자 + 태그
  const meta = document.createElement("div");
  meta.className = "card-meta";
  meta.innerHTML =
    `<span class="author">${post.author}</span>` +
    post.tags.map(t => `<span class="tag">${t}</span>`).join("");

  // 프롬프트 본문
  const body = document.createElement("p");
  body.className = "prompt-body";
  body.textContent = post.prompt;

  // 액션 버튼
  const actions = document.createElement("div");
  actions.className = "card-actions";

  // 복사 버튼
  const copyBtn = document.createElement("button");
  copyBtn.className = "btn-copy";
  copyBtn.textContent = "프롬프트 복사";
  copyBtn.addEventListener("click", () => {
    navigator.clipboard.writeText(post.prompt).then(() => {
      copyBtn.textContent = "복사됨 ✓";
      copyBtn.classList.add("copied");
      setTimeout(() => {
        copyBtn.textContent = "프롬프트 복사";
        copyBtn.classList.remove("copied");
      }, 1500);
    });
  });

  // 좋아요 버튼
  let heartCount = post.hearts;
  const heartBtn = document.createElement("button");
  heartBtn.className = "btn-heart";
  heartBtn.innerHTML = `❤️ <span class="heart-count">${heartCount}</span>`;
  heartBtn.addEventListener("click", () => {
    heartCount++;
    heartBtn.querySelector(".heart-count").textContent = heartCount;
  });

  actions.appendChild(copyBtn);
  actions.appendChild(heartBtn);

  // 댓글 영역
  const comments = document.createElement("div");
  comments.className = "comments";

  // 더미 댓글 렌더링
  post.comments.forEach(c => {
    const item = document.createElement("div");
    item.className = "comment-item";
    item.innerHTML = `<strong>${c.user}</strong>${c.text}`;
    comments.appendChild(item);
  });

  // 댓글 입력창
  const form = document.createElement("div");
  form.className = "comment-form";

  // textarea로 변경 — 내용이 많아지면 높이 자동 확장
  const input = document.createElement("textarea");
  input.className = "comment-input";
  input.placeholder = "댓글 남기기...";
  input.rows = 1;
  input.addEventListener("input", () => {
    input.style.height = "auto";
    input.style.height = input.scrollHeight + "px";
  });

  const submitBtn = document.createElement("button");
  submitBtn.className = "btn-comment";
  submitBtn.textContent = "등록";
  // 댓글 추가 함수 — 버튼 클릭과 엔터 둘 다 이 함수만 호출
  const submitComment = () => {
    const text = input.value.trim();
    if (!text) return;
    const item = document.createElement("div");
    item.className = "comment-item";
    item.innerHTML = `<strong>@me</strong>${text}`;
    comments.insertBefore(item, form);
    input.value = "";
    input.style.height = "auto"; // 등록 후 높이 초기화
  };

  submitBtn.addEventListener("click", submitComment);

  input.addEventListener("keydown", (e) => {
    // isComposing: 한글 IME 조합 중일 때는 무시
    if (e.key === "Enter" && !e.isComposing) {
      e.preventDefault();
      submitComment();
    }
  });

  form.appendChild(input);
  form.appendChild(submitBtn);
  comments.appendChild(form);

  card.appendChild(meta);
  card.appendChild(body);
  card.appendChild(actions);
  card.appendChild(comments);
  feed.appendChild(card);
});
