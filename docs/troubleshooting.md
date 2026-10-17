# 문제 해결

실제로 겪은 함정 위주. 증상 -> 원인 -> 해결 순서. 서버 쪽은 [server.md](server.md), 사양은 [hardware.md](hardware.md).

목차: [GPU 를 못 씀](#재부팅-후-gpu-를-못-쓰고-cpu-로-돈다) · [재부팅 후 서버 없음](#재부팅-후-서버가-안-떠-있다) · [IP 변경](#망이-바뀌어-접속이-안-된다) · [설치 중 접속/키 오류](#설치-스크립트가-접속에-실패하거나-키를-거부한다) · [붙여넣기 잘림](#긴-설치-명령을-원격-터미널에-붙여넣으면-잘린다) · [/models 목록](#models-창에-모델이-일부만-보인다) · [시작 모델 우선순위](#opencode-시작-모델의-우선순위) · [opencode run 멈춤](#opencode-run-이-멈춘다) · [외부 제공자](#외부-제공자가-켜져-있어-코드가-밖으로-나간다) · [승인 없이 실행](#opencode-가-수정과-명령을-승인-없이-실행한다) · [다운로드](#모델-다운로드-크기가-맞아도-끝난-게-아니다) · [NTFS](#ntfs-에-둔-빌드가-안-뜬다) · [새 모델 로드 실패](#새-모델이-로드되지-않는다-llamacpp-빌드가-모델보다-오래됨) · [엔진 올린 뒤 느려짐](#엔진을-올린-뒤-특정-모델만-느려졌다) · [옵션 이름](#옵션-이름이-바뀌었다-no-mmap) · [MTP](#mtp-가-켜지지-않는다) · [fn 반복](#fn-flash-next-반복과-샘플링) · [32K 모델](#문맥이-32k-인-모델에서-문맥-초과-오류가-난다) · [서브에이전트](#동시-서브에이전트로-느려진다) · [Windows 스크립트](#windows-스크립트-작성-주의)

## 재부팅 후 GPU 를 못 쓰고 CPU 로 돈다

- **증상**: 모델은 `loaded` 인데 `status` 의 **GTT 가 0.0G**, 생성 3.5 t/s · 읽기 113 t/s (정상이면 `cn` 49 · 700). 에러도 경고도 없다.
- **원인**: `/dev/dri/renderD128` 접근 권한이 logind ACL 로 「그 seat 앞에 로그인한 사용자」에게만 붙는다. 재부팅 후 아무도 데스크톱에 로그인하지 않으면 seat 에는 로그인 화면(greeter)만 있고, 서버를 띄운 사용자는 `render`/`video` 그룹이 아니어서 GPU 장치를 열지 못한다. 전날에는 누군가 데스크톱에 로그인해 있어서 드러나지 않았다.
- **해결**:
  ```bash
  sudo usermod -aG render,video <사용자>                                   # 영구 (재로그인/재부팅 후 적용)
  sudo setfacl -m u:<사용자>:rw /dev/dri/renderD128 /dev/dri/card1         # 즉시 적용 (카드 번호는 ls /dev/dri 로 확인)
  ~/llm-router.sh start                                                    # 서버 재시작
  ```
- **예방**: 서버를 켠 뒤 **항상 `status` 의 GTT 를 본다**(`cn` 47G · `q36`/`orn`/`fn` 30G · `mg` 22G · `mel` 13G).

## 재부팅 후 서버가 안 떠 있다

- **증상**: 재부팅(또는 전원 차단) 뒤 클라이언트가 접속하지 못한다. 서버에서 `status` 는 「꺼짐」.
- **원인**: router 는 사용자 유닛으로 띄운 것이라 부팅 때 자동으로 시작되지 않는다.
- **해결**: `~/llm-router.sh start` 후 GTT 확인(위 항목). 자동 시작이 필요하면 `systemd --user` 유닛과 로그인 없이 유지하는 설정(linger) 같은 별도 구성이 필요할 수 있다 - 이 레포는 제공하지 않고 시험하지도 않았다.
- 덮개를 닫아 절전에 들어갔다면 [덮개 설정](server.md#덮개를-닫아도-계속-돌게-노트북-서버).

## 망이 바뀌어 접속이 안 된다

- **증상**: 어제까지 되던 PC 가 접속하지 못하거나, 서버를 다른 망에 옮긴 뒤 클라이언트가 옛 주소로 간다.
- **원인**: 서버 주소는 어느 망에 붙었느냐에 따라 바뀐다(유선·무선이 둘 다 있으면 주소가 둘). 방화벽 허용도 PC 의 IP 마다 따로다.
- **해결**:
  1. 서버에서 새 주소 확인: `~/llm-router.sh status` (마지막 줄) 또는 `hostname -I`.
  2. 클라이언트: 설치 스크립트를 다시 실행하고 새 주소를 입력한다(키·opencode 는 그대로 쓰고 설정만 다시 쓴다). 손으로 고치려면 `opencode.json` 의 `baseURL` 과 사용자 환경변수 `LLM_URL` 을 바꾼다.
  3. 새 망에서 접속하는 PC 의 IP 를 `~/llm-allow.sh <PC IP>` 로 연다.

## 설치 스크립트가 접속에 실패하거나 키를 거부한다

- `Cannot connect to ... from this PC`: 스크립트가 보여 주는 「This PC's address」를 서버에서 `~/llm-allow.sh <그 IP>` 로 허용한 뒤 같은 명령을 다시 실행한다. 그래도 안 되면 서버가 켜져 있는지(`status`), 같은 망인지, 입력한 주소가 맞는지(Wi-Fi 공유기의 기기 간 격리 포함)를 본다.
- `The server rejected the API key (HTTP 401)`: 키가 틀렸다. 최대 3번 다시 묻는다. 서버에서 키를 확인해 안전한 경로로 전달받는다(채팅·레포에 붙이지 않는다).
- `The server answered HTTP 404`: 그 주소는 LLM 서버가 아니다(포트 확인).
- 저장된 값 지우기(PowerShell): `[Environment]::SetEnvironmentVariable('LLM_KEY',$null,'User')` / `'LLM_URL'`.

## 긴 설치 명령을 원격 터미널에 붙여넣으면 잘린다

- **증상**: 원격 터미널·원격 제어 창에 긴 스크립트를 통째로 붙여넣으면 중간에서 잘리거나 줄이 섞여 파싱 오류가 난다.
- **해결**: 긴 스크립트를 붙여넣지 말고 **한 줄 설치**를 쓴다: `irm https://raw.githubusercontent.com/genishs/localllm/main/client/windows/install.ps1 | iex`.

## /models 창에 모델이 일부만 보인다

- **증상**: opencode `/models` 에서 `halo` 칸에 모델이 두세 개뿐이다.
- **원인**: 정상이다. 즐겨찾기와 **최근 사용(Recent)** 모델은 맨 위 칸에 따로 나오고 제공자 칸에서는 빠진다. 지금 쓰는 `cn` 이 Recent 로 올라가 `halo` 칸에는 나머지만 보인 것이다.
- **확인**: `opencode models halo` 또는 `/models` 의 검색창.

## opencode 시작 모델의 우선순위

- 시작 모델은 `-m` 옵션 > 설정 파일의 `model` > Recent 순이다.
- `/models` 로 바꾼 모델은 **그 세션에서만** 유효하다. 껐다 켜면 설정 기본(`cn`, 없으면 목록의 첫 모델)으로 돌아간다.
- 실험·비교할 때는 **매번 `-m` 을 명시**한다: `opencode --auto -m halo/q36`. (`--auto` 로 다시 시작하다 모델이 기본으로 바뀌어 비교가 섞인 적이 있다 - 서버 로그의 모델 교체 기록으로 발견했다. [로그](server.md#로그))
- Glimmer(`mg`)의 생각 강도는 모델이 아니라 variant 다: `Ctrl+T` 또는 `Ctrl+P` -> 「Switch model variant」 -> `low` / `xhigh`. variant 만 바꾸면 모델을 다시 올리지 않는다. opencode 는 모델별 마지막 variant 를 기억한다.
- 제목 생성용 `small_model` 을 다른 모델로 두면 제목을 만들 때마다 모델 교체가 일어나므로 비워 둔다(설치 스크립트는 설정하지 않는다).

## opencode run 이 멈춘다

- **증상**(Linux 에서 확인): 스크립트·비대화 환경에서 `opencode run ...` 이 조용히 무한 대기한다(서버에 요청이 0건).
- **원인**: stdin 이 터미널(tty)이 아니면 입력을 기다린다.
- **해결**: `opencode run ... </dev/null`. (Windows 에서의 동작은 확인하지 않았다.)

## 외부 제공자가 켜져 있어 코드가 밖으로 나간다

- **문제**: opencode 는 기본으로 외부 제공자(내장 무료 모델 포함)가 살아 있다. 이 상태로 쓰면 프롬프트와 코드가 외부 서비스로 나갈 수 있다.
- **대책**: 설치 스크립트는 설정에 `"enabled_providers": ["halo"]`(v1.18.35 스키마: 지정하면 **그 제공자만** 켜진다)와 `"share": "disabled"` 를 쓴다.
- **확인**: `opencode models` 에 `halo/...` 만 나와야 한다. (이 설정을 뺀 대조군에서는 내장 `opencode/...` 모델이 함께 나왔다.)
- 외부 모델을 일부러 써야 한다면 그 제공자를 `enabled_providers` 에 추가한다 - 그 모델에는 프롬프트가 외부로 나간다는 뜻이다.

## opencode 가 수정과 명령을 승인 없이 실행한다

- opencode 의 기본값은 모든 수정·명령을 승인 없이 허용하는 것이다. 설치 스크립트는 설정에 `permission: {edit: ask, bash: ask}` 를 쓰고, 이미 `permission` 이 있으면 그대로 둔다.
- `opencode --auto` 는 「deny 가 아닌 권한을 전부 자동 승인」한다. 위 설정은 `ask` 뿐이라 `--auto` 를 쓰면 전부 풀린다 - 신뢰하는 작업 폴더에서만 쓴다.

## 업데이트 안내가 뜨거나 업데이트가 실패할 때

- **증상**: opencode 를 켜면 새 버전이 있다는 안내가 뜨고, 업데이트를 시도하면(`opencode upgrade`, 또는 「Install anyways?」에 Yes) 실패한다 - `Unknown installation method: unknown`.
- **원인**: 설치 스크립트는 패키지 관리자(npm·brew·scoop 등)가 아니라 GitHub 릴리스 zip 을 `%LOCALAPPDATA%\Programs\opencode` 에 풀어 설치한다. opencode 는 실행 파일 위치와 패키지 관리자의 설치 목록으로 설치 방식을 알아내는데(v1.18.35 바이너리의 코드로 확인) 이 경우는 어디에도 해당하지 않아 `unknown` 이 되고, `unknown` 은 업데이트 방법이 없다. 그래도 시작할 때마다 GitHub 에서 최신 버전을 조회해, 새 버전이 마이너 이상으로 다르면 안내를 띄운다(v1.18.35 에 대해 v1.19.x 가 나온 시점부터 보인다).
- **대책**: 설치 스크립트가 업데이트 확인 자체를 끈다. 두 곳에 쓴다.
  - `opencode.json` 에 `"autoupdate": false`. 스키마가 받는 값은 `true` / `false` / `"notify"` 이고 `false` 면 확인을 건너뛴다.
  - 사용자 환경변수 `OPENCODE_DISABLE_AUTOUPDATE=true` (값은 `true` 또는 `1` 만 인식한다). 설정 파일의 `autoupdate` 는 전역 설정 폴더(`%USERPROFILE%\.config\opencode\`)의 파일에서만 읽히고, `OPENCODE_CONFIG` 로 다른 곳의 파일을 가리키면 거기 적힌 값은 무시된다. 환경변수는 설정 파일 위치와 상관없이 듣는다.
  - 바탕화면 `opencode-local.bat` 는 고치지 않았다. `LLM_KEY`·`OPENCODE_CONFIG` 도 사용자 환경변수로 받으므로 같은 방식이다.
- **이미 설치한 PC**: 설치 스크립트를 한 번 더 실행하고(키·주소는 기억돼 있다) 열려 있는 opencode 를 다시 시작한다. 기존 설정의 다른 키는 그대로 두고 `autoupdate` 만 더하며, 바꾸기 전 파일은 `.bak-날짜` 로 남는다. 손으로 하려면: opencode.json 에 `"autoupdate": false` 를 더하고 PowerShell 에서 `[Environment]::SetEnvironmentVariable('OPENCODE_DISABLE_AUTOUPDATE','true','User')` 후 새 터미널을 연다.
- **확인한 것과 못 한 것**: Linux 용 v1.18.35 로 TUI 를 띄워 `api.github.com` 으로 나가는 연결을 세었다. 기본 설정은 연결이 나가고, `autoupdate: false`(전역 설정) 또는 `OPENCODE_DISABLE_AUTOUPDATE` 중 하나만 있어도 나가지 않았다. `OPENCODE_CONFIG` 로 다른 폴더의 파일에 `autoupdate: false` 만 둔 경우는 연결이 나갔다. Windows 에서 같은 시험은 하지 않았다(같은 코드 경로로 읽힌다).
- **버전을 올리고 싶을 때**: 이 구성은 서버와 검증한 v1.18.35 로 고정이다. 올리려면 `client/windows/install.ps1` 의 두 값을 고친다.
  1. 올릴 릴리스를 정한다: https://github.com/anomalyco/opencode/releases
  2. `$Ver = "v1.18.35"` 를 그 태그로 바꾼다.
  3. `$Sha` 의 두 항목(`opencode-windows-x64.zip`, `opencode-windows-x64-baseline.zip`)을 그 릴리스의 sha256 으로 바꾼다. 값은 릴리스 자산의 digest(`https://api.github.com/repos/anomalyco/opencode/releases/tags/<태그>` 의 `assets[].digest`)에서 얻고, zip 을 받아 `Get-FileHash <zip> -Algorithm SHA256` 로 직접 계산한 값과 같은지 대조한다.
  4. 이 레포의 설정(`enabled_providers` · `permission` · `autoupdate` 등)은 v1.18.35 스키마로 확인한 것이다. 새 버전에서 키 이름이 바뀌었는지 보고, 서버와 붙는지 시험한 뒤 올린다.
  5. `v1.18.35` 를 쓴 문서(`README.md`, `docs/hardware.md`, `THIRD_PARTY_NOTICES.md`, 이 문서)도 함께 고친다: `grep -rn 1.18.35 .`
  6. 설치 스크립트를 다시 실행하면 `$Ver` 와 다른 버전이 설치돼 있는 PC 는 새 버전으로 교체된다(「found a different or broken opencode」).
- **하지 말 것**: `opencode upgrade` 는 이 설치에서 실패하고, `--method` 로 방식을 강제하면 설치 스크립트가 만든 것과 다른 위치에 별도 복사본이 생길 수 있다.
- 업데이트 확인을 다시 켜고 싶다면 환경변수를 지우고 `autoupdate` 를 고친다. 단 설치 스크립트를 다시 실행하면 이 값은 또 꺼진다(스크립트가 관리하는 키다).

## 모델 다운로드: 크기가 맞아도 끝난 게 아니다

- 병렬 Range 다운로더 중에는 **파일을 최종 크기로 미리 잡아 두는** 것이 있다. 크기만 보면 시작하자마자 「다 받았다」로 보인다(3분에 끝났다고 오판했으나 실제는 20분).
- **완료 판정은 프로세스(유닛) 종료 + `sha256sum` 대조**로 한다. Hugging Face 가 공개한 값은 [server.md](server.md#새-모델-추가-체크리스트) 3번.
- 다운로드 속도는 저장소(CDN 캐시)마다 다르다 - 같은 시각에 어떤 저장소는 2.3MB/s, 다른 저장소는 10~13MB/s 였다. 8연결 병렬 받기로 18.7MB/s 까지 나왔다.

## NTFS 에 둔 빌드가 안 뜬다

- **증상**: `llama-server` 가 「file too short」 같은 오류로 시작하지 않는다.
- **원인**: NTFS 로 옮긴 llama.cpp 빌드의 `.so` 심볼릭 링크가 42바이트짜리 텍스트 파일로 바뀐다.
- **해결**: 바이너리는 **ext4**(예: 홈 디렉터리)에 둔다. (모델 파일은 NTFS 에 있어도 된다.)

## 새 모델이 로드되지 않는다: llama.cpp 빌드가 모델보다 오래됨

- **증상**: router 에서 새 모델을 요청해도 `loaded` 가 되지 않고 오류로 끝난다. 서버 로그(자식 서버 `[포트]` 줄)에 `check_tensor_dims: blk.1.ffn_gate_inp.weight has wrong shape` 가 있다. Nemotron 3.5 Bolt 를 b11539 로 읽을 때 실제로 이 오류가 났다(층마다 전문가 수가 달라 텐서 모양이 맞지 않았다). 이미지 입력용 mmproj(C-RADIO)도 읽지 못했다.
- **원인**: 새 구조의 모델은 llama.cpp 가 그 구조를 구현한 뒤에야 읽힌다. Bolt 는 PR #30520(2026-10-15 병합), MiniCPM-V 4.7 은 PR #29416(2026-10-10 병합)이 필요한데, 당시 서버가 쓰던 b11539(2026-10-09)에는 둘 다 없었다. **파일이 깨진 것이 아니다** - sha256 이 맞아도 난다.
- **해결**:
  1. 모델 카드의 지원 버전과 llama.cpp 의 커밋·PR 병합일을 확인한다.
  2. 그 PR 이 들어간 공식 사전빌드로 올린다. 이 서버는 b11701(2026-10-16)을 쓴다 - 받는 법과 sha256 은 [server.md](server.md#1-처음-세우는-순서) 2번. 이전 빌드 폴더는 지우지 않고 둔다.
  3. `llm-router.sh` 의 기본 경로(`LLAMA_BIN`)가 새 폴더를 가리키는지 확인하고 `start` 한 뒤 `status` 로 GTT 를 본다.
  4. 되돌리려면 `LLAMA_BIN=$HOME/llama.cpp-bin/b11539/llama-b11539 ~/llm-router.sh start` (그러면 `bolt` 와 `mcv` 는 다시 못 쓴다).
- **엔진을 올린 뒤**: 기존 모델의 속도와 결과가 달라질 수 있다. 표준 시험을 다시 돌려 비교한다([benchmarks.md](benchmarks.md#1-표준-시험-2026-10-17)). 실제로 b11701 로 올린 뒤 한 모델(`mel`)이 느려졌다 - 아래 항목.

## 엔진을 올린 뒤 특정 모델만 느려졌다

엔진을 올렸더니 특정 모델만 4~5배 느려졌다 -> 그 모델 관련 PR 을 확인한다(정확도 수정이 GPU 가 지원하지 않는 연산을 CPU 로 보내는 경우가 있다) -> perplexity 로 옛 빌드에 정말 문제가 있었는지 재 본다.

- **증상**: llama.cpp 를 b11539 에서 b11701 로 올린 뒤 `mel`(Mellum2.1) 한 모델만 생성이 84.7 -> 17.9 t/s, 긴 프롬프트 읽기가 2008 -> 524 t/s 로 떨어졌다. 같은 파일이고 GTT 도 그대로(13.3G -> 13.4G)이며 오류도 없다. 나머지 12종은 두 엔진에서 거의 같은 속도였고, `mel` 의 느려짐은 b11701 에서 두 번 재현됐다([비교표](benchmarks.md#엔진-비교-b11539-대-b11701)).
- **원인**: llama.cpp PR #30584(2026-10-16 병합, 「graph : add precision handling for MELLUM architecture」). Mellum 의 `ffn_moe_down` 입력이 F16 한계(65504)를 넘어 Metal 에서 NaN 이 나서, 그 연산에 `GGML_PREC_F32` 를 지정했다. 그런데 Vulkan 등 GPU 백엔드는 이 설정의 `MUL_MAT_ID` 를 `supports_op` 에서 거부하므로 **모든 층의 `ffn_moe_down` 이 CPU 에서 돈다.** b11539 는 이 PR 이전 빌드, b11701 은 이후 빌드다.
- **진단 순서**:
  1. 느려진 모델의 구조 이름으로 llama.cpp 의 최근 PR·이슈를 찾는다(예: `MELLUM`). 정밀도(`PREC_F32`)·그래프 수정은 속도가 아니라 정확도를 고치는 변경이라, 지원하지 않는 백엔드에서는 CPU 로 빠져 느려질 수 있다.
  2. 옛 빌드에 정확도 문제가 실제로 있는지 perplexity 로 재 본다. 같은 파일로 두 빌드에서 `llama-perplexity -m <파일> -c 2048 --chunks 8 -ngl 999` 를 돌려 NaN 이 나오는지, 값이 같은지, 한 번(pass)당 시간이 얼마나 다른지 본다. `mel` 은 b11539 6.0967 ± 0.177 (0.94초) 대 b11701 6.1049 ± 0.177 (3.39초) 로 값이 같고 NaN 도 없었다 - 이 서버에서는 새 빌드가 정확도 이득 없이 속도만 잃는다.
  3. 직접 생성 속도도 재 본다(`mel` 은 b11539 81.7 t/s 대 b11701 17.5 t/s).
- **대처**: 그 모델을 주로 쓰면 옛 빌드가 안전하다 - `LLAMA_BIN=$HOME/llama.cpp-bin/b11539/llama-b11539 ~/llm-router.sh start`. 단 엔진은 router 단위라 새 빌드가 필요한 `bolt`·`mcv` 는 못 쓴다. 이 서버는 `bolt`·`mcv` 때문에 b11701 을 기본으로 두었고, 비교 시험(콘테스트)에서는 `mel` 만 b11539 로 돌린다. 또는 상류에서 해당 백엔드(Vulkan)용 수정이 나오기를 기다린다. 이전 빌드 폴더는 지우지 않고 둔다.
- **일반 규칙**: 엔진을 올린 뒤에는 쓰는 모델마다 속도를 다시 잰다(표준 시험, 또는 짧은 요청 하나의 로그 `tokens per second`). 오류가 없어서 재 보지 않으면 모른다.

## 옵션 이름이 바뀌었다: no-mmap

- llama.cpp 최신 빌드에서 `--no-mmap` 은 **`--load-mode none`** 이 되었다. 옛 이름은 invalid argument 로 거부된다. 프리셋 INI 에서는 `load-mode = none`.
- 변환 스크립트도 바뀌어 `convert_hf_to_gguf.py` 가 얇은 껍데기가 되었다(`conversion/*.py` 로 분리). 이 파일만 grep 해 「미지원」으로 오판하지 않는다.
- 옵션 존재 여부는 쓰는 빌드의 `llama-server --help` 로 확인한다.

## MTP 가 켜지지 않는다

- `spec-type = draft-mtp` 는 GGUF 파일에 `nextn` 층이 있어야 한다. 확인: `head -c 32M <파일> | grep -ac nextn`.
- unsloth 의 일반 GGUF 저장소는 MTP 층을 **뺀다**. Qwen3.6 은 `unsloth/...-MTP-GGUF` 저장소를 따로 받아야 한다.
- 생각을 켜면 MTP 수락률이 60%대로 떨어져 속도 이득이 줄어든다.

## fn (Flash-Next) 반복과 샘플링

- 가지치기·1.89비트판(`IQ1_M`)이라 샘플링에 민감하다. 처음(10-11)에는 생각을 켜면 14분 넘게 생각만 하다 0바이트, 생각을 끄고 `temp 0.2` 로 하면 「Malayalam」을 반복하며 붕괴했다.
- 지금 프리셋은 Qwen 비생각 권장 샘플링(`temp 0.7` · `top-p 0.8` · `top-k 20` · `min-p 0`)에 `presence-penalty 1.5` 를 더한 것이다. 반복 붕괴는 짧은 시험에서 나타나지 않았다.
- 그래도 코드의 `Array(n).map(...)` 빈 배열 버그가 두 번(10-11, 10-17) 재현됐고 표준 시험도 통과하지 못했다 -> 실험용으로만 쓴다([benchmarks.md](benchmarks.md#1-표준-시험-2026-10-17)). 같은 계열 전체판 `ff` 는 같은 샘플링에서 표준 시험을 통과했다.
- 메모리: 58.4GB 중 28.8GB 텐서 하나를 `override-tensor = per_layer_token_embd=CPU` + `load-mode = mmap` 으로 GPU 밖에 두고 mmap 으로 필요한 줄만 읽는다. 이 두 줄이 GPU 사용량을 약 30GB 로 줄인다. 전체판 `ff`(75.8GB)도 같은 방식이며 GTT 46.5G + mmap 으로 시험 중 남은 RAM 이 11.6G 까지 줄었다 - 다른 프로세스를 많이 띄운 상태에서는 쓰지 않는다.

## 문맥이 32K 인 모델에서 문맥 초과 오류가 난다

- **주의**: `c7` `c7r` `c1` 은 문맥이 32K 가 한계라 서버 프리셋도 `c = 32768` 로 잡는다. 클라이언트가 65536 으로 알고 있으면 32K 를 넘는 요청을 보내 긴 대화·큰 파일에서 문맥 초과 오류가 날 수 있다(예방 조치이며, 실제 사고를 겪은 것은 아니다).
- **해결**: 설치 스크립트는 이 별칭의 `limit.context` 를 32768 로 쓴다. 이 목록에 없는 32K 모델을 추가했다면 `opencode.json` 의 해당 모델 `limit.context` 를 직접 낮추고(`install.ps1` 의 `$Known` 표에 `context = 32768` 을 더하면 다시 실행해도 유지된다) 서버 섹션에는 `c = 32768` 을 쓴다.

## 동시 서브에이전트로 느려진다

- 서브에이전트(task 도구)는 에이전트에 model 지정이 없으면 **부른 쪽 모델을 물려받는다**. 서버 슬롯은 4개라 동시에 도는 서브에이전트가 생성 속도를 나눠 쓴다. dense 모델(`mg`)이 가장 크게 손해를 본다(평균 7.2 t/s 까지 관측).
- 프롬프트의 폴더 지시는 **절대 경로**로 쓴다. 상대 경로(「study 아래」)는 모델마다 다르게 풀려, 한 모델이 사용자 홈에 프로젝트를 만든 적이 있다.

## Windows 스크립트 작성 주의

이 레포의 `install.ps1` 을 고치거나 비슷한 스크립트를 만들 때.
- `.ps1` 은 **ASCII 만** 쓴다. BOM 없는 파일을 Windows PowerShell 5.1 은 ANSI 로 읽어 한글이 깨진다. `.bat` 의 한글은 CP949 로 읽힌다 - 설치 스크립트가 만드는 `.bat` 은 ASCII 로 유지한다(경로는 `%USERPROFILE%` 형태로).
- 설정 JSON 은 **문자열로 이어 붙이지 말고** `[ordered]@{}` 객체로 만들어 `ConvertTo-Json -Depth 30` 한다. 기존 `permission` 을 끼워 넣으려 문자열을 이어 붙이다 PowerShell 7 의 `ConvertFrom-Json` 이 실패한 적이 있다. 쓰기 전에 다시 파싱해 검증한다(설치 스크립트가 그렇게 한다).
- git 의 `eol=crlf` 는 체크아웃 때만 변환한다. `raw.githubusercontent.com` 은 저장소의 바이트를 그대로 준다. 그래서 `.ps1`/`.bat`/`.cmd` 는 `.gitattributes` 에서 `-text`(바이트 그대로 저장)로 둔다.
- 스크립트 안에서 `exit` 를 쓰면 `irm | iex` 로 실행했을 때 사용자의 PowerShell 창이 닫힌다. 설치 스크립트는 `& { ... }` 안에서 `return` 으로 끝낸다.
