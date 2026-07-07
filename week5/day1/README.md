# Week 5 Day 1 — AWS 계정 안전과 운영 좌표계

## 한눈에 보기

| 교시 | 주제 | 핵심 |
|---|---|---|
| 1교시 | Week4 요약 + AWS로 넘어가는 이유 | Kubernetes 운영 질문을 AWS resource로 연결, 목표는 "서비스 생성"이 아니라 **운영 경계 이해**, evidence note 형식 만들기 |
| 2교시 | AWS 계정 안전장치 | root user vs IAM, **MFA·Budget·access key·billing 권한**을 실습 전 안전장치로, 비용·보안 사고 막는 최소 checklist |
| 3교시 | Region/AZ와 장애 경계 | Region=위치·법적경계, AZ=**장애 격리 단위**, 서울 `ap-northeast-2` 고정, "resource 안 보이면 **첫 확인은 Region**" |
| 4교시 | AWS 서비스 운영 지도 | service를 알파벳 암기 ❌ **운영 질문(어디서 실행/접속/저장/누가 접근/evidence/비용)으로 분류**, CloudWatch(상태) vs CloudTrail(누가 호출), managed=책임이 **사라지는 게 아니라 위치 이동** |
| 5교시 | VPC와 Security Group 기본 | VPC=격리된 network 경계, public subnet 조건(route→IGW + public IP + SG), **SG는 stateful**, 접속 안 될 때 확인 순서, SG만 열어선 안 됨 |
| 6교시 | EC2 첫 관찰 | EC2=아래 계층 compute, 생성 전 **AMI·type·network·SG·storage·tag** 읽기, **stop≠안전한 삭제**(EBS·EIP 잔여 비용), instance type 네이밍, EIP는 놀리면 더 과금 |
| 7교시 | S3 첫 관찰 | S3=object storage(file server ❌, mount disk ❌ → **S3 API로 read/write**), bucket name **전역 unique**, **BPA가 policy보다 상위 안전장치**, URL 존재≠public, versioned object 안 지우면 삭제 안 됨 |
| 8교시 | 구름 EXP 배움일기 | 하루 정리 + 다음(EC2/ALB) 준비 질문, 생성한 resource **cleanup 상태 확인** |

## 파일 목록

| 파일 | 내용 |
|---|---|
| `lesson-01.md` ~ `lesson-08.md` | 교시별 실습 확인 기록·확인 질문 답변·notes·Blocker Log |

## 핵심 한 줄
AWS 첫날의 목표는 resource를 많이 만드는 게 아니라, **계정 사고를 막는 안전장치(root/MFA/Budget/IAM)**와 **앞으로 만들 resource를 같은 기준으로 관찰할 좌표계(Region/AZ → VPC/SG → EC2/S3)**를 세우는 것. 각 resource는 **생성 전 관찰 기준 · 비용 기준 · 삭제 기준**을 말할 수 있어야 한다.

## 자주 하는 오해 (Day1에서 잡은 것)
- resource가 안 보임 → 서비스 문제가 아니라 **Region**부터
- instance running → app 정상 ❌ (status check → SG → app process 분리)
- EC2 stop → 비용 0 ❌ (EBS·EIP·snapshot 잔여)
- S3 URL 있음 → 공개됨 ❌ (BPA·object permission 확인)
- EFS로 이미지 직접 서빙 → 비용 폭탄, **S3+CloudFront**가 정답 (강사 경험담)

## 다음 연결
Day2에서 EC2/ALB를 **직접 생성·접속**하며 오늘 만든 관찰 좌표계(AMI·SG·public IP·비용·cleanup)를 실제로 적용한다.
