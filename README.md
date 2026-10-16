# localllm

집에서 돌리는 **로컬 LLM 코딩 에이전트 구성**을 기록하고 설치까지 묶어 둔 레포.
AMD Strix Halo 리눅스 서버에서 llama.cpp 를 router 모드로 돌리고, Windows PC 에서 [opencode](https://github.com/anomalyco/opencode) 코딩 에이전트로 접속한다.

- 서버 설정(`server/`), Windows 설치 스크립트(`client/windows/`), 모델 카탈로그·벤치마크·운영·문제 해결 문서(`docs/`)로 이루어져 있다.
- 모든 수치는 직접 잰 값이다. 실전 과제는 모델당 1회(n=1)라 경향으로만 읽는다.
- 라이선스 미지정(추후 결정). 사용하는 제3자 소프트웨어와 모델의 라이선스는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## 구성

```
Windows PC                                   Strix Halo 서버
 opencode  --HTTP /v1 + API 키-->  :8080  llama-server (router 모드, llama.cpp b11539 / Vulkan)
 (provider "halo")                          └ 요청의 model 이름으로 모델 선택 (한 번에 1개, 교체 17~80초)
                                              cn | q36 | mg | orn | fn | mel | (bolt | lfm | mcv 추가 중)
```

- **서버**: llama.cpp b11539(공식 사전빌드, Vulkan 백엔드)의 router 모드. AMD Strix Halo / Radeon 8060S, 64GB 통합 메모리 중 56GB 를 GPU 공유 메모리(GTT)로 쓴다. 포트 8080, API 키 인증, 모델은 한 번에 하나만 올리고 요청의 `model` 이름에 따라 자동 교체한다.
- **클라이언트**: Windows PC 의 opencode v1.18.35. OpenAI 호환 제공자 `halo`(표시 이름 「Strix Halo LLM」)로 서버에 붙는다.
- 이 서버에서는 메모리 대역폭이 속도를 정한다 - 활성 파라미터가 작은 MoE 모델이 빠르고 dense 30B 는 느리다.

### 서버 사양 요약

| 항목 | 내용 |
|---|---|
| 기종 | ASUS TUF Gaming A14 (FA401EA) 노트북 |
| CPU / GPU | AMD Ryzen AI MAX+ 392 (12코어/24스레드) / 내장 Radeon 8060S (RDNA 3.5, gfx1151) |
| 메모리 | 64GB LPDDR5X 통합 메모리 (OS 인식 60.94GiB), 전용 VRAM 0.5GiB, GPU 공유 메모리(GTT) 56GiB |
| 저장장치 | NVMe 2TB (모델) + NVMe 1TB (OS) |
| OS / 실행기 | Ubuntu 26.04.1 LTS (커널 7.0) / llama.cpp b11539, Vulkan (Mesa 26.0.8 RADV) |
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
4. 서버의 모델 목록으로 opencode 설정 작성 - 외부 제공자 차단(`enabled_providers: ["halo"]`), 공유 끔, 기존 `permission` 유지(없으면 수정·명령 모두 `ask`), 기존 설정은 `.bak-날짜` 로 백업.
5. 작업 폴더 선택 + 바탕화면 실행 파일 `opencode-local.bat`.
6. 사용법 안내, 바로 시작할지 묻기.

인터넷에서 받은 스크립트를 바로 실행하는 방식이라, 먼저 읽어 보고 싶다면 파일로 저장해서 실행한다:

```powershell
irm https://raw.githubusercontent.com/genishs/localllm/main/client/windows/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File install.ps1
```

## 모델 요약

표준 시험(2026-10-17, 같은 하네스 · GPU · 단독 실행) 기준. 생성 = 답을 쓰는 속도. 평가는 직접 플레이해 본 판정이며 n=1.

| 별칭 | 모델 | 크기 | 생성 t/s | 한 줄 평가 |
|---|---|---|---|---|
| `cn` | Qwen3-Coder-Next 80B-A3B (Q4_K_M) | 48.7GB | 55.4 | 가장 빨리 끝나는 초안형(테트리스 4분). 핵심 규칙을 틀릴 수 있고 짚어 주면 고친다. 서버 기본 상주 모델 |
| `q36` | Qwen3.6-35B-A3B (UD-Q6_K, MTP) | 30.0GB | 89.7 | 빠른 기본 일꾼 후보. 테트리스 5/5, 큰 과제(갤러그)에서는 시작 직후 멈춤 |
| `mg` | Muse Glimmer 30B (Q4_K_XL, DFlash) | 19.7GB | 25.3 | 느리지만 테트리스·갤러그 모두 완성도 1위. 시간이 걸려도 돌아가는 결과물이 필요할 때 |
| `orn` | Ornith-1.5-35B-A3B (Q6_K, MTP) | 29.2GB | 87.3 | 팀 작업을 성실히 돌리나 갤러그에서 좌우 이동 불가. 표본 1회라 판단 보류 |
| `fn` | Qwen3.8-Flash-Next Coder 가지치기 (IQ1_M) | 58.4GB | 23.1 | 표준 시험 실패(`Array(n).map` 빈 배열 버그 재현). 실험용 |
| `mel` | Mellum2.1-12B-A2.5B Thinking (Q8_0) | 12.9GB | 84.7 | 읽기 2008 t/s · GTT 13G 로 가볍고 표준 시험 통과. 생각이 항상 켜짐. 실전 과제 미실시 |
| `bolt` | NVIDIA Nemotron 3.5 Bolt 74B-A9B (2비트 QAT) | 22.0GB | - | **추가 중 - 실측 전** |
| `lfm` | LFM2.5-24B-A2B (Q8_0) | 25.5GB | - | **추가 중 - 실측 전** |
| `mcv` | MiniCPM-V 4.7 35B-A3B (Q6_K, 비전) | 28.5GB | - | **추가 중 - 실측 전** |

함수 벤치(테트리스 함수 6문제)는 거의 모두 6/6 이라 모델 차이가 보이지 않았다 - 차이는 끝까지 만든 결과물을 사람이 돌려 볼 때 드러났다.
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
- opencode 는 기본으로 외부 제공자가 켜져 있어 코드가 밖으로 나갈 수 있다. 설치 스크립트는 `halo` 만 켠다 - 직접 설정을 바꿀 때 주의.
- 이 구성은 집/사무실의 신뢰하는 LAN 을 전제로 한다. 서버를 인터넷에 직접 공개하지 않는다.
