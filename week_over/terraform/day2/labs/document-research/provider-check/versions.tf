# 3교시 실습용: Provider 신원(namespace/source/version)을 CLI로 확인하기 위한 최소 선언
# 리소스는 만들지 않는다. init + lock file + providers schema 로 문서 개념만 관찰한다.
terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
