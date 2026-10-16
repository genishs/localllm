#!/usr/bin/env bash
# lid-ac-ignore.sh - 전원을 꽂아 둔 상태에서는 덮개를 닫아도 절전하지 않게 한다 (노트북을 서버로 쓸 때)
#
#   ./lid-ac-ignore.sh          적용   (배터리일 때는 지금처럼 덮개 닫으면 절전)
#   ./lid-ac-ignore.sh undo     되돌리기
#
# 기존 /etc/systemd/logind.conf 는 건드리지 않고, 조각 파일 하나만 추가/삭제한다.
# 관리자 권한이 필요하다 - 서버의 터미널(데스크톱 또는 SSH)에서 실행할 것.
set -euo pipefail
CONF=/etc/systemd/logind.conf.d/10-lid-ac-ignore.conf

if [ "$(id -u)" -ne 0 ]; then exec sudo "$0" "$@"; fi

if [ "${1:-}" = "undo" ]; then
  rm -f "$CONF"; echo "삭제: $CONF"
else
  mkdir -p "$(dirname "$CONF")"
  printf '[Login]\n# 전원 연결 중엔 덮개를 닫아도 계속 동작 (LLM 서버가 멈추지 않게)\nHandleLidSwitchExternalPower=ignore\n' > "$CONF"
  echo "작성: $CONF"
fi

systemctl kill -s HUP systemd-logind      # 설정 다시 읽기 (로그인 세션은 유지된다)
sleep 1

get() { busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager "$1" | awk '{print $2}' | tr -d '"'; }
ac=$(get HandleLidSwitchExternalPower); bat=$(get HandleLidSwitch)
echo
echo "덮개 닫음 (배터리)    : ${bat}"
echo "덮개 닫음 (전원 연결) : ${ac:-(배터리와 같음)}"
if [ "${1:-}" = "undo" ]; then
  [ -z "$ac" ] && echo "[OK] 되돌렸습니다" || echo "[!] 아직 적용값이 남아 있습니다: $ac"
else
  [ "$ac" = "ignore" ] && echo "[OK] 적용됐습니다 - 전원이 꽂혀 있으면 덮개를 닫아도 절전하지 않습니다" || echo "[!] 적용이 안 됐습니다 (현재: ${ac:-비어 있음})"
fi
