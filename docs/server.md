# 서버 운영

llama.cpp 의 `llama-server` **router 모드** 하나가 포트 8080 에서 모든 모델을 서비스한다. 클라이언트는 요청의 `model` 값만 바꿔 모델을 고른다.
하드웨어·OS 설정은 [hardware.md](hardware.md), 모델 목록은 [models.md](models.md), 문제 해결은 [troubleshooting.md](troubleshooting.md).

| 파일 | 역할 |
|---|---|
| [`server/llm-router.sh`](../server/llm-router.sh) | router 서버 시작/중지/상태 |
| [`server/llm-presets.ini`](../server/llm-presets.ini) | 모델 목록과 모델별 옵션 |
| [`server/models.tsv`](../server/models.tsv) | 모델 파일의 출처·크기·sha256 (다시 받을 때 사용). `status`: `current` 사용 중 / `compare` 비교용 / `staging` 추가 중(지금은 없음) / `local-convert` 직접 변환한 파일(내려받는 파일이 아님) |
| [`server/llm-allow.sh`](../server/llm-allow.sh) | 방화벽에서 PC 한 대(IP)만 8080 에 열기 |
| [`server/lid-ac-ignore.sh`](../server/lid-ac-ignore.sh) | 전원이 꽂힌 노트북은 덮개를 닫아도 절전하지 않게 |

## 1. 처음 세우는 순서

1. [hardware.md](hardware.md)의 OS 설정: `render`/`video` 그룹, `ttm.pages_limit`, (노트북이면) 덮개 설정.
2. llama.cpp 공식 사전빌드(Vulkan)를 **ext4** 에 푼다. 지금 쓰는 빌드는 **b11701**(2026-10-16)이다 - `bolt` 와 `mcv` 가 b11701 이상을 요구한다(이전 b11539 에는 해당 PR 이 없다). NTFS 에 두면 `.so` 심볼릭 링크가 깨진다([troubleshooting.md](troubleshooting.md#ntfs-에-둔-빌드가-안-뜬다)).
   ```bash
   mkdir -p ~/llama.cpp-bin/b11701 && cd ~/llama.cpp-bin/b11701
   curl -LO https://github.com/ggml-org/llama.cpp/releases/download/b11701/llama-b11701-bin-ubuntu-vulkan-x64.tar.gz
   echo "1b0e8ddc82545fe9a5ce90b4c46d8651a0ab82390c48330a8b6c8b4ed76ddd00  llama-b11701-bin-ubuntu-vulkan-x64.tar.gz" | sha256sum -c -
   tar -xzf llama-b11701-bin-ubuntu-vulkan-x64.tar.gz      # -> llama-b11701/llama-server
   ./llama-b11701/llama-server --version                   # version: 0.7.0-dev (build 11701, commit 01fc3aae8)
   ```
3. 모델을 받아 sha256 을 대조한다(아래 [새 모델 추가](#새-모델-추가-체크리스트) 3번).
4. `server/` 의 파일을 서버 홈에 복사하고 `llm-presets.ini` 의 모델 경로를 자기 것으로 고친다.
   ```bash
   cp server/llm-router.sh server/llm-allow.sh server/lid-ac-ignore.sh ~/ && cp server/llm-presets.ini ~/
   chmod +x ~/llm-*.sh ~/lid-ac-ignore.sh
   ```
5. 켠다: `~/llm-router.sh start` - **켠 뒤 `GTT` 가 모델 크기만큼 올라갔는지 반드시 확인**한다([GPU 사용 확인](#gpu-를-쓰는지-확인)).
6. 클라이언트 PC 가 접속하려면 방화벽을 연다: `~/llm-allow.sh <PC 의 IP>` ([방화벽](#방화벽)).
7. Windows PC 에서 [설치 스크립트](../client/windows/install.ps1)를 실행한다. 서버 주소는 설치 중 입력한다 - 주소는 `~/llm-router.sh status` 가 마지막 줄에 보여 준다(`hostname -I` 도 된다).

## 2. router 모드가 하는 일

```
요청 { "model": "q36", ... } --> router(8080, API 키) --> 자식 서버(127.0.0.1:임의포트, q36 로드)
```

- `--models-preset <INI>`: 모델 목록과 옵션을 INI 로 준다. 요청의 `model` 이 섹션 이름과 같으면 그 모델로 보낸다.
- `--models-max 1`: **한 번에 한 모델만** 메모리에 둔다. 다른 모델을 요청하면 직전 모델을 내리고 새로 올린다(대체로 17~30초, `fn` 처럼 큰 모델은 80초 안팎). 첫 응답이 느린 것은 정상이다.
- 자식 서버는 `127.0.0.1` 의 임의 포트에만 열린다. 밖에 열리는 것은 router 의 8080 하나이고, **API 키(`--api-key`)** 가 걸려 있다.
- `GET /v1/models` 는 모든 프리셋의 목록과 상태(`loaded`/`unloaded`)를 준다. 클라이언트 설치 스크립트가 이 목록으로 opencode 의 모델 목록을 만든다.
- 내장 웹 UI 도 같은 포트에서 열린다(`http://<서버>:8080`, 설정의 API Key 칸에 키 입력).
- 슬롯은 기본 4개라 동시 요청(서브에이전트)이 속도를 나눠 쓴다.

## 3. llm-router.sh

```bash
~/llm-router.sh start [최대동시모델=1]   # 켜기 (LAN 공개 + API 키)
~/llm-router.sh status                   # 모델 목록 · GTT · 접속 주소
~/llm-router.sh stop                     # 끄기
```

- `systemd-run --user` 로 사용자 유닛(`llm-server`)을 띄운다 - 터미널을 닫아도 살아 있다. (그냥 `&` 로 띄우면 세션이 정리될 때 같이 죽는다.)
- 처음 켤 때 API 키가 없으면 `~/.config/llm-api-key`(권한 600)를 만든다. **키는 화면에 찍지 않는다.** 클라이언트에 알려 줄 때는 서버에서 직접 읽어서 전달한다.
- 경로는 환경변수로 바꿀 수 있다: `LLAMA_BIN`(llama-server 폴더), `LLM_PRESETS`, `LLM_LOG`, `LLM_KEYFILE`, `LLM_PORT`, `LLM_UNIT`.
- **재부팅하면 자동으로 켜지지 않는다.** 부팅 후 `start` 를 다시 실행한다.
- 시작할 때 `/health` 를 `curl -f` 로 기다린다. 모델을 올리는 동안 `/health` 는 503 을 주는데, `-f` 가 없으면 이를 「준비됨」으로 오판한다.
- API 키는 `llama-server --api-key` 인자로 넘기므로 같은 서버의 다른 사용자가 `ps` 로 볼 수 있다(단일 사용자 서버 가정). 이 빌드에는 `--api-key-file` 옵션도 있으나 이 구성에서는 시험하지 않았다.
- 옛 단일 모델 스크립트 `llm.sh` 는 같은 유닛 이름(`llm-server`)을 써서 router 와 둘 중 하나만 돈다. 이 레포에는 포함하지 않는다.

## 4. 프리셋 INI 형식

```ini
version = 1

; [*] = 모든 모델 공통
[*]
n-gpu-layers = 999
flash-attn = on
jinja = true
c = 65536
load-mode = none

; 섹션 이름 = 요청의 "model" 값 = opencode 의 halo/cn
; load-on-startup = true : 서버가 켜질 때 바로 올린다(기본 모델)
[cn]
model = /경로/Qwen_Qwen3-Coder-Next-Q4_K_M.gguf
load-on-startup = true

[q36]
model = /경로/Qwen3.6-35B-A3B-UD-Q6_K.gguf
spec-type = draft-mtp
chat-template-kwargs = {"enable_thinking":false}
```

- **키 = `llama-server` 의 CLI 인자 이름에서 앞의 `--` 를 뺀 것.** 긴 이름(`n-gpu-layers`, `flash-attn`, `spec-draft-n-max`)을 쓰고, `c` 같은 짧은 이름도 통한다. 값에 `{}` 가 있는 JSON 은 그대로 한 줄에 쓴다.
- `[*]` 는 공통값이고 **모델 섹션이 같은 키를 쓰면 덮어쓴다**(예: `fn` 은 `load-mode = mmap`).
- 주석은 줄 맨 앞에 `;` 를 둔 한 줄 주석만 쓴다. 이 레포의 파일은 전부 그렇다 - 값 뒤에 붙이는 주석은 시험하지 않았다.
- `load-on-startup = true` 는 router 전용 키다. 한 모델에만 둔다.
- 자주 쓰는 키: `model` `model-draft`(초안 모델) `mmproj`(비전) `lora`(LoRA 어댑터 GGUF) `spec-type`(`draft-mtp` `draft-dflash` `draft-dspark` ...) `spec-draft-n-max` `spec-draft-ngl` `chat-template-kwargs` `temp` `top-p` `top-k` `min-p` `presence-penalty` `repeat-penalty` `cache-type-k`/`cache-type-v` `override-tensor` `load-mode` `c`(문맥 크기).
- 모델마다 문맥이 다르면 그 섹션에 `c = 32768` 처럼 쓴다(`c7` `c7r` `c1`). 클라이언트의 `limit.context` 도 같게 맞춰야 한다 - 설치 스크립트는 이 별칭들을 알고 있다([troubleshooting.md](troubleshooting.md#문맥이-32k-인-모델에서-문맥-초과-오류가-난다)).
- LoRA 를 붙이려면 베이스 `model` 은 그대로 두고 `lora = /경로/어댑터.gguf` 한 줄을 더한다(`c7r` 예시. 이 레포에는 어댑터 파일이 없다 - 자기 어댑터로 바꿔 쓴다). 적용 여부는 자식 서버의 `GET /lora-adapters` 가 scale 1.0 으로 보여 준다.
- 옵션 이름은 llama.cpp 버전마다 바뀐다. 이 빌드(b11701, b11539 도 같다)에서는 옛 `--no-mmap` 이 `--load-mode none` 이 되었다(옛 이름은 invalid argument). 이 문서의 옵션(`--load-mode` `--override-tensor` `--lora` `--mmproj` `--spec-type` `--api-key-file` ...)이 b11701 의 `--help` 에 모두 있는 것을 확인했다. 확인은 `llama-server --help | grep -n <이름>`.
- 모델 머리 주석은 한 형식을 지킨다(모델 / 출처(공개일·라이선스) / 양자화·크기·sha256 / 가속·비고 / 실측).
- 이 레포의 `llm-presets.ini` 의 `model` 경로는 이 서버의 실제 경로다. 다른 장비에서는 자기 경로로 바꾼다.

## 새 모델 추가 체크리스트

1. **엔진이 이 구조를 아는지 확인**: 새 구조의 모델은 새 llama.cpp 빌드가 있어야 읽힌다. 모델 카드의 지원 버전과 llama.cpp 의 커밋·PR 병합일을 본다. (`bolt` 는 PR #30520, 10-15 병합 -> b11701 이상. b11539 에서는 `check_tensor_dims: ... has wrong shape` 로 로드에 실패했다. [troubleshooting.md](troubleshooting.md#새-모델이-로드되지-않는다-llamacpp-빌드가-모델보다-오래됨))
2. **들어가는지 확인**: 파일 크기 + 문맥(KV)이 GTT(56GiB)를 넘지 않아야 한다. 참고로 가장 큰 `cn`(파일 48.7GB)이 GTT 47.5G 를 쓴다. 활성 파라미터가 큰 dense 모델은 대역폭 때문에 느리다([hardware.md](hardware.md)).
3. **받고 sha256 으로 확인**: 크기만 맞으면 끝난 게 아니다(미리 크기를 잡는 다운로더가 있다).
   ```bash
   # Hugging Face 가 공개한 sha256 (lfs.oid)
   curl -s "https://huggingface.co/api/models/<repo>/tree/main?recursive=true" \
     | python3 -c 'import json,sys;[print(e["lfs"]["oid"],e["size"],e["path"]) for e in json.load(sys.stdin) if "lfs" in e]'
   sha256sum <받은 파일>            # 위 값과 같아야 한다
   ```
4. **MTP 층이 있는지 확인**(`spec-type = draft-mtp` 를 쓰려면): 헤더에 `nextn` 텐서가 있어야 한다.
   ```bash
   head -c 32M <파일.gguf> | grep -ac nextn     # 1 이상이면 있음 (MTP 포함 파일에서 확인한 방법)
   ```
   unsloth 의 일반 GGUF 저장소는 MTP 층을 뺀다. `...-MTP-GGUF` 저장소를 따로 받아야 한다.
5. **프리셋 섹션 추가**: 위 머리 주석 형식을 지키고, 모델 카드의 권장 샘플링과 생각(thinking) 처리를 적는다. 생각을 끄는 모델은 `chat-template-kwargs = {"enable_thinking":false}`.
6. **재시작**: `~/llm-router.sh start`. `status` 목록에 새 별칭이 `unloaded` 로 보여야 한다.
7. **시험 요청** (서버에서):
   ```bash
   curl -s http://127.0.0.1:8080/v1/chat/completions \
     -H "Authorization: Bearer $(cat ~/.config/llm-api-key)" -H 'Content-Type: application/json' \
     -d '{"model":"<별칭>","messages":[{"role":"user","content":"hi"}],"max_tokens":32}'
   ```
   첫 응답은 모델을 올리는 시간이 포함된다. 끝난 뒤 **`status` 의 GTT 가 올라갔는지** 확인한다.
8. **재기**: 생성/읽기 속도와 GTT, 초안 수락률을 로그에서 읽어 머리 주석의 「실측」에 적는다([로그](#로그)). 표준 시험과 같은 방법으로 재면 비교할 수 있다([benchmarks.md](benchmarks.md#1-표준-시험-2026-10-17)).
9. **클라이언트**: Windows 에서 설치 스크립트를 다시 실행하면 `/v1/models` 목록에서 새 모델이 opencode 에 들어간다(이름 표는 `install.ps1` 의 `$Known`; 모르는 id 는 id 그대로 표시).
10. **문서**: `server/models.tsv` 에 행을 추가하고 [models.md](models.md)·README 표를 갱신한다.

## 로그

- 위치: `~/gpu_jobs/logs/llm-server.log` (`LLM_LOG` 로 바꿈). `start` 때마다 비운다.
- 자식 서버의 줄은 `[포트]` 접두사가 붙는다 - 어느 모델 줄인지 구분하는 데 쓴다. router 자신의 줄은 접두사가 없다.
  ```bash
  grep -a 'spawning server instance' ~/gpu_jobs/logs/llm-server.log | tail     # 모델 교체 기록 (name=모델 별칭)
  grep -a 'tokens per second' ~/gpu_jobs/logs/llm-server.log | tail            # 읽기(prompt eval) / 생성(eval) 속도
  grep -a 'draft acceptance' ~/gpu_jobs/logs/llm-server.log | tail             # 추측 디코딩 수락률
  ```
- 실시간으로 볼 때 `tail -F | awk` 는 파이프 입력을 버퍼링해 **조용히 아무것도 안 내는** 경우가 있다 - `mawk` 라면 `mawk -W interactive`.

## GPU 를 쓰는지 확인

서버를 켠 뒤 **항상** 확인한다. GPU 를 못 쓰면 경고 없이 CPU 로 돈다(10배 이상 느림).

```bash
~/llm-router.sh status
# 모델: cn(loaded), q36(unloaded), ...
# GTT 47.5G / 56G
```

- 올라간 모델의 GTT 가 대략 이 값이어야 한다: `cn` 47~48G · `ff` 약 46.5G · `q36`/`orn`/`fn` 약 30G · `mcv` 약 32G · `aw`/`bolt` 약 29G · `q38` 약 28G · `lfm` 약 25G · `mg` 약 22.5G · `mel` 약 13G · `c7`/`c7r` 약 9.6G · `c1` 약 4.3G.
- 모델이 `loaded` 인데 **GTT 가 0.0G** 이면 GPU 를 못 쓰는 것이다 -> [troubleshooting.md](troubleshooting.md#재부팅-후-gpu-를-못-쓰고-cpu-로-돈다).
- 직접 읽기: `awk '{printf "%.1fG\n",$1/1073741824}' /sys/class/drm/card*/device/mem_info_gtt_used` (카드가 여럿이면 GPU 쪽 카드의 값을 본다).

## 방화벽

서버에 방화벽(ufw)이 켜져 있으면 클라이언트 PC 는 8080 에 접속하지 못한다. 설치 스크립트가 접속에 실패하면 「이 PC 의 IP」와 아래 명령을 그대로 보여 준다.

```bash
~/llm-allow.sh 192.168.0.10           # 이 IP 하나만 허용 (예시 주소)
~/llm-allow.sh 192.168.0.10 remove    # 그 규칙 삭제
~/llm-allow.sh list                   # 8080 관련 규칙 보기
```

- 공용망(공유오피스·카페)에서는 대역 전체를 열지 말고 **PC 한 대의 IP** 만 연다.
- 규칙은 PC 의 IP 마다 필요하다. PC 가 다른 망/다른 IP 로 접속하면 새로 열어야 한다.
- 관리자(sudo) 권한이 필요하다 - 서버의 터미널(데스크톱 또는 SSH)에서 실행한다.

## 덮개를 닫아도 계속 돌게 (노트북 서버)

```bash
~/lid-ac-ignore.sh          # 전원이 연결된 동안 덮개를 닫아도 절전하지 않는다 (배터리일 때는 그대로 절전)
~/lid-ac-ignore.sh undo     # 되돌리기
```

`/etc/systemd/logind.conf.d/10-lid-ac-ignore.conf` 에 `HandleLidSwitchExternalPower=ignore` 한 줄짜리 조각 파일만 추가/삭제하고 `systemd-logind` 에 HUP 을 보내 다시 읽게 한다(로그인 세션은 유지). 기본값은 덮개를 닫으면 절전이라, 전원을 꽂아도 서버와 LAN 접속이 멈춘다.

## API 키

- 서버: `~/.config/llm-api-key` (권한 600, 첫 `start` 때 자동 생성). 직접 만들 때: `umask 077; head -c 18 /dev/urandom | base64 | tr -d '/+=' > ~/.config/llm-api-key`.
- 클라이언트: 설치 스크립트가 숨김 입력으로 받아 사용자 환경변수 `LLM_KEY` 에 저장하고, opencode 설정에는 `{env:LLM_KEY}` 로만 적는다(키가 설정 파일에 들어가지 않는다).
- 키를 바꾸면 `llm-router.sh start` 로 재시작하고 클라이언트 설치 스크립트를 다시 실행한다(거부되면 새 키를 묻는다).
- **키를 레포·메모·로그·메신저에 평문으로 남기지 않는다.**
