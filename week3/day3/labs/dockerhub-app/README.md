# W3D3 Docker Hub App

GitHub Actions에서 Docker image를 build/push하는 실습용 작은 앱이다.

## 로컬 Build
```bash
cd /mnt/d/paperclip
docker build -t w3d3-dockerhub-app:local week3/day3/labs/dockerhub-app
```

## 로컬 실행
```bash
docker rm -f w3d3-dockerhub-app 2>/dev/null || true
docker run -d --name w3d3-dockerhub-app -p 18088:8080 w3d3-dockerhub-app:local
curl -s http://localhost:18088/health
docker logs --tail=20 w3d3-dockerhub-app
docker rm -f w3d3-dockerhub-app
```

## Docker Hub Pull/Run 예시
GitHub Actions push가 성공한 뒤 `DOCKERHUB_USERNAME`을 실제 Docker Hub 계정으로 바꿔 실행한다.

Public repository:

```bash
docker pull DOCKERHUB_USERNAME/w3d3-dockerhub-app:0.1.0
docker run -d --name w3d3-dockerhub-app -p 18088:8080 DOCKERHUB_USERNAME/w3d3-dockerhub-app:0.1.0
curl -s http://localhost:18088/health
docker rm -f w3d3-dockerhub-app
```

Private repository:

```bash
docker login -u DOCKERHUB_USERNAME
docker pull DOCKERHUB_USERNAME/w3d3-dockerhub-app:0.1.0
docker run -d --name w3d3-dockerhub-app -p 18088:8080 DOCKERHUB_USERNAME/w3d3-dockerhub-app:0.1.0
curl -s http://localhost:18088/health
docker rm -f w3d3-dockerhub-app
docker logout
```

`docker login`에는 계정 password 대신 Docker Hub access token을 입력한다.
