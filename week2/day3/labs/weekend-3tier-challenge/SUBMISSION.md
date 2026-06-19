# Weekend Challenge Submission

## Architecture
| Tier | Container | Network | Evidence |
|---|---|---|---|
| Frontend |  |  |  |
| Backend |  |  |  |
| Database |  |  |  |

## Network Evidence
| Check | Command | Result | Pass/Fail |
|---|---|---|---|
| frontend -> backend |  |  |  |
| backend -> db |  |  |  |
| frontend -> db blocked |  |  |  |

## Volume Evidence
| Evidence | Command | Result |
|---|---|---|
| volume exists |  |  |
| stale volume signal |  |  |
| data reset decision | keep / remove |  |

## Logs
| Service | Command | Key line |
|---|---|---|
| frontend |  |  |
| backend |  |  |
| database |  |  |

## Troubleshooting RCA
| Field | Note |
|---|---|
| Symptom |  |
| First evidence command |  |
| Cause |  |
| Fix |  |
| Recheck |  |
| Prevention |  |

## Image Optimization Measurement
| Target | Base image | First build seconds | Size bytes | Size human | Selected |
|---|---|---:|---:|---|---|
| frontend | `nginx:stable` |  |  |  |  |
| frontend | `nginx:stable-alpine` |  |  |  |  |
| frontend | `nginx:stable-trixie` |  |  |  |  |
| backend | `node:22` |  |  |  |  |
| backend | `node:22-slim` |  |  |  |  |
| backend | `node:22-alpine` |  |  |  |  |

## Image Tags Or Registry URLs
| Image | Tag or URL |
|---|---|
| frontend |  |
| backend |  |

## Final Decision
```text
내가 선택한 frontend base image:
이유:

내가 선택한 backend base image:
이유:

push 여부:
push하지 않았다면 이유:
```
