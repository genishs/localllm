#!/usr/bin/env bash
# llm-router.sh - 여러 모델을 한 포트(8080)에서 골라 쓰는 llama.cpp router 모드 서버
#
#   ./llm-router.sh start [최대동시모델=1]   켜기 (LAN 공개 + API 키)
#   ./llm-router.sh stop                      끄기
#   ./llm-router.sh status                    모델 목록 / GTT 사용량 / 접속 주소
#
# 모델 목록은 llm-presets.ini. 경로는 환경변수로 바꿀 수 있다(아래 기본값).
# 옛 단일 모델 스크립트(llm.sh)를 쓴 적이 있다면 같은 유닛 이름(llm-server)이라 둘 중 하나만 돈다.
# 재부팅하면 자동으로 켜지지 않는다 - 부팅 후 start 를 다시 실행하고, 반드시 status 로 GTT 를 확인한다.
set -uo pipefail

# llama.cpp 공식 사전빌드(Vulkan) - ext4 에 둘 것(NTFS 는 .so 링크가 깨진다).
# 2026-10-17 b11539 -> b11701: Nemotron 3.5 Bolt(PR #30520)와 MiniCPM-V 4.7(PR #29416)을 읽으려면 b11701 이상이 필요하다.
# 되돌리기: LLAMA_BIN=$HOME/llama.cpp-bin/b11539/llama-b11539 (bolt 와 mcv 는 못 쓴다)
BIN="${LLAMA_BIN:-$HOME/llama.cpp-bin/b11701/llama-b11701}"
PRESETS="${LLM_PRESETS:-$HOME/llm-presets.ini}"
UNIT="${LLM_UNIT:-llm-server}"
LOG="${LLM_LOG:-$HOME/gpu_jobs/logs/llm-server.log}"
KEYFILE="${LLM_KEYFILE:-$HOME/.config/llm-api-key}"
PORT="${LLM_PORT:-8080}"

key() { cat "$KEYFILE"; }

# 기본 경로가 나가는 NIC 의 주소 - 클라이언트 설치 때 입력할 서버 주소
lan_ip() { ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="src"){print $(i+1); exit}}'; }

# GTT(GPU 공유 메모리) 사용량. 모델이 GPU 에 올라갔는지 확인하는 가장 빠른 방법
gtt() {
  local f
  for f in /sys/class/drm/card*/device/mem_info_gtt_used; do
    [ -r "$f" ] || continue
    awk -v t="$(cat "${f%used}total")" '{printf "%.1fG / %.0fG", $1/1073741824, t/1073741824}' "$f"
    return
  done
  echo "?"
}

# /v1/models -> "cn(loaded), q36(unloaded), ..."
models() {
  curl -s -m 5 -H "Authorization: Bearer $(key)" "http://127.0.0.1:$PORT/v1/models" |
    python3 -c "import json,sys;print('모델:',', '.join(m['id']+'('+m.get('status',{}).get('value','?')+')' for m in json.load(sys.stdin)['data']))"
}

case "${1:-status}" in
  start)
    [ -x "$BIN/llama-server" ] || { echo "llama-server 가 없다: $BIN  (LLAMA_BIN 으로 경로 지정)"; exit 1; }
    [ -f "$PRESETS" ] || { echo "프리셋이 없다: $PRESETS  (LLM_PRESETS 로 경로 지정)"; exit 1; }
    mkdir -p "$(dirname "$LOG")" "$(dirname "$KEYFILE")"
    if [ ! -s "$KEYFILE" ]; then   # 처음 켤 때만 API 키 생성(화면에 찍지 않는다)
      ( umask 077; head -c 18 /dev/urandom | base64 | tr -d '/+=' > "$KEYFILE" )
      echo "API 키를 만들었다: $KEYFILE  (서버에서만 읽는다. 클라이언트 설치 때 입력)"
    fi
    systemctl --user stop "$UNIT" 2>/dev/null; systemctl --user reset-failed "$UNIT" 2>/dev/null; : > "$LOG"
    systemd-run --user --unit="$UNIT" --description="llama-server router" \
      --property="StandardOutput=append:$LOG" --property="StandardError=append:$LOG" \
      "$BIN/llama-server" --models-preset "$PRESETS" --models-max "${2:-1}" \
        --host 0.0.0.0 --port "$PORT" --api-key "$(key)" >/dev/null
    # curl -f 필수: 모델을 올리는 동안 /health 는 503 을 주는데, -f 가 없으면 그걸 '준비됨'으로 오판한다
    for _ in $(seq 1 30); do curl -sf -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break; sleep 1; done
    models 2>/dev/null || echo "(모델 목록을 아직 못 읽었다 - 로그: $LOG)"
    echo "GTT $(gtt)   (모델이 올라간 뒤 0.0G 면 GPU 를 못 쓰는 것 - docs/troubleshooting.md)"
    ip="$(lan_ip)"; [ -n "$ip" ] && echo "접속 주소(클라이언트 설치 때 입력): http://$ip:$PORT"
    ;;
  stop)
    systemctl --user stop "$UNIT"; echo 꺼짐
    ;;
  status)
    models 2>/dev/null || echo 꺼짐
    echo "GTT $(gtt)"
    ip="$(lan_ip)"; [ -n "$ip" ] && echo "접속 주소: http://$ip:$PORT"
    ;;
  *)
    echo "사용: $0 {start [최대동시모델]|stop|status}"; exit 1
    ;;
esac
