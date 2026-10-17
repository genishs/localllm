# localllm

집에서 돌리는 **로컬 LLM 코딩 에이전트 구성**을 기록하고 설치까지 묶어 둔 레포.
AMD Strix Halo 리눅스 서버에서 llama.cpp 를 router 모드로 돌리고, Windows PC 에서 [opencode](https://github.com/anomalyco/opencode) 코딩 에이전트로 접속한다.

- 서버 설정(`server/`), Windows 설치 스크립트(`client/windows/`), 모델 카탈로그·벤치마크·운영·문제 해결 문서(`docs/`)로 이루어져 있다.
- 수치는 직접 잰 값이다(모델 카드의 주장은 따로 표시). 실전 과제는 모델당 1회(n=1)라 경향으로만 읽는다.
- 라이선스 미지정(추후 결정). 사용하는 제3자 소프트웨어와 모델의 라이선스는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## 구성

```
Windows PC                                   Strix Halo 서버
 opencode  --HTTP /v1 + API 키-->  :8080  llama-server (router 모드, llama.cpp b11701 / Vulkan)
 (provider "halo")                          └ 요청의 model 이름으로 모델 선택 (한 번에 1개, 교체 17~80초)
                                              15종: cn q36 mg orn mel bolt lfm mcv / fn ff q38 aw c7 c7r c1
```

- **서버**: llama.cpp b11701(공식 사전빌드, Vulkan 백엔드)의 router 모드. AMD Strix Halo / Radeon 8060S, 64GB 통합 메모리 중 56GB 를 GPU 공유 메모리(GTT)로 쓴다. 포트 8080, API 키 인증, 모델은 한 번에 하나만 올리고 요청의 `model` 이름에 따라 자동 교체한다.
- **클라이언트**: Windows PC 의 opencode v1.18.35. OpenAI 호환 제공자 `halo`(표시 이름 「Strix Halo LLM」)로 서버에 붙는다.
- 이 서버에서는 메모리 대역폭이 속도를 정한다 - 활성 파라미터가 작은 MoE 모델이 빠르고 dense 30B 는 느리다.

### 서버 사양 요약

| 항목 | 내용 |
|---|---|
| 기종 | ASUS TUF Gaming A14 (FA401EA) 노트북 |
| CPU / GPU | AMD Ryzen AI MAX+ 392 (12코어/24스레드) / 내장 Radeon 8060S (RDNA 3.5, gfx1151) |
| 메모리 | 64GB LPDDR5X 통합 메모리 (OS 인식 60.94GiB), 전용 VRAM 0.5GiB, GPU 공유 메모리(GTT) 56GiB |
| 저장장치 | NVMe 2TB (모델) + NVMe 1TB (OS) |
| OS / 실행기 | Ubuntu 26.04.1 LTS (커널 7.0) / llama.cpp b11701, Vulkan (Mesa 26.0.8 RADV) |
| 클라이언트 | Windows 10/11 x64, PowerShell 5.1+, 서버와 같은 LAN 에서 TCP 8080 접속 가능 |

자세한 내용과 서버를 따라 만들 때의 기준: [docs/hardware.md](docs/hardware.md).

## 빠른 설치 (새 Windows PC)

PowerShell 에서 **한 줄**:

```powershell
irm https://raw.githubusercontent.com/genishs/localllm/main/client/windows/install.ps1 | iex
```

미리 준비할 것:
- **서버 주소(IP)** - 설치 중에 입력한다(스크립트에 박혀 있지 않다). 서버에서 `~/llm-router.sh status` 를 실행하면 마지막 줄에 `접속 주소: http://<IP>:8080` 이 나온다(`hostname -I` 도 된다). IP 만 입력해도 되고, `IP:포트`·호스트 이름·전체 URL 도 받는다.
- **API 키** - 서버 소유자에게 안전한 경로로 받는다. 입력은 화면에 보이지 않고, 사용자 환경변수 `LLM_KEY` 에만 저장되며, 설정 파일에는 `{env:LLM_KEY}` 로만 적힌다.
- 서버 방화벽에서 **이 PC 의 IP 허용**. 접속에 실패하면 스크립트가 이 PC 의 IP 와 서버에서 실행할 명령(`~/llm-allow.sh <IP>`)을 보여 주고 끝난다 - 허용한 뒤 같은 명령을 다시 실행하면 된다.

설치 스크립트가 하는 일(다시 실행해도 안전하다):
1. 서버 주소 입력(이전에 쓴 값이 기본값) -> 사용자 환경변수 `LLM_URL`.
2. API 키 입력 -> `GET /v1/models` 로 확인(401 이면 최대 3번 다시 묻는다).
3. opencode **v1.18.35** 설치 - GitHub 릴리스에서 받아 **sha256 검증**, 이 CPU 에서 안 돌면 baseline 빌드로 대체.
4. 서버의 모델 목록으로 opencode 설정을 쓴다. 기존 `opencode.json` 이 있으면 **관리하는 키만 바꾸고**(`$schema` · `provider.halo` · `enabled_providers` · `share` · `model` · `permission`) 나머지(theme, keybinds, 다른 제공자 등)는 그대로 둔다. 외부 제공자는 차단(`enabled_providers: ["halo"]`)하고 공유는 끈다. `permission` 은 기존 값을 유지(없으면 수정·명령 모두 `ask`), 기본 모델은 쓰던 `halo/...` 모델이 서버에 있으면 유지하고 아니면 `halo/cn`. 모델마다 문맥 크기가 다르면 맞춰 쓴다(32K 모델은 32768). 바꾸기 전 설정은 `.bak-날짜` 로 백업하고, 쓰기 전에 JSON 을 다시 읽어 검증한다.
5. 작업 폴더 선택 + 바탕화면 실행 파일 `opencode-local.bat`.
6. 사용법 안내, 바로 시작할지 묻기.

인터넷에서 받은 스크립트를 바로 실행하는 방식이라, 먼저 읽어 보고 싶다면 파일로 저장해서 실행한다:

```powershell
irm https://raw.githubusercontent.com/genishs/localllm/main/client/windows/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File install.ps1
```

## 15개 모델

서버(router)에서 고를 수 있는 모델 전부. 앞의 8종(`cn` `q36` `mg` `orn` `mel` `bolt` `lfm` `mcv`)이 일반 사용 후보(`mcv` 는 이미지·영상용), 나머지 7종(`fn` `ff` `q38` `aw` `c7` `c7r` `c1`)은 실험·비교·기준선용이다. 15종 모두 표준 시험을 마쳤다.

| 약어 | 풀네임 | 발표처(공개) | 파라미터(전체·활성) | 필요 메모리(파일) | 실측 점유(GTT) | 특징 |
|---|---|---|---|---|---|---|
| `cn` | Qwen3-Coder-Next 80B-A3B (Q4_K_M) | Qwen (2026-01-30) | 80B · 3B | 48.7GB | 47.5G | 코딩 전용 MoE, 서버 기본 상주. 생성 56 t/s. 가장 빨리 끝나는 초안형이나 핵심 규칙을 틀릴 수 있다 |
| `q36` | Qwen3.6-35B-A3B (UD-Q6_K, MTP) | Qwen (2026-04-15) | 35B · 3B | 30.0GB | 30.7G | 범용 MoE. 생성 91 t/s. 테트리스 5/5, 큰 과제(갤러그)에서는 시작 직후 멈춤. 표준 시험은 1/2회 통과(채점이 확률적) |
| `mg` | Muse Glimmer 30B (Q4_K_XL, DFlash) | Meta (2026-08-09) | 30B · 30B (dense) | 19.7GB (+초안 1.6GB) | 22.7G | 에이전트용 dense. 생성 26 t/s 로 느리지만 테트리스·갤러그 완성도 1위. 생각 강도 low/xhigh |
| `orn` | Ornith-1.5-35B-A3B (Q6_K, MTP) | ornith-ai (2026-08-18) | 35B · 3B | 29.2GB | 30.0G | 추론 모델(서버에서 생각 끔). 생성 81 t/s. 팀 작업을 성실히 돌리나 갤러그 조작 불가 - 판단 보류 |
| `mel` | Mellum2.1-12B-A2.5B Thinking (Q8_0) | JetBrains (2026-09-20) | 12B · 2.5B | 12.9GB | 13.4G | 코딩 에이전트용 생각 모델(항상 켜짐). **b11701 에서 생성 17.9 t/s, 읽기 524 t/s 로 4~5배 느려진다** - llama.cpp PR #30584 가 일부 연산을 GPU(Vulkan) 대신 CPU 로 보내기 때문이며 b11539 에서는 84.7 / 2008 이었다. 주로 쓰면 b11539 가 안전하다. 실전 과제 미실시 |
| `bolt` | NVIDIA Nemotron 3.5 Bolt 74B-A9B 24GB (2비트 QAT, DFlash) | NVIDIA (2026-10-07) | 74B · 9B | 22.0GB (+mmproj 1.7GB, 초안 1.0GB) | 28.8G | Mamba-2+Transformer LatentMoE, 도구 호출·터미널 학습, 이미지·영상 입력. 생성 54 t/s(생각 끔, 서버 기본. 켜면 46 t/s 에 추론 약 1.25만 자). **llama.cpp b11701 이상 필요**. variant fast/think. 실전 과제 미실시 |
| `lfm` | LFM2.5-24B-A2B (Q8_0) | Liquid AI (2026-10-09) | 24B · 2B | 25.5GB | 25.4G | 하이브리드 MoE, 에이전트 도구 사용 중심 학습. 생성 75 t/s, 읽기 1834 t/s 로 빠르나 생각이 기본으로 켜져(약 1.34만 자) 첫 응답이 길다. 실전 과제 미실시 |
| `fn` | Qwen3.8-Flash-Next Coder 가지치기 (IQ1_M) | Qwen (2026-08-24) · ISTA-DASLab 압축 | 원본 125B · 6B (+51B n-gram 임베딩, 4B MTP) 중 전문가 절반 제거 | 58.4GB | 30.2G (+28.8GB mmap) | 1.89비트. 표준 시험 0/2회(`Array(n).map` 빈 배열 버그) - 실험용. 원본 라이선스 주의 |
| `ff` | Qwen3.8-Flash-Next 전체판 (IQ3_XXS) | Qwen (2026-08-24) · ISTA-DASLab 압축 | 125B · 6B (+51B n-gram 임베딩, 4B MTP) | 75.8GB | 46.5G (+28.8GB mmap) | 표준 시험 2/2회 통과(`fn` 은 0/2회). RAM 여유가 가장 빠듯하다(첫 측정 중 최저 11.6G). 비교용. 원본 라이선스 주의 |
| `q38` | Qwen3.8-27B (UD-Q6_K, MTP) | Qwen (2026-08-05) | 27B · 27B (dense) | 22.0GB | 27.7G | 생각 모델(서버에서 끔). 생성 25 t/s, 읽기 301 t/s 로 느리다. 비교용 |
| `aw` | Qwen-AgentWorld-35B-A3B (UD-Q6_K) | Qwen (2026-06-22) | 35B · 3B | 29.3GB | 28.9G | **세계 모델 — 코딩 에이전트용 아님**. 비교용 |
| `c7` | Qwen2.5-Coder-7B-Instruct (Q8_0) | Qwen (2024-09-17) | 7B · 7B (dense) | 8.1GB | 9.6G | 옛 세대 기준선, 직접 변환, 문맥 32K. 표준 시험 2/2회 통과 |
| `c7r` | c7 + React LoRA 「r4mlp」 | 직접 학습 (2026-06-27), 베이스는 Qwen | 7B · 7B + LoRA | 8.1GB (+어댑터 80MB) | 9.6G | 직접 학습한 LoRA 를 붙이는 예시 - 어댑터 파일은 비공개. 문맥 32K. 표준 시험 1/2회 |
| `c1` | Qwen2.5-Coder-1.5B-Instruct (F16) | Qwen (2024-09-18) | 1.5B · 1.5B (dense) | 3.1GB | 4.3G | 속도 기준선: 읽기 3057 t/s 로 가장 빠르나 표준 시험 0/2회. 직접 변환, 문맥 32K |
| `mcv` | MiniCPM-V 4.7 35B-A3B (Q6_K, 비전) | OpenBMB (2026-10-06) | 35B · 3B | 28.5GB (+mmproj 1.1GB, 초안 0.42GB) | 32.2G | 시리즈 첫 MoE, 이미지·영상 이해 특화. DSpark 로 생성 90 t/s(수락 75%), 읽기 1052 t/s. **llama.cpp b11701 이상 필요**. 실전 과제 미실시 |

- 공개일은 제작사의 첫 Hugging Face 저장소 생성일 기준이다. 생성 속도와 GTT 는 표준 시험(2026-10-17, llama.cpp b11701, 같은 하네스 · GPU · 단독 실행)의 값이다. 표준 시험의 채점은 확률적이라 통과 횟수로 적었고(표본 2~3회), 평가는 직접 플레이해 본 판정이며 n=1이다.
- 서버 엔진을 b11539 에서 b11701 로 올렸다(`bolt` 와 `mcv` 가 필요로 한다). 같은 모델의 속도는 두 엔진에서 거의 같았지만 `mel` 만 4~5배 느려졌다. 원인은 llama.cpp PR #30584(Mellum 정밀도 처리)로 밝혀졌다 - 퍼플렉서티는 두 엔진에서 같아서 이 서버에서는 속도만 잃는다([엔진 비교와 원인](docs/benchmarks.md#mel-이-b11701-에서-45배-느려진-이유)). `mel` 을 주로 쓰면 b11539 가 안전하고, `bolt`·`mcv` 를 쓰려면 b11701 이어야 한다(엔진은 router 단위).
- 함수 벤치(테트리스 함수 6문제)는 거의 모두 6/6 이라 모델 차이가 보이지 않았다 - 차이는 끝까지 만든 결과물을 사람이 돌려 볼 때 드러났다.

전체 제원·sha256·router 설정은 [docs/models.md](docs/models.md), 시험 방법과 결과는 [docs/benchmarks.md](docs/benchmarks.md).

## opencode 에서 모델 고르기

```text
opencode -m halo/q36              # 시작할 때 모델 지정 (설정의 기본값은 halo/cn)
opencode --auto -m halo/q36       # 자동 승인: deny 가 아닌 권한을 전부 승인 - 신뢰하는 폴더에서만
opencode models halo              # 쓸 수 있는 모델 목록
```

- 세션 안에서는 `/models` 로 바꾼다. 바뀐 모델은 **그 세션에서만** 유효하고, 다시 시작하면 `-m` > 설정 기본값 > 최근 사용 순으로 정해진다. 최근에 쓴 모델은 목록 맨 위 「Recent」 칸에 따로 나온다.
- 모델을 바꾼 첫 응답은 서버가 모델을 교체하는 시간(대체로 17~30초, 큰 모델은 80초 안팎)이 더해진다.
- **Glimmer(`mg`) 생각 강도**: 세션 안에서 `Ctrl+T` 또는 `Ctrl+P` -> 「Switch model variant」 -> `low` / `xhigh`. 모델을 다시 올리지 않는다.
- **Bolt(`bolt`) 생각 켜기**: 같은 방법으로 `fast`(생각 끔, 기본) / `think`(켬). 표준 시험에서 끔은 첫 응답 24.0초 · 53.7 t/s, 켬은 추론 약 1.25만 자가 붙어 103.5초 · 46.3 t/s 였다.
- 바탕화면 `opencode-local.bat` 는 작업 폴더에서 opencode 를 실행한다. 인자가 그대로 넘어간다: `opencode-local.bat --auto -m halo/q36`.

## 문서

| 문서 | 내용 |
|---|---|
| [docs/models.md](docs/models.md) | 모델 카탈로그: 제원, 라이선스, sha256, router 설정, 속도, 평가, 제외한 모델 |
| [docs/benchmarks.md](docs/benchmarks.md) | 표준 시험, 함수 벤치, 실전 과제(테트리스·갤러그), 순위와 교훈 |
| [docs/server.md](docs/server.md) | router 모드, `llm-router.sh`, 프리셋 INI, 새 모델 추가, 로그, GPU 확인, 방화벽 |
| [docs/hardware.md](docs/hardware.md) | 서버 사양, 메모리 예산(GTT), 필요한 OS 설정, 규모 가이드 |
| [docs/troubleshooting.md](docs/troubleshooting.md) | 실제로 겪은 함정과 해결 |
| [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) | opencode · llama.cpp · 모델 라이선스 고지 |

## 레포 구성

```text
README.md
THIRD_PARTY_NOTICES.md
docs/                      models.md  benchmarks.md  server.md  hardware.md  troubleshooting.md
server/
  llm-router.sh            router 서버 시작/중지/상태
  llm-presets.ini          모델 목록과 옵션 (경로는 이 서버 기준 - 자기 환경에 맞게 수정)
  models.tsv               모델 파일의 출처·크기·sha256
  llm-allow.sh             방화벽에서 PC 한 대(IP)만 열기
  lid-ac-ignore.sh         전원 연결 시 덮개를 닫아도 절전 안 함
client/windows/install.ps1 Windows 설치 스크립트 (opencode 설치 + 서버 연결)
```

## 주의

- API 키는 이 레포 어디에도 없다. 키를 레포·메모·로그에 평문으로 남기지 않는다.
- 설치 스크립트는 키를 Windows 사용자 환경변수 `LLM_KEY` 에 저장한다 - 레지스트리에 평문으로 남는다. 공용 PC 에서는 쓰지 말고, 쓴 뒤에는 지운다([지우는 법](docs/troubleshooting.md#설치-스크립트가-접속에-실패하거나-키를-거부한다)).
- opencode 는 기본으로 외부 제공자가 켜져 있어 코드가 밖으로 나갈 수 있다. 설치 스크립트는 `halo` 만 켠다 - 직접 설정을 바꿀 때 주의.
- 이 구성은 집/사무실의 신뢰하는 LAN 을 전제로 한다. 서버를 인터넷에 직접 공개하지 않는다.
