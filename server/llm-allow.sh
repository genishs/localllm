#!/usr/bin/env bash
# llm-allow.sh - 방화벽(ufw)에서 LLM 서버 포트(기본 8080)를 "그 PC 한 대"에만 열어준다
#
#   ./llm-allow.sh 192.168.0.10          이 IP 하나만 허용
#   ./llm-allow.sh 192.168.0.10 remove   그 허용 규칙 삭제
#   ./llm-allow.sh list                  현재 8080 관련 규칙 보기
#
# 공용망(공유오피스·카페 등)에서는 대역 전체를 열지 말고 내 PC 의 IP 하나만 연다.
# 클라이언트 설치 스크립트(install.ps1)가 접속에 실패하면 "이 PC 의 IP" 와 이 명령을 그대로 보여 준다.
# 관리자 권한 필요 - 서버의 터미널(데스크톱 또는 SSH)에서 실행.
set -euo pipefail
PORT=8080   # llm-router.sh 의 LLM_PORT 를 바꿨다면 여기도 같이 바꾼다
if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi

if [ "${1:-list}" = "list" ]; then ufw status numbered | grep -E "$PORT|Status"; exit 0; fi

ip="$1"
[[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || { echo "IP 형식이 아닙니다: $ip"; exit 1; }

if [ "${2:-}" = "remove" ]; then
  ufw delete allow from "$ip" to any port "$PORT" proto tcp
else
  ufw allow from "$ip" to any port "$PORT" proto tcp comment 'llama-server one PC'
fi
echo; ufw status | grep -E "$PORT|Status"
