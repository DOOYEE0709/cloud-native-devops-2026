# 3교시: EC2 웹 서버 실행

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| 이 실습의 성공 증거는? | **instance running이 아니라 HTTP response(200 + body)**. running은 instance 상태일 뿐, app 정상은 별개 |
| User Data가 뭐고 왜 쓰나? | 최초 부팅 때 자동 실행되는 **bootstrap script**. 손작업 대신 **생성과 함께 반복 재현**. instance마다 설정이 달라지는 걸 막음 |
| User Data는 AMI와 무관한가? | ❌ **package manager·service name이 AMI별로 다름**. Amazon Linux=`dnf`+`httpd`, Ubuntu=`apt`+`apache2`. AMI와 명령을 맞추는 게 핵심 |
| `curl -i`를 쓰는 이유? | 브라우저 화면만으론 부족. **status code + response header/body**를 같이 봐야 200/403/404·redirect·cache·ALB 문제를 정확히 구분 |
| SSH는 되는데 HTTP 안 됨, 원인? | network는 뚫림(SSH 됨) → **app/SG 80 계층 문제**. web server service 상태 → SG 80 → listen port 순 |
| user data 실패는 어디서 보나? | instance 안 **`/var/log/cloud-init-output.log`**(+ `/var/log/cloud-init.log`). SG부터 고치는 건 순서 틀림 |
| 수동 설치로 고치면 끝인가? | 임시복구일 뿐 **재현성↓**. evidence엔 "user data 실패→log 확인→수동 임시복구→user data 수정 필요"로 경로를 남김 |

## notes

### 💬 강사님 설명 — user data = 인스턴스 실행 때 "미리 파일/설정을 만들어두는 것"
instance가 **처음 켜질 때 자동으로 돌아가는 script**라서, 접속해서 손으로 만들 파일(예: `/var/www/html/index.html`)과 설치·설정을 **부팅 시점에 미리 다 만들어 둔다**. 그래서 매번 손작업 없이 **같은 상태로 재현**된다. (단순히 파일만 만드는 게 아니라 package 설치·service 시작도 이 안에서 같이 함 → "부팅 때 자동 실행되는 초기 셋업")

### User Data script (Amazon Linux 기준)
```bash
#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl enable --now httpd
cat > /var/www/html/index.html <<'EOF'
<h1>paperclip w5d2 ec2 web</h1>
<p>hello from EC2 user data</p>
EOF
```
> Ubuntu면 `apt` + `apache2`로 바뀐다. **AMI에 명령을 맞추는 것**이 이 교시의 핵심.

### 확인 순서 (위에서부터 하나씩)
```text
EC2 state = running
Status checks = passed
Public IPv4 exists
Security Group allows TCP 80
Browser/curl returns HTTP response   ← 진짜 성공 증거
```
기대 결과: `curl -i` → `HTTP/1.1 200 OK` + index body.

### 실패 증상별 첫 확인
| 증상 | 첫 확인 |
|---|---|
| timeout | public IP, route table, **SG inbound 80** |
| connection refused | web server **process/listen port** |
| 403/404 | document root, index file |
| SSH는 되는데 HTTP 안 됨 | **SG 80, web server service** |
| user data가 안 된 것 같음 | **cloud-init-output.log** |

### 💬 tcpdump로 "트래픽이 들어오는지"를 직접 본다 (강사님 팁)
80 포트로 **패킷이 도착은 하는지**를 눈으로 확인 → "SG/network에서 막힘" vs "app이 응답을 안 함"을 가른다.
```bash
sudo tcpdump -i any port 80        # 모든 인터페이스에서 80 트래픽 관찰
sudo tcpdump -i ens5 port 80       # 특정 인터페이스만 (ip a로 이름 확인)
```
> ⚠️ `-i` 뒤엔 **인터페이스 이름**이 온다(`any`/`ens5`/`eth0`). `tcpdump -i port 80`처럼 쓰면 `port`를 인터페이스로 오해해 에러. 인터페이스 이름은 `ip a`로 확인.

| tcpdump 결과 | 해석 | 다음 확인 |
|---|---|---|
| 패킷이 **아예 안 보임** | 트래픽이 여기까지 못 옴 | **SG inbound 80**, public IP, route table |
| 패킷은 **들어오는데** 응답 없음 | network는 뚫림, **app이 응답 안 함** | httpd service(⑤), 80 listen(⑥) |

### 🧪 실험 — localhost는 되는데 public IP는 안 된다 (SG가 어디서 거르는가)
SG inbound를 **80 → 81로 변경**(80 차단, 81만 허용). 웹서버는 그대로 **80 listen**.
| 어디서 | 명령 | 결과 | 이유 |
|---|---|---|---|
| 인스턴스 **안** | `curl -i http://localhost/` | ✅ 잘 됨 | **loopback**(자기 자신) 통신 → **SG를 안 거침** |
| **밖(내 PC)** | `curl -i http://<publicIP>/` | ❌ 응답 없음(timeout) | 인터넷 타고 **ENI로 들어옴 → SG가 80 차단** |

**ENI(Elastic Network Interface) = EC2의 가상 랜카드**. VPC 안에서 인스턴스가 네트워크에 연결되는 실제 접점으로, private IP·public IP·MAC·**SG가 붙는 자리**다. 인스턴스 OS 안에서 `ip a`로 보이는 **`ens5`가 바로 이 ENI**(같은 것의 양쪽 이름). SG는 ENI에 붙어 있고 **트래픽이 ENI를 통과할 때 검사**하므로, ENI를 안 지나는 loopback(localhost)은 SG 검사를 받지 않는다.

> ⭐ **결론: SG는 "밖에서 인스턴스(ENI)로 들어오는 트래픽"에만 걸린다. localhost(loopback)는 SG를 통과하지 않는다.**
> → 그래서 **"서버 안에서 되는지"와 "밖에서 되는지"는 다른 질문**. 안에서 `curl localhost`로 app이 살아있는지 먼저 확인하고, 밖에서 안 되면 그 사이(SG·public IP·route)를 본다.
> → 이때 앞의 `tcpdump -i any port 80`을 밖에서 요청하며 돌리면 **패킷이 아예 안 들어옴**(SG에서 drop)을 눈으로 확인 가능. (자세한 분석은 4교시)

### 🧪 실험 — 서비스를 죽이면 80 LISTEN이 사라진다 (app process = listen port)
nginx를 stop/start 하며 `netstat`으로 80 포트를 관찰. **app이 살아있어야 포트를 듣는다**를 눈으로 확인.

실제 로그 (그대로):
```text
[ec2-user@ip-172-31-44-240 ~]$ sudo service stop nginx
The service command supports only basic LSB actions (start, stop, restart, try-restart, reload, reload-or-restart, try-reload-or-restart, force-reload, status, condrestart). For other actions, please try to use systemctl.

[ec2-user@ip-172-31-44-240 ~]$ netstat -anp | grep LISTEN
(No info could be read for "-p": geteuid()=1000 but you should be root.)
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      -
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -
tcp6       0      0 :::80                   :::*                    LISTEN      -
tcp6       0      0 :::22                   :::*                    LISTEN      -
（이하 unix 소켓 LISTEN 다수 — /run/systemd/*, /var/lib/amazon/ssm/* 등）

[ec2-user@ip-172-31-44-240 ~]$ sudo service nginx stop
Redirecting to /bin/systemctl stop nginx.service

[ec2-user@ip-172-31-44-240 ~]$ netstat -anp | grep LISTEN
(No info could be read for "-p": geteuid()=1000 but you should be root.)
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -
tcp6       0      0 :::22                   :::*                    LISTEN      -
（80 사라짐. 22만 남음. 이하 unix 소켓 동일）

[ec2-user@ip-172-31-44-240 ~]$ sudo service nginx start
Redirecting to /bin/systemctl start nginx.service

[ec2-user@ip-172-31-44-240 ~]$ netstat -anp | grep LISTEN
(No info could be read for "-p": geteuid()=1000 but you should be root.)
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      -
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      -
tcp6       0      0 :::80                   :::*                    LISTEN      -
tcp6       0      0 :::22                   :::*                    LISTEN      -
（80 복귀）
```

관찰:
| 단계 | 80 포트 | 의미 |
|---|---|---|
| nginx 실행 중 | `0.0.0.0:80 LISTEN` | app이 80을 **듣는 중** |
| `nginx stop` 후 | **80 사라짐**(22만) | app 죽음 → 아무도 80 안 들음 |
| `nginx start` 후 | `0.0.0.0:80 LISTEN` 복귀 | app이 다시 80을 엶 |

> ⭐ **netstat에 80 LISTEN이 없으면 = network(SG) 문제가 아니라 app(서비스) 문제.** 이 상태로 밖에서 `curl`하면 SG가 80을 허용해도 **`connection refused`**(= ENI엔 도달, 듣는 게 없음). 앞의 SG 차단은 **`timeout`**이었음 → **refused ≠ timeout으로 앞단/뒷단을 가른다.**

로그에서 짚은 것 2개:
1. **`sudo service stop nginx`는 순서 틀림** → LSB help만 뜸. 맞는 건 `sudo service nginx stop` 또는 `sudo systemctl stop nginx`(정석).
2. **`(No info could be read for "-p")`** = `-p`(프로세스 이름)는 root 필요 → 그래서 PID가 `-`로 나옴. 프로세스까지 보려면:
```bash
sudo netstat -tlnp | grep :80
sudo ss -tlnp | grep :80
```

### user data vs 수동 설치
| 구분 | user data | 수동 설치 |
|---|---|---|
| 재현성 | 생성과 함께 반복 | 사람이 기억해야 |
| 실패 확인 | cloud-init log | shell history/log |
| 수정 속도 | 재생성 필요할 수 있음 | 빠르게 고침 |
| 수업 목적 | **표준 절차 학습** | 장애 복구 보조 |

### 복구 절차 (순서대로)
1. `curl` timeout → **SG·public IP** 확인
2. SSH는 되는데 HTTP 안 됨 → **web server service 상태**(⑤)
3. service 없음 → **user data 실패인지 cloud-init log**(⑦)
4. **AMI와 package manager가 맞는지** 확인
5. 수동 설치로 임시복구했다면 **user data 수정 필요성 기록**

### HTTP 확인 기준
브라우저에 페이지 보이는 것만으론 부족. **`curl -i`로 status code + header/body**를 함께 남겨야 재현·비교가 됨.

### Evidence Note (배움일기용)
```markdown
# W5D2S3 EC2 web
- EC2 public IP:
- User data 사용 여부:
- Web server package:
- SG inbound 80:
- curl result:
- 실패 시 첫 확인:
```

### 한 줄 요약
EC2 웹 서버 실습의 성공 증거는 **instance running이 아니라 HTTP response(200)**다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| `curl` timeout | network gate → **SG inbound 80**, public IP, route table |
| `curl` connection refused | host는 도달, **80 listen 안 함** → ⑤ httpd status, ⑥ `ss -tlnp` |
| SSH는 되는데 HTTP 안 됨 | SSH=network OK → **app/SG 80 계층**. service·SG 80 확인 |
| index page 대신 기본 페이지/403 | document root `/var/www/html/index.html`, 권한 확인 |
| user data가 실행 안 된 듯 | ⑦ `cloud-init-output.log`에서 실패 로그 → AMI별 명령(`dnf`/`apt`) 불일치 확인 |
