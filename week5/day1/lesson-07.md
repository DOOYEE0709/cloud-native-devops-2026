# 7교시: S3 첫 관찰

```bash
# 이 교시 실습 변수 (본인 값으로 교체)
export REGION=ap-northeast-2                 # bucket을 볼 Region
export BUCKET=paperclip-w5d1-hyeonta-obs     # bucket name은 전역 unique
```

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| ① `aws s3 ls` | |
| ② `aws s3api list-buckets --query "Buckets[].Name" --output table` | |
| ③ `aws s3api get-bucket-location --bucket $BUCKET` | |
| ④ `aws s3api get-public-access-block --bucket $BUCKET` | |
| ⑤ `aws s3api get-bucket-policy-status --bucket $BUCKET` | |
| ⑥ `aws s3api list-objects-v2 --bucket $BUCKET --query "Contents[].{Key:Key,Size:Size,Class:StorageClass}" --output table` | |
| ⑦ `aws s3api list-object-versions --bucket $BUCKET --query "{Versions:length(Versions),DeleteMarkers:length(DeleteMarkers)}"` | |
| ⑧ `aws s3api get-bucket-website --bucket $BUCKET` | |
| ⑨ (중복확인) `aws s3api create-bucket --bucket $BUCKET --region $REGION --create-bucket-configuration LocationConstraint=$REGION` | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| S3는 file server인가? | ❌ **object storage**. 폴더처럼 보이는 UI가 있어도 실제 단위는 bucket 안 **object(key+data+metadata)**. Pod에 mount하는 disk처럼 보면 안 되고 app이 **S3 API**로 읽고 씀 |
| bucket name의 범위는? | **전역(global) unique**. 이미 쓰는 이름이면 create 실패 → 이걸 Region 문제로 착각하면 안 됨 |
| Region은 무엇에 붙나? | **bucket**에 붙음(object 하나하나가 아니라). data가 그 Region에 저장됨 |
| Block Public Access(BPA)란? | account·bucket·access point 수준의 **상위 안전장치**. bucket policy/ACL로 public을 허용해도 BPA가 켜져 있으면 **차단이 이김**. 새 bucket 기본값=차단 |
| 정적 사이트가 403이면 어디부터? | app 문제 아님. **BPA → bucket policy → object ownership/ACL → website hosting 설정** 순으로 permission 계층을 봄 |
| URL이 있으면 공개된 건가? | ❌ endpoint 존재 ≠ public. object permission과 BPA를 봐야 실제 접근 가능 여부를 앎 |
| bucket 삭제가 안 되면? | 안에 **object가 남았거나**, versioning bucket이면 **versioned object·delete marker**가 남아 있음. 다 비워야 삭제됨 |
| 비용은 어디서 커지나? | 저장량·요청 수·storage class·**versioning 누적**. 작은 실습 object라도 versioning 켜고 계속 올리면 쌓임 |

## notes

### S3 = object storage (file server 아님)
```text
Amazon S3
 └ Bucket (전역 unique name + Region)
     ├ Object: index.html   (key + data + metadata)
     ├ Object: image.png
     ├ Block Public Access  (상위 안전장치)
     └ Lifecycle / Storage class
```
directory permission 바꾸는 감각으로 접근하면 bucket policy·object ownership·BPA·lifecycle을 놓친다. web hosting 실습 403은 **app server 문제가 아니라 S3 permission 계층 문제**일 확률이 높다.

### 오늘 반드시 가져갈 것
| 개념 | 왜 필수 | 놓치면 | 확인 지점 |
|---|---|---|---|
| Bucket/Object | directory가 아니라 bucket 안 object | permission·path를 file system처럼 오해 | bucket, object key |
| Public Access Block | policy/ACL보다 **위**에서 public 제한 | 의도치 않은 공개/공개 실패를 설명 못함 | bucket/account BPA |
| Bucket name | **전역 unique** | 같은 이름 실패를 Region 탓으로 착각 | create error |
| Lifecycle/cost | 저장량·요청·class·versioning으로 비용 변동 | 실습 object가 쌓임 | storage class, lifecycle |

### Public access 판단 계층 (위→아래로 확인)
| 계층 | 확인 |
|---|---|
| Account-level BPA | 계정 전체 차단 여부 |
| Bucket-level BPA | bucket 단위 차단 여부 |
| Bucket policy | public read 허용/거부 |
| Object ownership/ACL | ACL 사용 여부·ownership |
| Website hosting | endpoint·index document |

> ⚠️ **BPA가 켜져 있으면 policy로 public을 허용해도 안 열린다.** 반대로 실습 후 닫을 때는 policy 제거 + **BPA enabled 재확인**까지 해야 진짜 닫힌 것.

### 일반 object access vs static website hosting (Day4 preview)
| 일반 object access | static website hosting |
|---|---|
| S3 API endpoint 중심 | 별도 website endpoint 제공 |
| permission 닫히면 접근 불가 | public hosting은 **별도 설정** 필요 |
| private object 저장에 적합 | 공개 정적 사이트에 사용 |

### S3 ↔ Kubernetes storage 비교
| Kubernetes | AWS |
|---|---|
| ConfigMap mount | 작은 설정파일처럼 보이나 목적 다름 |
| PV/PVC | block/file storage에 더 가까움 |
| object storage | **S3**가 대표 |
| container image layer | **ECR**이 더 직접적 |

> ⚠️ **S3는 Pod에 mount하는 일반 disk가 아니다.** PV/PVC처럼 파일시스템으로 붙여 쓰는 게 아니라, **app이 S3 API(SDK/HTTP)로 object를 읽고 쓰는** 구조가 일반적. "볼륨 mount 감각"으로 접근하면 permission·endpoint·버전 관리를 file system처럼 오해하게 됨.

### 캡처/기록 가이드
bucket 이름·Region·BPA 상태·Properties의 static hosting 상태를 **따로** 캡처. 공개 URL을 남겼다면 **실습 종료 후 public을 닫았는지**도 함께 기록. 화면엔 민감정보 대신 resource 이름·Region·상태값·rule·tag 같은 **재현 가능한 값**이 보여야 함.

### 흔한 실패 3개
1. bucket name **중복**을 Region 문제로 봄
2. BPA 때문에 website 안 되는 걸 **app 문제**로 봄
3. bucket 안 **object(+version)**를 안 지워서 삭제가 안 됨

### 💬 강사님 경험담 — 이미지 서빙을 EFS로 했다가 수천만원
사용자 업로드 **이미지를 EFS에 올려놓고 그대로 서빙**했더니 비용이 **수천만원** 나왔다. 이걸 **CloudFront(CDN)**로 앞단을 바꾸니 **수백만원**으로 내려갔다.
| 항목 | EFS 직접 서빙 | S3 + CloudFront |
|---|---|---|
| 스토리지 성격 | 공유 file system(NFS) — **GB당 단가 비쌈** | object storage — **저렴** |
| 트래픽 처리 | origin이 매 요청을 다 받음 | CDN **edge cache**가 대신 처리(origin 요청↓) |
| egress 비용 | 요청마다 origin에서 나감 | cache hit이면 origin egress 안 나감 |
| 용도 적합성 | 여러 서버가 **쓰기 공유**할 파일 | **읽기 많은 정적 자산(이미지 등)** |

> ⚠️ **교훈: "저장되니까 서빙도 거기서"가 함정.** 정적 이미지 같은 read-heavy 자산은 EFS(공유 파일시스템)가 아니라 **object storage(S3) + CDN(CloudFront)** 조합이 맞다. EFS는 단가·트래픽 구조상 서빙용이 아니라 **여러 인스턴스가 쓰기까지 공유**해야 할 때 쓰는 것. → 스토리지는 **"저장 용도"와 "서빙 용도"를 분리**해서 고른다.

### 한 줄 요약
S3는 object storage이고, **public access는 "의도 + 안전장치(BPA)"를 함께** 확인한다.
(그리고 **읽기 많은 정적 자산 서빙은 S3+CloudFront** — EFS 직접 서빙은 비용 폭탄.)

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| create-bucket이 `BucketAlreadyExists`/`OwnedByYou` | name은 **전역 unique** → 이름 바꾸기. Region 문제 아님 |
| static site가 403 | app 아님. BPA → bucket policy → object ownership/ACL → website 설정 순 |
| `aws s3 rb`(bucket 삭제)가 실패 | object 잔존. versioning bucket이면 versioned object·delete marker까지 비워야 함 |
| `get-bucket-website`가 `NoSuchWebsiteConfiguration` | website hosting 미설정 상태(정상). 켜야 website endpoint 생김 |
