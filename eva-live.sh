#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_FILE="$ROOT_DIR/caddy/compose.ecr.yaml"

die() { printf '오류: %s\n' "$*" >&2; exit 1; }
info() { printf '[eva-dock] %s\n' "$*"; }

load_env() {
  [[ -f "$ENV_FILE" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a

  export DOCK_PORT="${DOCK_PORT:-18080}"
  export DOCK_SECURE_PORT="${DOCK_SECURE_PORT:-17443}"
  export DOCK_UID="${DOCK_UID:-$(id -u)}"
  export DOCK_GID="${DOCK_GID:-$(id -g)}"

  DOCK_DATA_DIR="${DOCK_DATA_DIR:-$ROOT_DIR/data}"
  [[ "$DOCK_DATA_DIR" = /* ]] || DOCK_DATA_DIR="$ROOT_DIR/$DOCK_DATA_DIR"
  export DOCK_DATA_DIR

  DOCK_TLS_CERT_FILE="${DOCK_TLS_CERT_FILE:-$ROOT_DIR/certs/tls.crt}"
  DOCK_TLS_KEY_FILE="${DOCK_TLS_KEY_FILE:-$ROOT_DIR/certs/tls.key}"
  [[ "$DOCK_TLS_CERT_FILE" = /* ]] || DOCK_TLS_CERT_FILE="$ROOT_DIR/$DOCK_TLS_CERT_FILE"
  [[ "$DOCK_TLS_KEY_FILE" = /* ]] || DOCK_TLS_KEY_FILE="$ROOT_DIR/$DOCK_TLS_KEY_FILE"
  export DOCK_TLS_CERT_FILE DOCK_TLS_KEY_FILE
}

require_setup() {
  command -v docker >/dev/null 2>&1 || die 'Docker를 찾을 수 없습니다.'
  docker compose version >/dev/null 2>&1 || die 'Docker Compose v2가 필요합니다.'
  [[ -f "$ENV_FILE" ]] || die '.env 파일이 없습니다. README.md의 서버 설정을 참고하세요.'
  [[ -f "$COMPOSE_FILE" ]] || die "Compose 파일을 찾을 수 없습니다: $COMPOSE_FILE"
}

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

run_up() {
  require_setup
  [[ -n "${DOCK_BACKEND_IMAGE:-}" ]] || die '.env에 DOCK_BACKEND_IMAGE를 설정하세요.'
  [[ -n "${DOCK_CADDY_IMAGE:-}" ]] || die '.env에 DOCK_CADDY_IMAGE를 설정하세요.'
  [[ -f "$DOCK_TLS_CERT_FILE" ]] || die "TLS 인증서를 찾을 수 없습니다: $DOCK_TLS_CERT_FILE"
  [[ -f "$DOCK_TLS_KEY_FILE" ]] || die "TLS 개인키를 찾을 수 없습니다: $DOCK_TLS_KEY_FILE"
  [[ "$DOCK_DATA_DIR" != / ]] || die 'DOCK_DATA_DIR에 루트 디렉터리(/)를 지정할 수 없습니다.'

  mkdir -p "$DOCK_DATA_DIR"
  compose config --quiet
  info "ECR 이미지 pull: backend=$DOCK_BACKEND_IMAGE, caddy=$DOCK_CADDY_IMAGE"
  compose pull
  info 'ECR 이미지로 백엔드와 Caddy를 시작합니다.'
  compose up -d --wait --wait-timeout 180

  printf '\n접속 URL: https://%s:%s/#/live\n' "${DOCK_TEST_HOST:-localhost}" "$DOCK_SECURE_PORT"
}

run_down() {
  require_setup
  compose down
}

run_status() {
  require_setup
  compose ps
}

run_logs() {
  require_setup
  local follow=() target=''
  while (($#)); do
    case "$1" in
      -f|--follow) follow=(-f);;
      live|backend) target=backend;;
      caddy) target=caddy;;
      *) die "로그 대상 또는 옵션이 잘못되었습니다: $1 (사용법: ./eva-live.sh logs [-f] {live|caddy})";;
    esac
    shift
  done
  [[ -n "$target" ]] || die '로그 대상을 지정하세요: live 또는 caddy'
  compose logs "${follow[@]}" "$target"
}

load_env
case "${1:-}" in
  up|up-ecr) run_up;;
  down) run_down;;
  status) run_status;;
  logs|log) shift; run_logs "$@";;
  -h|--help|help|'')
    printf '사용법:\n  %s {up-ecr|down|status}\n  %s {logs|log} [-f] {live|caddy}\n' "$0" "$0";;
  *) die "알 수 없는 명령입니다: $1";;
esac
