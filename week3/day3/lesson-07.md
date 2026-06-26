# 7교시: GitHub Actions 2 - Secrets, Docker Hub Push, 유사 도구

## 실습 확인 기록

> 실제 push는 본인 GitHub repo + Docker Hub 계정/secret 필요 (UI 작업). 아래는 절차·확인 기준.

| 명령/확인 | 결과/기준 |
|---|---|
| Secret 등록 | repo Settings → Secrets → `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`(access token) |
| 실행 ① tag push | `git tag v0.1.0 && git push origin v0.1.0` → `on.push.tags`로 workflow 트리거 |
| 실행 ② manual | Actions → `w3d3-dockerhub-publish` → Run workflow |
| Docker Hub 확인 | Repositories → `<user>/w3d3-dockerhub-app` → Tags에 `0.1.0`, `latest`, push 시각 일치 |
| 로컬 pull/run (public) | `docker pull <user>/w3d3-dockerhub-app:0.1.0` → run → `curl /health` = `status: ok` |
| 로컬 pull/run (private) | `docker login`(token 입력) 먼저 → pull → run → curl → `docker logout` |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| password 대신 무엇을 secret으로? | Docker Hub **access token** (`DOCKERHUB_TOKEN`) |
| GitHub Secrets의 가장 큰 단점? | 저장 후 UI에서 **값 재확인 불가** + rotation 필요 + 만능 보안 아님 |
| build됨 = pull 가능? | 아니오. CI가 build한 것과 registry에 push되어 pull/run 가능한 건 별개 → registry image 실행으로 최종 검증 |
| private repo image pull 조건? | 인증 필요 — pull 환경에서도 `docker login` 안 하면 `pull access denied` |
| 도구보다 중요한 것? | pipeline 단계: source→test→scan→build→push→deploy→verify |

## notes

### Docker Hub push 흐름
```text
개발자 push → GitHub → Actions(workflow) → Docker Hub(image 저장) → 서버/PC pull·run
```

### GitHub Secrets 장단점
- 장점: repo에 token 미저장 / `${{ secrets.NAME }}` 참조 / log masking / environment별 분리.
- 단점: 저장 후 값 재확인 불가 / 권한 관리 필요 / rotation 필요 / 악성 workflow면 secret 사용 위험(만능 아님).

### 핵심 workflow 구간
```yaml
- name: Login to Docker Hub
  uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
- name: Build and push image
  uses: docker/build-push-action@v6
  with:
    context: week3/day3/labs/dockerhub-app
    push: true
```

### 수동 배포의 문제 (Actions가 해결)
- 누락(test/scan 빼먹음) / 불일치(사람마다 tag 기준) / 증거 부족 / secret 노출(shell history) / 재현 어려움. → Actions가 절차를 YAML로 고정 + 실행 로그 남김.

### 유사 도구 비교
- GitHub Actions(GitHub 중심) / Jenkins(자체 운영·플러그인) / TeamCity(상용 엔터프라이즈) / AWS CodePipeline(AWS 통합).
- 도구보다 pipeline 단계가 중요: `source → test → security scan → build → push → deploy → verify`.
- 강사님 메모: 실무에서 **TeamCity 쓰는 곳은 5%도 안 됨** (점유율 낮음). 현장은 대체로 GitHub Actions / Jenkins 중심.

### 메모 — 멀티 아키텍처(arm64 pull 실패 대응)
- 원인: workflow가 `ubuntu-latest`(amd64) runner에서 build → image가 **amd64만** 포함. Apple Silicon Mac은 arm64라 manifest 매칭 실패.
- 즉시 해결: `docker pull --platform linux/amd64 <image>` (Docker Desktop이 emulation으로 실행 가능).
- 근본 해결: workflow의 `build-push-action`에 멀티 아키텍처 빌드 추가
  ```yaml
  with:
    platforms: linux/amd64,linux/arm64   # 둘 다 빌드해 manifest list로 push
  ```
  (단 빌드 시간↑, QEMU emulation 필요할 수 있음)

### 실패 사례
- `login failed`(secret 오류) / `denied requested access`(repo 권한) / `pull access denied`(private인데 login 안 함) / `build context not found`(path 오류) / tag 안 보임(push/tag 조건 불일치).

### 핵심 포인트
- **build됨 ≠ pull/run 가능.** 최종 검증은 항상 registry에서 받은 image를 실행하는 것.

### Evidence Note
```markdown
# W3D3S7 Docker Hub Push
- workflow run: (성공/실패)
- image name: w3d3-dockerhub-app
- tag: 0.1.0, latest
- Docker Hub tag visible: Tags 탭 확인
- repository visibility: public / private
- private pull auth: docker login 필요 여부
- docker pull: 성공 여부
- local run result: curl status ok
- failure evidence: (있으면 원인)
```

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `docker pull niceguy6112/w3d3-dockerhub-app` → `no matching manifest for linux/arm64/v8 ... not found` | image가 amd64만 있음(`ubuntu-latest` runner build), Mac은 arm64. `docker manifest inspect`로 amd64만 확인. 해결: `docker pull --platform linux/amd64 ...`로 pull 성공 (근본 해결은 workflow에 `platforms: linux/amd64,linux/arm64` 멀티 빌드) |
