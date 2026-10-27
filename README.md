# EVA Dock 배포

EVA Dock의 사전 빌드 이미지를 ECR에서 받아 실행하는 배포용 저장소입니다. `eva-live.sh`와 `caddy/compose.ecr.yaml`로 백엔드와 Caddy 컨테이너를 관리합니다. Caddy 설정은 Caddy 이미지에 포함되어 있어 별도 Caddyfile은 필요하지 않습니다.

## 저장소 구성

- `eva-live.sh`: ECR 이미지 pull, 실행, 상태 확인, 로그 조회, 종료
- `caddy/compose.ecr.yaml`: 백엔드와 Caddy 서비스 정의
- `.env`: 이미지 버전, 호스트/포트, 인증서와 데이터 경로 등 서버별 설정. Git에 올리지 않습니다.
- `certs/tls.crt`, `certs/tls.key`: HTTPS 서버 인증서와 개인키. Git에 올리지 않습니다.
- `data/`: SQLite DB와 런타임 데이터. Git에 올리지 않습니다.

## 사전 준비

- Linux 서버, Docker Engine, Docker Compose v2
- ECR 이미지에 접근할 AWS 자격 증명
- 인증서 SAN에 접속 호스트가 포함된 TLS 인증서와 매칭되는 개인키

AWS CLI 프로필을 사용한다면 Docker 로그인은 다음과 같이 합니다.

```bash
aws ecr get-login-password --region ap-northeast-2 --profile eva-dock-ecr \
  | docker login --username AWS --password-stdin 211722900905.dkr.ecr.ap-northeast-2.amazonaws.com
```

프로필 이름과 레지스트리 주소는 실제 환경에 맞게 바꿉니다.

## 환경 설정

예시 파일을 복사한 뒤 서버에 맞게 수정합니다.

```bash
cp .env.example .env
```

`.env`에서 `DOCK_TEST_HOST`와 ECR 저장소 주소를 실제 값으로 설정합니다. `DOCK_VERSION`은 백엔드 이미지 태그에 사용되며 Caddy 이미지는 `latest`를 사용합니다. 데이터와 인증서 경로가 상대 경로이면 저장소 루트를 기준으로 해석됩니다. 인증서와 개인키를 지정한 위치에 넣으세요.

DB fallback으로 EVA 피드백을 조회하는 경우에만 `EVA_MYSQL_USER`, `EVA_MYSQL_PASSWORD` 등 EVA MySQL 설정을 추가합니다. EVA별 M2M 및 그룹 설정은 EVA Dock 관리 화면에서 구성합니다.

## 실행 및 관리

```bash
chmod +x eva-live.sh

# ECR에서 이미지 pull 후 실행
./eva-live.sh up-ecr

# 상태 확인
./eva-live.sh status

# 백엔드 로그
./eva-live.sh logs -f live

# Caddy 로그
./eva-live.sh logs -f caddy

# 종료
./eva-live.sh down
```

브라우저 접속 주소는 `https://<DOCK_TEST_HOST>:<DOCK_SECURE_PORT>/`입니다. Docker Compose는 host network를 사용하므로 서버 방화벽에서 `DOCK_PORT`와 `DOCK_SECURE_PORT`의 사용 여부 및 접근 정책을 확인하세요.

`down`은 컨테이너와 Compose 리소스를 정리하지만 `data/`의 바인드 마운트 DB와 Caddy named volume은 삭제하지 않습니다.

## 이미지 업데이트

`.env`에서 `DOCK_VERSION` 또는 `DOCK_CADDY_IMAGE`를 변경한 뒤 `./eva-live.sh up-ecr`를 실행하면 설정된 이미지를 다시 pull하고 컨테이너를 갱신합니다. 동일 태그의 이미지가 ECR에서 교체된 경우에도 `up-ecr`가 pull을 수행합니다.

## Git 제외 파일

`.env`, 인증서와 개인키, DB 및 런타임 데이터는 서버별 설정 또는 운영 데이터이므로 커밋하지 않습니다. 새 서버에서 이 파일들을 별도로 준비해야 합니다.
