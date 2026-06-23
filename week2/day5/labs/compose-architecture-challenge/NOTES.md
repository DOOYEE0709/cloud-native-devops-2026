# Compose Architecture Challenge Notes

## Basic Info
| 항목 | 작성 |
|---|---|
| 이름/팀 |  |
| 선택한 keyword set | A / B / C / D |
| 한 줄 설명 |  |

## Architecture Summary
| Service | 역할 | Image/build | 공개 여부 | Network | Stateful 여부 |
|---|---|---|---|---|---|
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |

## Traffic Path
| 구간 | 연결 | 확인 증거 |
|---|---|---|
| 외부 진입 |  |  |
| 내부 API |  |  |
| cache/queue |  |  |
| data |  |  |

## Network Design
| Network | 포함 service | 이유 |
|---|---|---|
| `public_net` |  |  |
| `app_net` |  |  |
| `cache_net` 또는 `queue_net` |  |  |
| `data_net` |  |  |

## Runtime Config
| Service | Env/config | service name 사용 여부 |
|---|---|---|
|  |  |  |
|  |  |  |

## Evidence
| 확인 항목 | 명령 | 핵심 결과 |
|---|---|---|
| Compose config | `docker compose config` |  |
| Running state | `docker compose ps` |  |
| HTTP |  |  |
| Logs |  |  |
| DB |  |  |
| Redis/Queue |  |  |

## Load/Pressure Notes
| 관점 | service | 이유 | 먼저 볼 증거 |
|---|---|---|---|
| traffic 집중 |  |  |  |
| CPU 부하 후보 |  |  |  |
| memory/state 부하 후보 |  |  |  |
| scale out 후보 |  |  |  |

## Failure Drill
| 실패 주입 | 관찰 증상 | 첫 확인 명령 | 복구 | 배운 점 |
|---|---|---|---|---|
|  |  |  |  |  |

## Cleanup
| 명령 | 선택 이유 | data 삭제 여부 |
|---|---|---|
| `docker compose down` 또는 `docker compose down -v` |  |  |

## Week 3 Bridge
| 질문 | 내 답 |
|---|---|
| Kubernetes로 옮기면 어떤 service가 Deployment가 될까 |  |
| Stateful하게 다뤄야 할 것은 무엇인가 |  |
| readiness/health check가 필요한 service는 무엇인가 |  |
| 가장 먼저 scale out할 service는 무엇인가 |  |
