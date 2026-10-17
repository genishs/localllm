# 모델 카탈로그

서버(router)가 한 포트에서 골라 주는 모델 15종과, 받아 봤지만 쓰지 않는 모델의 사유.
수치는 서버 로그와 자체 시험 하네스에서 집계한 값이며, 실전 과제는 모델당 1회(n=1)다 - 경향으로만 읽는다.
자세한 시험 내용은 [benchmarks.md](benchmarks.md), 운영 방법은 [server.md](server.md), 라이선스는 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

- 별칭(alias) = router 에서 요청의 `model` 값 = opencode 에서 `halo/<별칭>`.
- 파일 크기 GB 는 10^9 바이트. sha256 은 앞 16자리(전체 값과 받는 주소는 [`server/models.tsv`](../server/models.tsv)).
- 「표준 시험」은 2026-10-17 같은 하네스로 router 에 있던 모델을 GPU 에서 한 번에 하나씩 돌린 값이다(방법: [benchmarks.md](benchmarks.md#1-표준-시험-2026-10-17)). 「첫 응답」은 첫 요청을 보내 답이 끝날 때까지의 시간(모델 교체 포함)이다. 채점은 확률적이라 **통과 횟수**(두 함수가 모두 맞은 실행 수 / 전체 실행 수)로 적는다.
- 공개일은 제작사의 첫 Hugging Face 저장소 생성일 기준이다(실제 발표일과 며칠 다를 수 있다). 변환 GGUF 저장소의 날짜는 따로 적는다.
- 엔진은 llama.cpp **b11701**. `bolt` 와 `mcv` 는 b11701 이상이 필요하다(해당 PR 이 b11539 보다 나중에 병합됐다). 표준 시험 값은 모두 b11701 에서 잰 것이다. 이전 엔진 b11539 에서 잰 값과의 비교, 그리고 `mel` 이 b11701 에서 느려진 현상은 [benchmarks.md](benchmarks.md#엔진-비교-b11539-대-b11701)에 있다.

## 한눈에 보기

| 별칭 | 모델 | 구조 | 양자화 · 크기 | 가속 | 생성 t/s* | 읽기 t/s* | GTT* | 상태 |
|---|---|---|---|---|---|---|---|---|
| `cn` | Qwen3-Coder-Next 80B-A3B | MoE 3B 활성, 코딩 전용 | Q4_K_M · 48.7GB | 없음 | 55.8 | 745 | 47.5G | 사용 중 (서버 기본 상주) |
| `q36` | Qwen3.6-35B-A3B | MoE 3B 활성, 범용 | UD-Q6_K · 30.0GB | MTP | 91.3 | 1001 | 30.7G | 사용 중 |
| `mg` | Muse Glimmer 30B | dense 30B, 에이전트용 | Q4_K_XL · 19.7GB (+초안 1.6GB) | DFlash | 25.7 | 331 | 22.7G | 사용 중 |
| `orn` | Ornith-1.5-35B-A3B | MoE 3B 활성, 추론 모델 | Q6_K · 29.2GB | MTP | 81.0 | 965 | 30.0G | 사용 중 |
| `mel` | Mellum2.1-12B-A2.5B Thinking | MoE 2.5B 활성, 생각 모델 | Q8_0 · 12.9GB | 없음 | 17.9 | 524 | 13.4G | 사용 중 (실전 과제 미실시, **b11701 에서 느려짐 - 조사 중**) |
| `fn` | Qwen3.8-Flash-Next Coder (가지치기) | MoE, 전문가 절반 제거 | IQ1_M · 58.4GB (2조각) | 없음 | 23.6 | 357 | 30.2G | 실험용 (표준 시험 0/2회) |
| `ff` | Qwen3.8-Flash-Next (전체판) | MoE 6B 활성 (원본 125B) | IQ3_XXS · 75.8GB (2조각) | 없음 | 24.3 | 315 | 46.5G | 비교용 |
| `q38` | Qwen3.8-27B | dense 27B, 생각 모델 | UD-Q6_K · 22.0GB | MTP | 25.3 | 301 | 27.7G | 비교용 |
| `aw` | Qwen-AgentWorld-35B-A3B | MoE 3B 활성, **세계 모델** | UD-Q6_K · 29.3GB | 없음 | 55.5 | 1046 | 28.9G | 비교용 (세계 모델 — 코딩 에이전트용 아님) |
| `c7` | Qwen2.5-Coder-7B-Instruct | dense 7B | Q8_0 · 8.1GB | 없음 | 28.9 | 1127 | 9.6G | 기준선 (문맥 32K) |
| `c7r` | c7 + React LoRA | dense 7B + LoRA | Q8_0 · 8.1GB (+어댑터 80MB) | 없음 | 27.8 | 931 | 9.6G | LoRA 예시 (어댑터 비공개) |
| `c1` | Qwen2.5-Coder-1.5B-Instruct | dense 1.5B | F16 · 3.1GB | 없음 | 68.6 | 3057 | 4.3G | 속도 기준선 (표준 시험 0/2회) |
| `bolt` | Nemotron 3.5 Bolt 74B-A9B | 혼합 LatentMoE 9B 활성 | 2비트 QAT · 22.0GB (+mmproj, 초안) | DFlash | 53.7 | 415 | 28.8G | 사용 중 (실전 과제 미실시, 엔진 b11701 이상) |
| `lfm` | LFM2.5-24B-A2B | 하이브리드 MoE 2B 활성 | Q8_0 · 25.5GB | 없음 | 75.2 | 1834 | 25.4G | 사용 중 (실전 과제 미실시, 생각이 기본 켜짐) |
| `mcv` | MiniCPM-V 4.7 35B-A3B | MoE 3B 활성, 비전 특화 | Q6_K · 28.5GB (+mmproj, 초안) | DSpark | - | - | - | **추가 중 — 실측 전** |

\* 표준 시험(2026-10-17, llama.cpp b11701) 값. 생성 = 답을 쓰는 속도, 읽기 = 긴 프롬프트(약 1만 토큰)를 읽는 속도, GTT = 올라간 모델이 쓰는 GPU 공유 메모리.
`mg` 는 생각 강도 low, `bolt` 는 생각 끔(서버 기본). 작업 중 평균은 이보다 낮을 수 있다(아래 각 모델의 「과거 실측」).

구분: 일반 사용 후보 `cn` `q36` `mg` `orn` `mel` `bolt` `lfm` / 실험·비교·기준선용 `fn` `ff` `q38` `aw` `c7` `c7r` `c1` (router 에 올라 있지만 일상 사용을 권하지 않는다) / 추가 중 `mcv`.

용어:
- **MoE / 활성 파라미터**: 전문가 여러 개 중 일부만 토큰마다 쓰는 구조. `A3B` = 활성 3B. 이 서버는 메모리 대역폭이 속도를 정하므로 활성이 작을수록 빠르다.
- **추측 디코딩**: 작은 초안(MTP 층 또는 별도 초안 모델)이 토큰 여러 개를 미리 제안하고 본 모델이 한 번에 검증한다. 수락률이 높을수록 빠르다. 코드를 길게 쓰는 구간에서는 수락률이 떨어진다.
  - `MTP`: 모델 파일에 `nextn` 층이 들어 있어야 한다(`spec-type = draft-mtp`). `DFlash`/`DSpark`: 별도 초안 모델 파일(`model-draft`).
- **GTT**: 통합 메모리 중 GPU 가 쓰는 공유 구간. 이 서버는 56GiB ([hardware.md](hardware.md)).

## 라우터 공통 설정 (`[*]`)

`n-gpu-layers = 999`(전부 GPU) · `flash-attn = on` · `jinja = true` · `c = 65536`(문맥 64K) · `load-mode = none`(통째로 메모리에 올림, 옛 `--no-mmap`).
모델 섹션이 같은 키를 쓰면 공통값을 덮어쓴다(예: `c7` `c7r` `c1` 은 `c = 32768`). 슬롯은 4개(기본)라 서브에이전트가 동시에 돌면 속도를 나눠 쓴다.

---

# 일반 사용 후보

## cn - Qwen3-Coder-Next 80B-A3B

| 항목 | 내용 |
|---|---|
| 만든 곳 / 변환 | Qwen / bartowski (GGUF) |
| 공개일 | 원본 2026-01-30 · GGUF 저장소 2026-02-03 |
| 라이선스 | Apache-2.0 |
| 구조 | MoE, 전체 80B 중 활성 3B, 코딩 전용, 생각 기능 없음 |
| 양자화 · 크기 · sha256 | Q4_K_M · 48.7GB (48,727,680,704 B) · `78f38fe85daaab51` |
| 출처 | https://huggingface.co/bartowski/Qwen_Qwen3-Coder-Next-GGUF |
| router 설정 | 공통값만. `load-on-startup = true`(서버가 켜지면 제일 먼저 올라가는 기본 모델). 추측 디코딩 없음 - 이 GGUF 에는 MTP 층이 없다(헤더 확인) |
| 표준 시험 | 첫 응답 33.4초 · 생성 55.8 t/s · 읽기 745 t/s · GTT 47.5G · 통과 2/2회 |
| 과거 실측 | 생성 45~49 t/s · 읽기 550~750 t/s (실전 과제 평균) |
| 평가 | 가장 빨리 끝나는 초안형. 테트리스 4분07초에 끝냈지만 보드 가로·세로 인자가 뒤바뀐 한 줄(`createMatrix(20, 12)`)로 줄이 안 지워졌다. 갤러그는 5분26초, 서브에이전트(페르소나)를 사실상 쓰지 않았다. 버그를 짚어 주면 바로 고친다. |

## q36 - Qwen3.6-35B-A3B

| 항목 | 내용 |
|---|---|
| 만든 곳 / 변환 | Qwen / unsloth (MTP 포함 GGUF) |
| 공개일 | 원본 2026-04-15 · GGUF 저장소 2026-05-11 |
| 라이선스 | Apache-2.0 |
| 구조 | MoE, 전체 35B 중 활성 3B, 범용 |
| 양자화 · 크기 · sha256 | UD-Q6_K · 30.0GB (30,011,242,784 B) · `49935b04ad883c2f` |
| 출처 | https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF |
| router 설정 | `spec-type = draft-mtp` · `chat-template-kwargs = {"enable_thinking":false}`(생각 끔). 샘플링은 모델 기본값. 주의: unsloth 의 일반 GGUF 저장소는 MTP 층을 뺀다 - 반드시 `-MTP-GGUF` 저장소 파일 |
| 표준 시험 | 첫 응답 22.1초 · 생성 91.3 t/s · 읽기 1001 t/s · GTT 30.7G · MTP 수락 85% · 통과 **1/2회** (b11701 재측정에서 clearLines 가 틀렸다. b11539 에서는 통과) |
| 과거 실측 | 생성 71~86 t/s · 읽기 680~900 t/s · MTP 수락 81~94% (생각 켜면 60%대로 떨어진다) |
| 평가 | 기본 일꾼 후보. 빠르고 함수 벤치 6/6, 테트리스 5분34초 5/5. 갤러그(큰 과제)에서는 시작 3초 뒤 멈추고, 지정한 폴더가 아닌 사용자 홈에 프로젝트를 만들었다. 표준 시험은 1/2회(재측정에서 clearLines 오답) - 한 번의 샘플로 단정하지 않는다. |

## mg - Muse Glimmer 30B

| 항목 | 내용 |
|---|---|
| 만든 곳 | Meta |
| 공개일 | 원본 2026-08-09 · GGUF 저장소 2026-08-09 |
| 라이선스 | Apache-2.0 |
| 구조 | dense 30B(활성 = 전체), 에이전트용 |
| 양자화 · 크기 · sha256 | KQuant-Dynamic Q4_K_XL · 19.7GB (19,653,960,832 B) · `ac7023d6a4c704eb` + DFlash 초안 Q4_K_M · 1.6GB (1,631,208,128 B) · `b2e808bf656086fe` |
| 출처 | https://huggingface.co/meta-models/Muse-Glimmer-30B-GGUF |
| router 설정 | `model-draft` = DFlash 초안 · `spec-type = draft-dflash` · `spec-draft-n-max = 6`(초안 길이 3≈6 > 10·16, 길면 수락률이 떨어져 오히려 느려진다). 생각 강도는 서버가 아니라 요청마다 정한다 - opencode variant `low`(기본)/`xhigh`가 `chat_template_kwargs.reasoning_strength` 로 실린다 |
| 표준 시험 | 첫 응답 65.5초 · 생성 25.7 t/s · 읽기 331 t/s · GTT 22.7G · DFlash 수락 45% · 생각 low(약 3.9천 자) · 통과 2/2회 |
| 과거 실측 | 생성 20~30 t/s · 읽기 190~310 t/s · DFlash 수락 75%(벤치) / 27~44%(실전). 서브에이전트가 동시에 돌면 평균 7 t/s 까지 떨어진 적이 있다(갤러그) |
| 평가 | 시간이 걸려도 돌아가는 결과물이 필요할 때. 테트리스(xhigh 18분14초)와 갤러그(low 14분41초) 모두 직접 플레이 판정에서 완성도 1위. 대신 실전 과제의 작업시간이 가장 길었다(생성 20~30 t/s, dense 라 대역폭 한계). 코드를 잘게 나눠 쓰고 고치기를 반복한다. |

## orn - Ornith-1.5-35B-A3B

| 항목 | 내용 |
|---|---|
| 만든 곳 | ornith-ai |
| 공개일 | 원본 2026-08-18 · GGUF 저장소 2026-08-18 |
| 라이선스 | MIT (카드에 Qwen3.5/Gemma4 기반이라고 적혀 있다 - 상속 조건은 원 모델 라이선스도 확인) |
| 구조 | MoE, 전체 35B 중 활성 3B, Qwen3.5/Gemma4 기반 자가개선 RL, 추론 모델(기본 생각 켬) |
| 양자화 · 크기 · sha256 | Q6_K · 29.2GB (29,208,731,392 B) · `15d4658bbfc9c603` |
| 출처 | https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B-GGUF |
| router 설정 | `spec-type = draft-mtp`(헤더에 `nextn` 층 확인) · 생각 끔 · `temp = 0.6`, `top-p = 0.95`, `top-k = 20`(모델 카드 권장) |
| 표준 시험 | 첫 응답 23.6초 · 생성 81.0 t/s · 읽기 965 t/s · GTT 30.0G · MTP 수락 63% · 통과 2/2회 |
| 과거 실측 | 생성 94 t/s(짧은 시험, MTP 87%) / 실전 평균 49 t/s(MTP 66%) · 읽기 600~630 t/s |
| 평가 | 팀(서브에이전트) 작업을 가장 성실히 돌린다(갤러그 126 요청). 그러나 갤러그 결과물은 좌우 이동이 안 되고 P(일시정지)가 풀리지 않아 진행 불가였다. 표본 1회라 판단 보류. 모델 카드의 벤치 점수(Terminal-Bench 2.1 67.8, SWE-bench Verified 79)는 생각을 켠 값이며 직접 검증하지 않았다. |

## mel - Mellum2.1-12B-A2.5B Thinking

| 항목 | 내용 |
|---|---|
| 만든 곳 | JetBrains |
| 공개일 | 원본 2026-09-20 · GGUF 저장소 2026-10-07 |
| 라이선스 | Apache-2.0 |
| 구조 | MoE, 전체 12B 중 활성 2.5B(64 전문가 중 8개), 코딩 에이전트용 생각 모델 |
| 양자화 · 크기 · sha256 | Q8_0 · 12.9GB (12,925,417,760 B) · `69e0ac02a16586c2` |
| 출처 | https://huggingface.co/JetBrains/Mellum2.1-12B-A2.5B-Thinking-GGUF |
| router 설정 | 추측 디코딩 없음 · 생각은 늘 켜짐(Thinking 판이라 끌 수 없다) · `temp = 0.6`, `top-p = 0.95`, `top-k = 20`(카드 권장) · 모델은 문맥 131K 를 지원하지만 서버는 64K |
| 표준 시험 | 첫 응답 87.9초 · 생성 **17.9 t/s** · 읽기 **524 t/s** · GTT 13.4G · 생각 약 4.0천 자 · 통과 3/3회 - **b11701 에서 느려짐(조사 중)**: b11539 에서는 84.7 t/s / 2008 t/s 였다. b11701 에서 두 번 재현됐다(17.9, 17.4 t/s). GTT 는 그대로다 |
| 평가 | 활성 2.5B 의 작은 생각 모델로, b11539 에서는 소형 기준선(`c7` `c7r` `c1`)을 빼면 읽기가 가장 빠르고(2008 t/s) 메모리를 가장 적게 썼다. **b11701 로 올린 뒤 생성 84.7 -> 17.9 t/s, 읽기 2008 -> 524 t/s 로 느려졌다**(같은 파일, GTT 13.3G -> 13.4G). 원인은 조사 중이다 - [benchmarks.md](benchmarks.md#엔진-비교-b11539-대-b11701). 생각이 항상 켜져 있어 답이 길어진다. 실전 과제(테트리스·갤러그)는 아직 하지 않았다. |

## bolt - NVIDIA Nemotron 3.5 Bolt 74B-A9B 24GB

| 항목 | 내용 |
|---|---|
| 만든 곳 | NVIDIA |
| 공개일 | 24GB GGUF 저장소 2026-10-07 (원본 BF16 저장소 2026-10-09, 초안 LiLiCorr 2026-10-12) |
| 라이선스 | OpenMDW-1.1 (https://openmdw.ai/license/1-1/) |
| 구조 | Mamba-2 + Transformer 혼합 LatentMoE, 전체 74B 중 활성 9B, 이미지·영상 입력 |
| 양자화 · 크기 · sha256 | 공식 2비트 QAT(IQ2) · 22.0GB (22,018,326,528 B) · `91d63363e782c8a3` + mmproj 1.7GB · `0ee891eadc7bf0ca` + LiLiCorr 초안 1.0GB · `080e1ea41c9562a7` |
| 출처 | https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB-GGUF · 초안 https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB-LiLiCorr-GGUF |
| 엔진 | **llama.cpp b11701 이상 필요** (PR #30520, 2026-10-15 병합). b11539 에서는 로드에 실패했다: `check_tensor_dims: blk.1.ffn_gate_inp.weight has wrong shape`(층마다 전문가 수가 다름), mmproj(C-RADIO)도 읽지 못했다 - [troubleshooting.md](troubleshooting.md#새-모델이-로드되지-않는다-llamacpp-빌드가-모델보다-오래됨) |
| router 설정 | `spec-type = draft-dflash`(초안 6토큰, NVIDIA 레시피) · `cache-type-k/v = q8_0` · `chat-template-kwargs = {"enable_thinking":false}`(서버 기본은 생각 끔. 요청에서 `enable_thinking: true` 를 주면 켜지는 것을 확인했다) · `temp = 1.0`, `top-p = 0.95`(카드 권장). 설치 스크립트는 opencode variant `fast`(끔, 기본) / `think`(켬)를 만든다 |
| 표준 시험 (b11701, 생각 끔 - 서버 기본) | 첫 응답 24.0초 · 생성 53.7 t/s · 읽기 415 t/s · GTT 28.8G · DFlash 수락 71% (284/402) |
| 표준 시험 (b11701, 생각 켬) | 첫 응답 103.5초(추론 약 1.25만 자) · 생성 46.3 t/s · 읽기 417 t/s · GTT 28.8G · DFlash 수락 57% (3072/5370) |
| 통과 횟수 | 2/2회 (b11701: 생각 켬 1회, 끔 1회 - 둘 다 통과) |
| 간이 확인 | 생각 끔에서 생성 62.4 t/s, 작은 함수 하나 1.2초 (같은 하네스의 정식 측정은 아님) |
| 평가 | 「로컬 에이전트·도구 호출·터미널」용으로 학습된, 64GB 장비를 겨냥한 24GB 판 2비트 모델. 표준 시험은 2회 모두 통과했다. 실전 과제(테트리스·갤러그)는 아직 하지 않았다. |

## lfm - LFM2.5-24B-A2B

| 항목 | 내용 |
|---|---|
| 만든 곳 | Liquid AI |
| 공개일 | GGUF 저장소 2026-10-09 (원본 저장소 2026-10-12) |
| 라이선스 | LFM Open License 1.0 (매출 1천만 달러 미만 무료 상업 이용 - 조건은 모델 페이지 확인) |
| 구조 | 하이브리드 MoE, 전체 24B 중 활성 2B, 에이전트 도구 사용 중심 학습 |
| 양자화 · 크기 · sha256 | Q8_0 · 25.5GB (25,493,732,640 B) · `f09bf094a8a138c5` |
| 출처 | https://huggingface.co/LiquidAI/LFM2.5-24B-A2B-GGUF |
| router 설정 | 추측 디코딩 없음 · `temp = 0.1`, `top-k = 50`, `repeat-penalty = 1.05`(카드 권장, GGUF 메타데이터에도 있음). LFM2.5 는 **생각이 기본으로 켜져 있고** 끄는 설정은 넣지 않았다 |
| 표준 시험 | 첫 응답 65.4초 · 생성 75.2 t/s · 읽기 1834 t/s · GTT 25.4G · 생각 켬(약 1.34만 자) · 통과 1/1회 |
| 평가 | 활성 2B 라 생성 75 t/s, 읽기 1834 t/s 로 빠르다. 코드 두 함수를 쓰면서 생각을 약 1.34만 자 써서(생성 약 3,800 토큰) 첫 응답이 65.4초 걸렸다. 실전 과제(테트리스·갤러그)는 아직 하지 않았다. |

---

# 실험 · 비교 · 기준선용

router 에 올려 두었지만 일상 사용은 권하지 않는 모델. 비교 시험의 기준이거나, 용도가 다르거나, 실험 중인 것들이다.

## fn - Qwen3.8-Flash-Next GSQ-RCO Coder (가지치기)

| 항목 | 내용 |
|---|---|
| 만든 곳 / 압축 | Qwen(원본) / ISTA-DASLab(압축) |
| 공개일 | 원본 2026-08-24 · GGUF 저장소 2026-09-26 |
| 라이선스 | 저장소 표기 Apache-2.0. **원본 Qwen3.8-Flash-Next 는 Qwen Community License 1.0** - [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) |
| 구조 | 원본은 전체 125B 중 활성 6B (+ n-gram 임베딩 51B, MTP 4B; 공식 모델 카드). 이 파일은 전문가 512개 중 절반을 코딩용으로 선별해 제거한 압축판, 이미지 입력 가능 |
| 양자화 · 크기 · sha256 | IQ1_M(유효 1.89비트) · 58.4GB = 2조각 (29,608,446,496 + 28,800,138,432 B) · `e11083ba855e7666` / `316b46f3a2dbd68c` |
| 출처 | https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF |
| router 설정 | `load-mode = mmap` + `override-tensor = per_layer_token_embd=CPU`(58.4GB 중 28.8GB 인 이 텐서 하나를 GPU 에 올리지 않고 CPU 쪽에서 mmap 으로 필요한 줄만 읽는다 -> GPU 약 30GB) · 생각 끔 · `temp = 0.7`, `top-p = 0.8`, `top-k = 20`, `min-p = 0`, `presence-penalty = 1.5`(양자화판 반복 억제) |
| 표준 시험 | 첫 응답 69.5초 · 생성 23.6 t/s · 읽기 357 t/s · GTT 30.2G · 통과 **0/2회** (두 번 모두 rotateMatrix 에서 TypeError) |
| 평가 | 실험용. `Array(n).map(...)` 빈 배열 버그가 10-11 과 10-17 두 번 같은 모양으로 나왔고, 표준 시험도 0/2회였다. 처음(10-11)에는 생각을 켜면 0바이트, 생각을 끄고 `temp 0.2` 면 「Malayalam」 반복으로 붕괴했다 - 지금 샘플링은 이를 피하려는 설정이다. 실전 과제는 하지 않았다. |

이 파일은 처음 받을 때부터 Coder 판이었다(저장소의 sha256 과 일치). 범용 GSQ-RCO 저장소에는 IQ1_M 이 없다.

## ff - Qwen3.8-Flash-Next GSQ-RCO 전체판

| 항목 | 내용 |
|---|---|
| 만든 곳 / 압축 | Qwen(원본) / ISTA-DASLab(압축) |
| 공개일 | 원본 2026-08-24 · GGUF 저장소 2026-09-07 |
| 라이선스 | 저장소 표기 Apache-2.0. **원본 Qwen3.8-Flash-Next 는 Qwen Community License 1.0** - [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) |
| 구조 | 원본 그대로 전체 125B 중 활성 6B (+ n-gram 임베딩 51B, MTP 4B; 공식 모델 카드). 전문가 512개를 모두 유지한 압축판 |
| 양자화 · 크기 · sha256 | IQ3_XXS · 75.8GB = 2조각 (47,039,860,096 + 28,800,138,432 B) · `219ea929900dfa9e` / `316b46f3a2dbd68c` (둘째 조각은 `fn` 과 같은 파일) |
| 출처 | https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF |
| router 설정 | `fn` 과 같다: `load-mode = mmap` + `override-tensor = per_layer_token_embd=CPU` · 생각 끔 · `temp = 0.7`, `top-p = 0.8`, `top-k = 20`, `min-p = 0`, `presence-penalty = 1.5` |
| 표준 시험 | 첫 응답 98.8초 · 생성 24.3 t/s · 읽기 315 t/s · GTT 46.5G (+ mmap 28.8GB, 첫 측정 중 남은 RAM 최저 11.6G) · 생각 끔 · 통과 2/2회 (같은 계열 `fn` 은 0/2회) |
| 평가 | 비교용. 메모리가 가장 빠듯한 모델이다: GTT 46.5G 에 더해 28.8GB 를 mmap 으로 읽어 시험 중 남은 RAM 이 11.6G 까지 줄었다(GTT 점유만 보면 `cn` 47.5G 가 더 크다). 10-11 벤치에서는 생각을 켜면 결과 0바이트(생각만 함)였고, `fn` 과 같은 비생각 샘플링으로 바꾼 표준 시험은 2회 모두 통과했다. 실전 과제는 하지 않았다. |

## q38 - Qwen3.8-27B

| 항목 | 내용 |
|---|---|
| 만든 곳 / 변환 | Qwen / unsloth (GGUF) |
| 공개일 | 원본 2026-08-05 · GGUF 저장소 2026-08-13 |
| 라이선스 | Apache-2.0 |
| 구조 | dense 27B(활성 = 전체), 생각 모델 |
| 양자화 · 크기 · sha256 | UD-Q6_K · 22.0GB (21,983,677,344 B) · `c9c206812fbe4ac7` |
| 출처 | https://huggingface.co/unsloth/Qwen3.8-27B-GGUF |
| router 설정 | `spec-type = draft-mtp`(파일 안 `nextn` 층) · `chat-template-kwargs = {"enable_thinking":false}`(생각 끔) |
| 표준 시험 | 첫 응답 32.3초 · 생성 25.3 t/s · 읽기 301 t/s · GTT 27.7G · MTP 수락 85% · 생각 끔 · 통과 2/2회 |
| 과거 실측 | 10-11 벤치 생각 끔 6/6 · 26 t/s, 벽돌깨기 5.8분 · 661줄로 요구 충족. 생각을 켜면 벽돌깨기에서 17분 동안 생각만 하고 결과 0바이트. 첫 시험의 9.8 t/s 는 MTP 를 끈 채 잰 값이라 보정했다 |
| 평가 | 비교용. 같은 시기의 MoE(`q36` 91.3 / 1001 t/s)보다 생성은 3.6배, 읽기는 3.3배 느리다. 매 단계 문맥을 다시 읽는 에이전트에는 부적합하다고 판단했다. |

## aw - Qwen-AgentWorld-35B-A3B (세계 모델 — 코딩 에이전트용 아님)

| 항목 | 내용 |
|---|---|
| 만든 곳 / 변환 | Qwen / unsloth (GGUF) |
| 공개일 | 원본 2026-06-22 · GGUF 저장소 2026-06-24 |
| 라이선스 | Apache-2.0 |
| 구조 | MoE, 전체 35B 중 활성 3B. **세계 모델** - 도구·환경의 반응을 흉내 내는 시뮬레이터이지 코딩 에이전트가 아니다 |
| 양자화 · 크기 · sha256 | UD-Q6_K · 29.3GB (29,308,321,024 B) · `cce7ec62095093b9` |
| 출처 | https://huggingface.co/unsloth/Qwen-AgentWorld-35B-A3B-GGUF |
| router 설정 | 공통값만 |
| 표준 시험 | 첫 응답 63.9초 · 생성 55.5 t/s · 읽기 1046 t/s · GTT 28.9G · 생각 켬(약 7.2천 자, 세계 모델) · 통과 2/2회 |
| 평가 | 용도가 달라 에이전트 비교 대상이 아니다. 비교·참고용으로만 router 에 둔다. |

## c7 - Qwen2.5-Coder-7B-Instruct (직접 변환, 기준선)

| 항목 | 내용 |
|---|---|
| 만든 곳 | Qwen (옛 세대, dense 7B) |
| 공개일 | 원본 2024-09-17 · 로컬 변환 2026-08-03 |
| 라이선스 | Apache-2.0 |
| 구조 | dense 7B(활성 = 전체) |
| 양자화 · 크기 · sha256 | Q8_0 · 8.1GB (8,098,525,760 B) · `c4b171ef14a7a498` - **내려받는 파일이 아니라** 원본 가중치를 직접 GGUF 로 변환한 파일이다 |
| 출처 | 원본 https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct |
| router 설정 | **`c = 32768`** - 이 모델의 문맥은 32K 가 한계다. 설치 스크립트가 opencode 쪽도 `limit.context = 32768` 로 맞춘다 |
| 표준 시험 | 첫 응답 34.1초 · 생성 28.9 t/s · 읽기 1127 t/s · GTT 9.6G · 생각 없음 · 통과 2/2회 |
| 평가 | 비교 기준선. 작고 가벼우며(GTT 9.6G) 표준 시험(두 함수)은 통과했지만, 옛 세대 모델이라 큰 에이전트 과제는 시험하지 않았다. |

## c7r - c7 + 직접 학습한 React LoRA (예시)

| 항목 | 내용 |
|---|---|
| 베이스 | `c7` 과 같은 파일(Qwen2.5-Coder-7B-Instruct Q8_0) |
| 어댑터 | 「r4mlp」 - qkvo+MLP, rank 16, 2026-06-27 RTX 4060 에서 학습, 자체 held-out 평가 95%(7B 어댑터 중 1위). 80MB (`4060-r4mlp-f16.gguf`, sha256 `1b8de00176055df4`) |
| 공개 여부 | **어댑터 파일은 비공개 — 직접 만든 LoRA 로 바꿔 쓰는 예시.** 이 레포에 파일도 내려받는 링크도 없다. `lora = ...` 한 줄로 LoRA 를 붙이는 방법만 보여 준다 |
| 라이선스 | 베이스 Apache-2.0. 어댑터는 직접 만든 것이라 이 레포의 지정 범위 밖 |
| router 설정 | `model` = `c7` 과 같은 파일 · `lora` = 어댑터 경로 · `c = 32768` |
| 표준 시험 | 첫 응답 9.4초(`c7` 직후라 파일이 캐시되어 있었다) · 생성 27.8 t/s · 읽기 931 t/s · GTT 9.6G · 통과 **1/2회** (b11701 에서 clearLines 실패) · LoRA 적용 확인(자식 서버 `/lora-adapters`, scale 1.0) |
| 평가 | React 컴포넌트 코드 생성 특화 비교용. LoRA 를 붙여도 표준 시험 속도는 `c7` 과 비슷하다(생성 28.9 -> 27.8 t/s). |

## c1 - Qwen2.5-Coder-1.5B-Instruct (직접 변환, 속도 기준선)

| 항목 | 내용 |
|---|---|
| 만든 곳 | Qwen (옛 세대, dense 1.5B) |
| 공개일 | 원본 2024-09-18 · 로컬 변환 2026-07-31 |
| 라이선스 | Apache-2.0 |
| 구조 | dense 1.5B(활성 = 전체) |
| 양자화 · 크기 · sha256 | F16 · 3.1GB (3,093,669,504 B) · `f1c4072853e42b29` - **내려받는 파일이 아니라** 직접 변환한 파일 |
| 출처 | 원본 https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct |
| router 설정 | `c = 32768` (32K 모델, 설치 스크립트가 opencode 쪽도 맞춘다) |
| 표준 시험 | 첫 응답 8.8초 · 생성 68.6 t/s · **읽기 3057 t/s** (가장 빠름) · GTT 4.3G · 생각 없음 · 통과 **0/2회** (두 번 모두 clearLines 실패) |
| 평가 | 속도·자동완성급 기준선. 읽기가 가장 빠르고 가장 가볍지만(생성은 `q36` `orn` `lfm` 등 MoE 가 더 빠르다) 표준 시험을 한 번도 통과하지 못했다(0/2회). |

---

# 추가 중 — 실측 전

아래 하나는 모델 파일을 받아 sha256 대조까지 마쳤고 [`server/llm-presets.ini`](../server/llm-presets.ini)에도 들어 있지만 **속도·메모리·품질은 아직 재지 않았다**(표의 「-」). sha256 은 Hugging Face 가 공개한 값이다.

### mcv - MiniCPM-V 4.7 35B-A3B

| 항목 | 내용 |
|---|---|
| 만든 곳 | OpenBMB |
| 공개일 | GGUF 저장소 2026-10-06 (원본 저장소 2026-10-07, 초안 DSpark 2026-10-14) |
| 라이선스 | Apache-2.0 |
| 구조 | 시리즈 첫 MoE, 전체 35B 중 활성 3B, 이미지·영상 이해 특화 |
| 양자화 · 크기 · sha256 | Q6_K · 28.5GB (28,513,556,640 B) · `fcbe98ad681730bc` + mmproj f16 1.1GB · `bff3b688e14c300e` + DSpark 초안 Q8_0 0.42GB · `9d23bebd6079cace` |
| 출처 | https://huggingface.co/openbmb/MiniCPM-V-4.7-35B-A3B-gguf · 초안 https://huggingface.co/openbmb/MiniCPM-V-4.7-35B-A3B-DSpark-gguf |
| 엔진 | **llama.cpp b11701 이상 필요** (PR #29416, 2026-10-10 병합) - 2026-10-09 빌드인 b11539 에는 이 PR 이 없다 |
| router 설정 | `spec-type = draft-dspark` · 생각 끔(카드의 instruct 모드) · `temp = 0.7`, `top-p = 0.95`, `top-k = 100`, `min-p = 0` |
| 표준 시험 / 실전 | 실측 전 |

---

## 받아 봤지만 쓰지 않는 모델 / 검토 후 제외

`q38`(Qwen3.8-27B), `ff`(Flash-Next 전체판), `aw`(AgentWorld)는 비교용으로 router 에 남아 있어 위 카탈로그에 있다. 아래는 router 에 올리지 않은 모델이다.

| 모델 | 사유 |
|---|---|
| GLM-5.3-Flash (321B) | 64GB 에 들어가지 않는다. |
| Nemotron 3 Super (120B) | 4비트로도 64GB 이상이 필요하다. |
| Nemotron 3.5 Super-VL (120B, 활성 12B) | IQ1_M 으로도 46GB 인 데다 활성이 커서 제외. |
| Muse Spark Open (816B) | 크기가 64GB 장비 범위를 크게 넘는다. |
| Cyber-Tiel | Ornith 의 abliterated 파생 모델 - 후보 조사에서 제외. |
| Nemotron 3 Ultra (550B-A55B) | 이 서버에서 돌리지 않는다. opencode 의 외부 무료 제공자로 한 번 써 봤을 뿐이다(테트리스: 정육면체를 이어 붙인 진짜 3D 블록이 나왔지만 회전 불가). 코드가 밖으로 나가므로 설치 스크립트는 외부 제공자를 꺼 둔다 - [troubleshooting.md](troubleshooting.md#외부-제공자가-켜져-있어-코드가-밖으로-나간다). |
| Meta Llama 계열 | Llama 4(2025-04) 이후 신작이 없다. Meta 의 에이전트 모델은 Muse Glimmer(`mg`)다. |

## 새 모델을 넣을 때

체크리스트는 [server.md](server.md#새-모델-추가-체크리스트)에 있다. 이 문서에는 머리 주석과 같은 항목(풀네임·출처·공개일·라이선스·양자화·크기·sha256·가속·샘플링·실측)을 채운다.
