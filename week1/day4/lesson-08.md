# 8교시: 카카오페이 - AI 플랫폼, GPU, Kubeflow, Docker 준비도

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| AI 시스템이 웹 서비스와 다른 점은 무엇인가? | 운영 패턴은 비슷하지만 compute가 더 비싸고 특수하다. GPU, memory, storage throughput, model file, scheduling이 중요해진다. GPU는 비싸고 공유 자원이므로 표준화와 quota 관리가 비용 관리와 같다. |
| AI 플랫폼에 표준화가 필요한 이유는 무엇인가? | 팀마다 다른 runtime, library version, GPU 설정을 쓰면 실험 재현이 불가능하고 비용 추적이 어렵다. 표준 환경이 있어야 여러 팀이 같은 조건으로 실험하고 배포할 수 있다. |

## notes

### 고성능 컴퓨팅 지도

| 구성요소 | 웹 앱 버전 | AI/HPC 버전 |
|---|---|---|
| Runtime | Node/Python server | Python/ML runtime |
| Dependency | web framework | ML library, CUDA 관련 stack |
| Data | DB 또는 JSON | dataset, model artifact |
| Compute | CPU, memory | GPU, memory, disk throughput |
| Config | API URL, secret | experiment config, resource quota |
| Observability | logs, status | training logs, metrics, GPU usage |
| Lifecycle | start/stop/restart | schedule, train, evaluate, deploy |

### Day4 종합표

| 교시 | 회사 | 구성요소 | Docker 압력 |
|---|---|---|---|
| 1 | 쿠팡 | 전체 앱 지도 | 많은 의존성에 공통 실행 계약이 필요하다. |
| 2 | 토스 | 프론트엔드 플랫폼 | runtime과 build version이 맞아야 한다. |
| 3 | 당근 | 백엔드 경계 | 각 service에 port, config, health check가 필요하다. |
| 4 | 네이버 | DB/storage | DB version, port, data path를 통제해야 한다. |
| 5 | 카카오 | message streaming | broker와 consumer 실행 순서가 중요하다. |
| 6 | 우아한형제들 | 배달 이벤트 | API, queue, worker, log를 함께 실행해야 한다. |
| 7 | 여기어때 | burst traffic | 반복 가능한 disposable test 환경이 필요하다. |
| 8 | 카카오페이 | AI/HPC | 비싼 compute일수록 표준 runtime이 필요하다. |

### Week2 Docker 준비 체크리스트

```text
1. 내가 가장 잘 이해한 app/component:
2. 이해에 도움이 된 회사 사례:
3. 내가 설명할 수 있는 수동 설치의 고통:
4. 고정해야 할 runtime 또는 version:
5. 고정해야 할 port 또는 network 조건:
6. 보호해야 할 data 또는 file path:
7. hard-code하면 안 되는 config 또는 secret:
8. Docker 주차에 물어보고 싶은 질문:
9. Day6 멘토링 필요 여부: yes/no
```

### AI 엔지니어링 연결

최근 AI 엔지니어링의 핵심:
```text
"모델을 한 번 학습했다"
    ↓ (이것이 아니라)
"데이터, 실험, 배포, 모니터링을 반복 가능하게 만들었다"
```

Docker와 Kubernetes는 AI 엔지니어링에서도:
- 모델을 담는 그릇 (image)
- 실험을 재현하는 단위 (container)
- GPU 자원을 배치하는 기준 (resource quota)

으로 이어진다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
