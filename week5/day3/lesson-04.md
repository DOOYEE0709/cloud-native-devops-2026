# 4교시: Container service와 ALB 연결

> App Runner 경로면 ALB가 자체 URL로 추상화돼 이 화면이 안 보인다. 아래는 **ECS + ALB** 기준. (App Runner는 health/port/logs 개념은 동일)

## 실습 확인 기록

| 명령/확인 | 결과 |
|---|---|
| | |

## 확인 질문 답변

| 질문 | 답변 |
|---|---|
| ALB 503이 뜨면 가장 먼저 볼 것은? | **target health**와 **desired/running count**. 등록된 healthy target이 0이면 ALB가 보낼 곳이 없어 503. count가 0이거나 target unhealthy면 그쪽부터 |
| container port와 target group port가 다르면? | health check가 container에 도달 못 해 **target unhealthy(timeout/refused)** → traffic 안 감. task definition portMappings와 target group Port를 **일치**시켜야 함 |
| service URL이 200인데 왜 health check는 봐야 하나? | URL 응답만으로 정상 착각 금지. desired=running이고 **모든 target이 healthy**여야 장애 시 안전. desired=1이면 그 task 죽는 순간 서비스 중단 위험 |

## notes

- **연결 흐름**: `User → ALB → Listener(:80) → Target Group → ECS Task → Container Port → Web App`
- **port가 3곳에서 맞아야 함**: ① container app이 listen하는 port ② task definition portMappings ③ target group Port
  - EC2는 보통 80이지만 container app은 3000/5000/8080 등 다른 port로 listen → 이걸 정확히 맞춰야 health check·routing 성공
- **ECS ↔ ALB 연결 시 확인**: listener(80/443), target group(protocol·port·health check path), container port, desired count ≥ 1, SG(ALB → task 허용)
- **target health 실패 대표 원인**:
  | 원인 | 증상 | 복구 |
  |---|---|---|
  | wrong container port | target timeout/refused | task port mapping 수정 |
  | wrong health path | 404/unhealthy | path를 실제 endpoint로 |
  | SG blocked | timeout | ALB SG → task SG 허용 |
  | task stopped | running count 0 | task stopped reason 확인 |
- **실패 증상별 첫 확인**: ALB 503 → target health·count / target unhealthy → health path·container port·SG / deployment pending → image pull 권한·subnet·capacity / URL 5xx → app logs·env·port
- **App Runner vs ALB**: App Runner는 자체 URL로 ALB를 추상화. "ALB를 직접 보느냐 vs service가 가려주느냐"의 차이 — health/port/logs는 어차피 봐야 함
- **desired count 1의 위험**: 장애/재배포 시 그 task 한 개가 죽으면 서비스 공백 → 운영은 2 이상 권장

### Serverless/VPC 판단 기준
- **VPC에 들어간다 = 아키텍처를 다시 본다**
  - Lambda든 App Runner든 VPC가 필요해지는 순간 subnet, security group, route table, NAT, VPC endpoint, private resource 접근까지 같이 설계해야 한다.
  - "그냥 VPC에 넣는다"가 아니라, 왜 private network가 필요한지 먼저 확인한다.
- **Lambda + VPC latency**
  - 예전 Lambda VPC는 ENI 생성 때문에 cold start가 몇 초 늘어나는 사례가 많았다.
  - 지금은 Hyperplane ENI로 개선됐지만, VPC 연결은 여전히 ENI lifecycle, subnet/security group 조합, NAT/endpoint 구성 영향을 받는다.
  - 그래서 "VPC에 들어가면 매번 6~7초 느리다"가 아니라, cold start/초기 연결/네트워크 경로를 측정해서 판단한다.
- **Lambda에서 DynamoDB를 자주 쓰는 이유**
  - Lambda + DynamoDB는 보통 Lambda를 내 VPC에 넣지 않아도 된다.
  - DynamoDB는 managed service endpoint로 접근하고, RDS처럼 connection pool을 직접 관리하는 방식이 아니다.
  - 그래서 짧게 실행되고 많이 확장되는 Lambda와 잘 맞는다.
- **대표 best choice 패턴**
  - 정적 웹사이트: `User -> CloudFront -> S3`
  - Serverless API: `User -> API Gateway/Lambda Function URL -> Lambda -> DynamoDB`
  - 파일 업로드/다운로드: `User -> CloudFront/S3`, Lambda는 presigned URL 발급이나 metadata 처리
  - 관계형 DB가 꼭 필요함: `API Gateway -> Lambda in VPC -> RDS Proxy -> RDS/Aurora`
- **RDS/private DB가 필요한 경우**
  - private RDS에 접근하려면 Lambda가 같은 VPC에 들어가야 한다.
  - Lambda가 RDS connection을 직접 많이 열고 닫으면 DB connection이 고갈될 수 있으므로 production에서는 RDS Proxy를 고려한다.
  - "DB를 외부로 뺀다"는 말이 public RDS 노출을 뜻하면 위험하다. 더 좋은 판단은 DynamoDB로 해결 가능한지, RDS가 꼭 필요한지, RDS Proxy가 필요한지 검토하는 것이다.
- **VPC가 필요한지 묻는 질문**
  - 이 workload가 꼭 private subnet의 resource에 접근해야 하는가?
  - DynamoDB, S3, SQS 같은 managed service endpoint로 해결할 수 있는가?
  - 외부 인터넷 호출이 필요하다면 NAT Gateway 비용/장애/latency를 감당할 것인가?
  - Lambda보다 ECS/App Runner가 DB 연결을 오래 유지하기에 더 적합한가?
- **Observability는 선택이 아니라 운영 조건**
  - 네트워크와 managed service가 늘어날수록 CloudWatch Logs/Metrics/Alarm, X-Ray/OpenTelemetry 같은 관찰 지점이 필요하다.
  - 단순히 "성공/실패"가 아니라 duration, cold start, timeout, error rate, throttle, DB latency, external API latency, connection count를 본다.
  - observability는 어쩔 수 없이 봐야 하는 비용이지만, 장애 원인을 찾기 위한 최소 장치다.

## Blocker Log

| 증상 | 확인한 것 |
|---|---|
| | |
