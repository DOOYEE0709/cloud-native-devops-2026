# 4교시: Security Group 장애 분석

```bash
# 이 교시 실습 변수
export REGION=ap-northeast-2
export SG=sg-xxxxxxxxxxxx          # EC2에 붙은 Security Group ID
export PUBIP=x.x.x.x               # instance public IPv4
export MYIP=$(curl -s https://checkip.amazonaws.com)   # 내 공인 IP (source 지정용)
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① (정상 확인) `curl -m 5 -i http://$PUBIP/` | |
| ② (장애주입1: 80 제거) Console SG inbound에서 TCP 80 삭제 **또는** `aws ec2 revoke-security-group-ingress --region $REGION --group-id $SG --protocol tcp --port 80 --cidr 0.0.0.0/0` | |
| ③ (증상) `curl -m 5 -i http://$PUBIP/` → **timeout 확인** | |
| ④ (복구) `aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG --protocol tcp --port 80 --cidr 0.0.0.0/0` | |
| ⑤ (recheck: 같은 명령) `curl -m 5 -i http://$PUBIP/` → 200 복귀 | |
| ⑥ (장애주입2: source 틀림) 80 source를 내 IP 아닌 CIDR로 → `aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG --protocol tcp --port 80 --cidr 203.0.113.0/24` | |
| ⑦ (증상) 밖에서 `curl -m 5 -i http://$PUBIP/` → **timeout**(instance·web은 정상인데) | |
| ⑧ (rule 확인) `aws ec2 describe-security-groups --region $REGION --group-ids $SG --query "SecurityGroups[].IpPermissions" --output json` | |
| ⑨ (정리) 잘못 넣은 rule 제거 → `aws ec2 revoke-security-group-ingress --region $REGION --group-id $SG --protocol tcp --port 80 --cidr 203.0.113.0/24` | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 왜 일부러 고장내나? | 정상 화면만 봐선 안 큼. 80 닫고·source 틀리고·port 바꿔봐야 **증상 차이**를 몸으로 익혀서, 실제 장애에서 **app code vs cloud network**를 분리할 수 있음 |
| SG 80 닫으면 증상은? | 밖에서 **timeout**(트래픽이 ENI에서 drop). instance·web server는 멀쩡할 수 있음 → app log부터 보면 오진 |
| wrong source vs SG 닫힘, 증상 차이? | **둘 다 timeout**. rule이 아예 없냐 vs 있는데 source가 내 IP와 다르냐의 차이. ⑧ describe로 **source CIDR을 내 IP와 비교** |
| timeout vs connection refused? | **timeout**=앞단 차단(SG/route/public IP, ENI 도달 못함), **refused**=ENI 도달했는데 **그 port 듣는 게 없음**(app/service down, lesson-03 netstat) |
| SG는 어느 방향을 보나? | **inbound**가 외부→resource gate. 흔한 실수가 outbound만 보고 inbound 안 보는 것. **port + source + direction**을 한 세트로 |
| SSH 22를 0.0.0.0/0으로? | 임시 예외만. 오래 열지 말 것. 열었으면 **사유·종료 시각** evidence에 남기고 종료 전 삭제 |
| 복구했는데 왜 같은 명령으로 재확인? | 브라우저 새로고침은 **DNS/cache/redirect**로 판단 흐려짐. `curl -m 5 -i` **고정**해야 전후 비교가 정확 |
| SG 변경 반영 시점은? | **즉시**. 공유 instance면 한 명 변경이 남에게 영향 → 개인 SG 쓰는 이유(영향 범위 축소) |

## notes

### 장애 주입 → 복구 → recheck (한 세트)
```text
① 정상 curl 확인  →  ② rule 고장(80 제거/source 틀림)  →  ③ 같은 curl로 증상 기록
   →  ④ rule 복구  →  ⑤ 같은 curl로 recheck(전후 비교)
```
고정 명령: `curl -m 5 -i http://$PUBIP/` (`-m 5`=5초 timeout, 무한 대기 방지)

### 원인 → 증거 매핑 (오진 방지 핵심표)
| 원인 | 증상 | 증거/확인 |
|---|---|---|
| app process down | 밖에서 **refused** | EC2 접속 후 service down, `netstat`에 80 없음 |
| SG 80 closed | 밖에서 **timeout** | inbound rule에 80 없음 |
| wrong source | 밖에서 **timeout** | rule은 있으나 **source ≠ 내 IP**(⑧ describe로 비교) |
| wrong port | SG 열어도 응답 없음 | app은 8080인데 SG는 80 (또는 반대) |

> ⭐ **timeout이면 app log보다 SG/route/public IP를 먼저 본다.** refused면 app/service를 본다. (lesson-03 tcpdump·localhost·netstat 3종 세트와 연결)

### source CIDR / port 위험 판단
| Rule | 수업 판단 | 종료 후 |
|---|---|---|
| TCP 22 from **my IP** | 권장 | 필요 없으면 삭제 |
| TCP 22 from `0.0.0.0/0` | ❌ **하지 마라**(아래) | 반드시 삭제 |
| TCP 80 from `0.0.0.0/0` | public web 확인 목적 가능 | EC2/ALB 또는 rule 삭제 |
| DB port from `0.0.0.0/0` | **금지에 가깝게** | 없어야 함 |

`0.0.0.0/0`=모든 IPv4.

> 🚫 **SSH 22 `0.0.0.0/0` 전체공개 = 원칙적으로 하지 마라 (강사님).** 진짜 급할 때나 리소스 종료 직전에만 잠깐, 그것도 사유·종료 시각 기록. 어차피 SSH는 **key(.pem) 관리 부담**이 따라온다. → 접속이 필요하면 **SSM Session Manager(inbound 0개, 아래)를 쓰는 게 낫다.** 22를 여는 것 자체가 마지막 선택지.

### 🔒 22를 아예 안 열고 접속하기 — SSM Session Manager (정공법 대안)
SSH는 밖→인스턴스 **inbound 22**를 열어야 하지만, Session Manager는 **inbound 0개**로 접속된다. 핵심은 **방향**:
```text
[SSH]           내 PC → (inbound 22) → EC2            ← SG에 22 열어야
[Session Mgr]   내 PC → AWS SSM ← (outbound 443) EC2   ← inbound 0개, agent가 밖으로 연결
```
- 인스턴스의 **SSM Agent**가 **outbound 443**으로 AWS SSM에 붙어 있고, 내 접속은 AWS SSM을 거쳐 그 agent로 연결됨.
- ⚠️ 여기 443은 **outbound**(인스턴스가 밖으로). "443 inbound를 여는" 게 아님. outbound는 SG 기본 전체허용이라 보통 안 건드림.

| 되려면 필요 | 내용 |
|---|---|
| SSM Agent | 최신 Amazon Linux엔 기본 설치·실행 |
| IAM role | 인스턴스에 `AmazonSSMManagedInstanceCore` 붙은 role |
| 네트워크 경로 | agent가 SSM endpoint에 닿음 → 인터넷(outbound 443) 또는 VPC endpoint |

> ⭐ **inbound 22를 안 여니 SSH 공격 표면·key(.pem) 관리가 사라지고, 접속은 IAM 인증 + 세션 로그(audit)로 남는다.** → 현업은 "bastion+SSH 22" 대신 이 방식을 선호. (lesson-02 접속 3방식의 Session Manager가 이것)

### SG 변경 주의
- rule 변경은 **즉시 반영**
- 공유 instance면 한 명 변경이 **남 실습에 영향** → 개인 계정/개인 SG로 영향 범위 축소
- **inbound/outbound 방향** 헷갈리지 말 것 (외부 접속 문제는 대개 inbound)

### Evidence Note (배움일기용)
```markdown
# W5D2S4 SG failure drill
- 실패 주입:
- 실패 증상:
- SG rule before:
- SG rule after:
- 같은 명령으로 recheck:
- 보안상 위험했던 rule:
```

### 한 줄 요약
SG 장애 분석은 **port · source · direction · recheck**를 한 세트로 본다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| 80 제거 후 curl **timeout** | 정상. 트래픽이 ENI에서 drop → inbound 80 rule 없음 |
| rule 넣었는데도 **timeout** | **source CIDR이 내 IP와 다름**(⑧ describe로 비교). `$MYIP` 재확인(공인 IP 바뀌었을 수 있음) |
| SG 열었는데 **refused** | SG 문제 아님 → **app/service down**. `netstat`에 그 port LISTEN 있는지(lesson-03) |
| 복구했는데 브라우저는 여전히 실패 | cache/DNS. `curl -m 5 -i`로 재확인해야 정확 |
| revoke/authorize가 `InvalidPermission.Duplicate`/`NotFound` | 이미 있거나 없는 rule. ⑧ describe로 현재 rule 먼저 확인 |
