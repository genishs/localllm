# 모델 카탈로그

서버(router)가 한 포트에서 골라 주는 모델 전체와, 받아 봤지만 쓰지 않는 모델의 사유.
수치는 서버 로그와 자체 시험 하네스에서 집계한 값이며, 실전 과제는 모델당 1회(n=1)다 - 경향으로만 읽는다.
자세한 시험 내용은 [benchmarks.md](benchmarks.md), 운영 방법은 [server.md](server.md).

- 별칭(alias) = router 에서 요청의 `model` 값 = opencode 에서 `halo/<별칭>`.
- 파일 크기 GB 는 10^9 바이트. sha256 은 앞 16자리(전체 값과 받는 주소는 [`server/models.tsv`](../server/models.tsv)).
- 「표준 시험」은 2026-10-17 같은 하네스로 모든 모델을 GPU 에서 한 번에 하나씩 돌린 값이다(방법: [benchmarks.md](benchmarks.md#1-표준-시험-2026-10-17)).

## 한눈에 보기

| 별칭 | 모델 | 구조 | 양자화 · 크기 | 가속 | 생성 t/s* | 읽기 t/s* | GTT* | 상태 |
|---|---|---|---|---|---|---|---|---|
| `cn` | Qwen3-Coder-Next 80B-A3B | MoE 3B 활성, 코딩 전용 | Q4_K_M · 48.7GB | 없음 | 55.4 | 732 | 47.5G | 사용 중 (서버 기본 상주) |
| `q36` | Qwen3.6-35B-A3B | MoE 3B 활성, 범용 | UD-Q6_K · 30.0GB | MTP | 89.7 | 1007 | 30.7G | 사용 중 |
| `mg` | Muse Glimmer 30B | dense 30B, 에이전트용 | Q4_K_XL · 19.7GB (+초안 1.6GB) | DFlash | 25.3 | 331 | 22.7G | 사용 중 |
| `orn` | Ornith-1.5-35B-A3B | MoE 3B 활성, 추론 모델 | Q6_K · 29.2GB | MTP | 87.3 | 968 | 30.0G | 사용 중 |
| `fn` | Qwen3.8-Flash-Next Coder (가지치기) | MoE, 전문가 절반 제거 | IQ1_M · 58.4GB (2조각) | 없음 | 23.1 | 356 | 30.2G | 사용 중 (실험용) |
| `mel` | Mellum2.1-12B-A2.5B Thinking | MoE 2.5B 활성, 생각 모델 | Q8_0 · 12.9GB | 없음 | 84.7 | 2008 | 13.3G | 사용 중 (실전 과제 미실시) |
| `bolt` | Nemotron 3.5 Bolt 74B-A9B | 혼합 LatentMoE 9B 활성 | 2비트 QAT · 22.0GB (+mmproj, 초안) | DFlash | - | - | - | **추가 중 - 실측 전** |
| `lfm` | LFM2.5-24B-A2B | 하이브리드 MoE 2B 활성 | Q8_0 · 25.5GB | 없음 | - | - | - | **추가 중 - 실측 전** |
| `mcv` | MiniCPM-V 4.7 35B-A3B | MoE 3B 활성, 비전 특화 | Q6_K · 28.5GB (+mmproj, 초안) | DSpark | - | - | - | **추가 중 - 실측 전** |

\* 표준 시험(2026-10-17) 값. 생성 = 답을 쓰는 속도, 읽기 = 긴 프롬프트(약 9.8천 토큰)를 읽는 속도, GTT = 올라간 모델이 쓰는 GPU 공유 메모리.
mg 는 생각 강도 low. 작업 중 평균은 이보다 낮을 수 있다(아래 각 모델의 「과거 실측」).

용어:
- **MoE / 활성 파라미터**: 전문가 여러 개 중 일부만 토큰마다 쓰는 구조. `A3B` = 활성 3B. 이 서버는 메모리 대역폭이 속도를 정하므로 활성이 작을수록 빠르다.
- **추측 디코딩**: 작은 초안(MTP 층 또는 별도 초안 모델)이 토큰 여러 개를 미리 제안하고 본 모델이 한 번에 검증한다. 수락률이 높을수록 빠르다. 코드를 길게 쓰는 구간에서는 수락률이 떨어진다.
  - `MTP`: 모델 파일에 `nextn` 층이 들어 있어야 한다(`spec-type = draft-mtp`). `DFlash`/`DSpark`: 별도 초안 모델 파일(`model-draft`).
- **GTT**: 통합 메모리 중 GPU 가 쓰는 공유 구간. 이 서버는 56GiB ([hardware.md](hardware.md)).

## 라우터 공통 설정 (`[*]`)

`n-gpu-layers = 999`(전부 GPU) · `flash-attn = on` · `jinja = true` · `c = 65536`(문맥 64K) · `load-mode = none`(통째로 메모리에 올림, 옛 `--no-mmap`).
모델 섹션이 같은 키를 쓰면 공통값을 덮어쓴다. 슬롯은 4개(기본)라 서브에이전트가 동시에 돌면 속도를 나눠 쓴다.

---

## cn - Qwen3-Coder-Next 80B-A3B

| 항목 | 내용 |
|---|---|
| 만든 곳 / 변환 | Qwen / bartowski (GGUF) |
| 저장소 공개일 · 라이선스 | 2026-02-03 · Apache-2.0 |
| 구조 | MoE, 전체 80B 중 활성 3B, 코딩 전용, 생각 기능 없음 |
| 양자화 · 크기 · sha256 | Q4_K_M · 48.7GB (48,727,680,704 B) · `78f38fe85daaab51` |
| 출처 | https://huggingface.co/bartowski/Qwen_Qwen3-Coder-Next-GGUF |
| router 설정 | 공통값만. `load-on-startup = true`(서버가 켜지면 제일 먼저 올라가는 기본 모델). 추측 디코딩 없음 - 이 GGUF 에는 MTP 층이 없다(헤더 확인) |
| 표준 시험 | 첫 응답 33.0초(교체 포함) · 생성 55.4 t/s · 읽기 732 t/s · GTT 47.5G · 채점 2/2 통과 |
| 과거 실측 | 생성 45~49 t/s · 읽기 550~750 t/s (실전 과제 평균) |
| 평가 | 가장 빨리 끝나는 초안형. 테트리스 4분07초에 끝냈지만 보드 가로·세로 인자가 뒤바뀐 한 줄(`createMatrix(20, 12)`)로 줄이 안 지워졌다. 갤러그는 5분26초, 서브에이전트(페르소나)를 사실상 쓰지 않았다. 버그를 짚어 주면 바로 고친다. |

## q36 - Qwen3.6-35B-A3B

| 항목 | 내용 |
|---|---|
| 만든 곳 / 변환 | Qwen / unsloth (MTP 포함 GGUF) |
| 저장소 공개일 · 라이선스 | 2026-05-11 · Apache-2.0 |
| 구조 | MoE, 전체 35B 중 활성 3B, 범용 |
| 양자화 · 크기 · sha256 | UD-Q6_K · 30.0GB (30,011,242,784 B) · `49935b04ad883c2f` |
| 출처 | https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF |
| router 설정 | `spec-type = draft-mtp` · `chat-template-kwargs = {"enable_thinking":false}`(생각 끔). 샘플링은 모델 기본값. 주의: unsloth 의 일반 GGUF 저장소는 MTP 층을 뺀다 - 반드시 `-MTP-GGUF` 저장소 파일 |
| 표준 시험 | 첫 응답 28.2초 · 생성 89.7 t/s · 읽기 1007 t/s · GTT 30.7G · MTP 수락 84% · 채점 2/2 통과 |
| 과거 실측 | 생성 71~86 t/s · 읽기 680~900 t/s · MTP 수락 81~94% (생각 켜면 60%대로 떨어진다) |
| 평가 | 기본 일꾼 후보. 빠르고 함수 벤치 6/6, 테트리스 5분34초 5/5. 갤러그(큰 과제)에서는 시작 3초 뒤 멈추고, 지정한 폴더가 아닌 사용자 홈에 프로젝트를 만들었다. |

## mg - Muse Glimmer 30B

| 항목 | 내용 |
|---|---|
| 만든 곳 | Meta |
| 저장소 공개일 · 라이선스 | 2026-08-09 · Apache-2.0 |
| 구조 | dense 30B(활성 = 전체), 에이전트용 |
| 양자화 · 크기 · sha256 | KQuant-Dynamic Q4_K_XL · 19.7GB (19,653,960,832 B) · `ac7023d6a4c704eb` + DFlash 초안 Q4_K_M · 1.6GB (1,631,208,128 B) · `b2e808bf656086fe` |
| 출처 | https://huggingface.co/meta-models/Muse-Glimmer-30B-GGUF |
| router 설정 | `model-draft` = DFlash 초안 · `spec-type = draft-dflash` · `spec-draft-n-max = 6`(초안 길이 3≈6 > 10·16, 길면 수락률이 떨어져 오히려 느려진다). 생각 강도는 서버가 아니라 요청마다 정한다 - opencode variant `low`(기본)/`xhigh`가 `chat_template_kwargs.reasoning_strength` 로 실린다 |
| 표준 시험 | 첫 응답 62.6초 · 생성 25.3 t/s · 읽기 331 t/s · GTT 22.7G · DFlash 수락 44% · 생각 low(약 3.8천 자) · 채점 2/2 통과 |
| 과거 실측 | 생성 20~30 t/s · 읽기 190~310 t/s · DFlash 수락 75%(벤치) / 27~44%(실전). 서브에이전트가 동시에 돌면 평균 7 t/s 까지 떨어진 적이 있다(갤러그) |
| 평가 | 시간이 걸려도 돌아가는 결과물이 필요할 때. 테트리스(xhigh 18분14초)와 갤러그(low 14분41초) 모두 직접 플레이 판정에서 완성도 1위. 대신 가장 느리다(dense 라 대역폭 한계). 코드를 잘게 나눠 쓰고 고치기를 반복한다. |

## orn - Ornith-1.5-35B-A3B

| 항목 | 내용 |
|---|---|
| 만든 곳 | ornith-ai |
| 저장소 공개일 · 라이선스 | 2026-08-18 · MIT |
| 구조 | MoE, 전체 35B 중 활성 3B, Qwen3.5/Gemma4 기반 자가개선 RL, 추론 모델(기본 생각 켬) |
| 양자화 · 크기 · sha256 | Q6_K · 29.2GB (29,208,731,392 B) · `15d4658bbfc9c603` |
| 출처 | https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B-GGUF |
| router 설정 | `spec-type = draft-mtp`(헤더에 `nextn` 층 확인) · 생각 끔 · `temp = 0.6`, `top-p = 0.95`, `top-k = 20`(모델 카드 권장) |
| 표준 시험 | 첫 응답 28.5초 · 생성 87.3 t/s · 읽기 968 t/s · GTT 30.0G · MTP 수락 69% · 채점 2/2 통과 |
| 과거 실측 | 생성 94 t/s(짧은 시험, MTP 87%) / 실전 평균 49 t/s(MTP 66%) · 읽기 600~630 t/s |
| 평가 | 팀(서브에이전트) 작업을 가장 성실히 돌린다(갤러그 126 요청). 그러나 갤러그 결과물은 좌우 이동이 안 되고 P(일시정지)가 풀리지 않아 진행 불가였다. 표본 1회라 판단 보류. 모델 카드의 벤치 점수(Terminal-Bench 2.1 67.8, SWE-bench Verified 79)는 생각을 켠 값이며 직접 검증하지 않았다. |

## fn - Qwen3.8-Flash-Next GSQ-RCO Coder (가지치기)

| 항목 | 내용 |
|---|---|
| 만든 곳 / 압축 | Qwen(원본 2026-08-24) / ISTA-DASLab(압축) |
| 저장소 공개일 · 라이선스 | 2026-09-26 · Apache-2.0 (저장소 표기. 원본 Qwen3.8-Flash-Next 는 Qwen Community License 1.0 - [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)) |
| 구조 | Qwen3.8-Flash-Next 에서 512 전문가 중 절반을 코딩용으로 선별해 제거, 이미지 입력 가능 |
| 양자화 · 크기 · sha256 | IQ1_M(유효 1.89비트) · 58.4GB = 2조각 (29,608,446,496 + 28,800,138,432 B) · `e11083ba855e7666` / `316b46f3a2dbd68c` |
| 출처 | https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF |
| router 설정 | `load-mode = mmap` + `override-tensor = per_layer_token_embd=CPU`(58.4GB 중 28.8GB 인 이 텐서 하나를 GPU 에 올리지 않고 CPU 쪽에서 mmap 으로 필요한 줄만 읽는다 -> GPU 약 30GB) · 생각 끔 · `temp = 0.7`, `top-p = 0.8`, `top-k = 20`, `min-p = 0`, `presence-penalty = 1.5`(양자화판 반복 억제) |
| 표준 시험 | 첫 응답 78.1초 · 생성 23.1 t/s · 읽기 356 t/s · GTT 30.2G · **채점 실패**(rotateMatrix TypeError) |
| 평가 | 실험용. `Array(n).map(...)` 빈 배열 버그가 10-11 과 10-17 두 번 같은 모양으로 나왔고, 표준 시험도 통과하지 못했다. 처음(10-11)에는 생각을 켜면 0바이트, 생각을 끄고 `temp 0.2` 면 「Malayalam」 반복으로 붕괴했다 - 지금 샘플링은 이를 피하려는 설정이다. 실전 과제는 하지 않았다. |

이 파일은 처음 받을 때부터 Coder 판이었다(저장소의 sha256 과 일치). 범용 GSQ-RCO 저장소에는 IQ1_M 이 없다.

## mel - Mellum2.1-12B-A2.5B Thinking

| 항목 | 내용 |
|---|---|
| 만든 곳 | JetBrains |
| 저장소 공개일 · 라이선스 | 2026-10-07 · Apache-2.0 |
| 구조 | MoE, 전체 12B 중 활성 2.5B(64 전문가 중 8개), 코딩 에이전트용 생각 모델 |
| 양자화 · 크기 · sha256 | Q8_0 · 12.9GB (12,925,417,760 B) · `69e0ac02a16586c2` |
| 출처 | https://huggingface.co/JetBrains/Mellum2.1-12B-A2.5B-Thinking-GGUF |
| router 설정 | 추측 디코딩 없음 · 생각은 늘 켜짐(Thinking 판이라 끌 수 없다) · `temp = 0.6`, `top-p = 0.95`, `top-k = 20`(카드 권장) · 모델은 문맥 131K 를 지원하지만 서버는 64K |
| 표준 시험 | 첫 응답 19.8초 · 생성 84.7 t/s · **읽기 2008 t/s** · **GTT 13.3G** · 생각 약 2.7천 자 · 채점 2/2 통과 |
| 평가 | 표준 시험에서 읽기가 가장 빠르고 메모리를 가장 적게 쓴다. 생각이 항상 켜져 있어 답이 길어진다. 실전 과제(테트리스·갤러그)는 아직 하지 않았다. |

---

## 추가 중 - 실측 전

아래 셋은 모델 파일을 받는 중이다. 파일·설정은 [`server/llm-presets.ini`](../server/llm-presets.ini)에 이미 들어 있지만 **속도·메모리·품질은 아직 재지 않았다**(표의 「-」). sha256 은 Hugging Face 가 공개한 값이며, 받은 뒤 `sha256sum` 으로 대조해야 한다.

### bolt - NVIDIA Nemotron 3.5 Bolt 74B-A9B 24GB

| 항목 | 내용 |
|---|---|
| 만든 곳 | NVIDIA |
| 저장소 공개일 · 라이선스 | 2026-10-07 · OpenMDW-1.1 (https://openmdw.ai/license/1-1/) |
| 구조 | Mamba-2 + Transformer 혼합 LatentMoE, 전체 74B 중 활성 9B, 이미지·영상 입력 |
| 양자화 · 크기 · sha256 | 공식 2비트 QAT(IQ2) · 22.0GB (22,018,326,528 B) · `91d63363e782c8a3` + mmproj 1.7GB · `0ee891eadc7bf0ca` + LiLiCorr 초안 1.0GB · `080e1ea41c9562a7` |
| 출처 | https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB-GGUF · 초안 https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB-LiLiCorr-GGUF (2026-10-12) |
| router 설정 | `spec-type = draft-dflash`(초안 6토큰, NVIDIA 레시피) · `cache-type-k/v = q8_0` · `temp = 1.0`, `top-p = 0.95`(카드 권장) |
| 비고 | 「로컬 에이전트·도구 호출·터미널」용으로 학습, 64GB 장비를 겨냥한 24GB 판 |
| 표준 시험 / 실전 | 실측 전 |

### lfm - LFM2.5-24B-A2B

| 항목 | 내용 |
|---|---|
| 만든 곳 | Liquid AI |
| 저장소 공개일 · 라이선스 | 2026-10-09 · LFM Open License 1.0 (매출 1천만 달러 미만 무료 상업 이용 - 조건은 모델 페이지 확인) |
| 구조 | 하이브리드 MoE, 전체 24B 중 활성 2B, 에이전트 도구 사용 중심 학습 |
| 양자화 · 크기 · sha256 | Q8_0 · 25.5GB (25,493,732,640 B) · `f09bf094a8a138c5` |
| 출처 | https://huggingface.co/LiquidAI/LFM2.5-24B-A2B-GGUF |
| router 설정 | 추측 디코딩 없음 · `temp = 0.1`, `top-k = 50`, `repeat-penalty = 1.05`(카드 권장, GGUF 메타데이터에도 있음) |
| 표준 시험 / 실전 | 실측 전 |

### mcv - MiniCPM-V 4.7 35B-A3B

| 항목 | 내용 |
|---|---|
| 만든 곳 | OpenBMB |
| 저장소 공개일 · 라이선스 | 2026-10-06 · Apache-2.0 |
| 구조 | 시리즈 첫 MoE, 전체 35B 중 활성 3B, 이미지·영상 이해 특화 |
| 양자화 · 크기 · sha256 | Q6_K · 28.5GB (28,513,556,640 B) · `fcbe98ad681730bc` + mmproj f16 1.1GB · `bff3b688e14c300e` + DSpark 초안 Q8_0 0.42GB · `9d23bebd6079cace` |
| 출처 | https://huggingface.co/openbmb/MiniCPM-V-4.7-35B-A3B-gguf · 초안 https://huggingface.co/openbmb/MiniCPM-V-4.7-35B-A3B-DSpark-gguf |
| router 설정 | `spec-type = draft-dspark` · 생각 끔(카드의 instruct 모드) · `temp = 0.7`, `top-p = 0.95`, `top-k = 100`, `min-p = 0` |
| 표준 시험 / 실전 | 실측 전 |

---

## 받아 봤지만 쓰지 않는 모델 / 검토 후 제외

| 모델 | 사유 |
|---|---|
| Qwen3.8-27B (dense, Q6_K 22.0GB) | 생각을 켜면 벽돌깨기에서 17분 동안 생각만 하고 결과 0바이트. 생각을 끄면 벽돌깨기 요구를 전부 충족했지만(5.8분, 661줄) 속도가 걸림돌이다: MTP 를 켜도 생성 26 t/s 이고, 읽기는 MTP 없이 쟀을 때 94.6 t/s 라 2만 토큰 문맥에 3.5분이 걸렸다. 매 단계 문맥을 다시 읽는 에이전트에는 부적합하다고 판단했다. (첫 시험의 9.8 t/s 는 MTP 를 끈 채 잰 값이라 보정했다.) |
| Qwen3.8-Flash-Next 전체판 (전문가 512개, IQ3_XXS 75.8GB) | 함수 벤치 5/6 - 생각이 토큰 한도(8000)를 다 먹어 답이 0자인 문제가 있었고, 벽돌깨기는 14분 넘게 생각만 하다 0바이트. (가지치기판은 `fn` 으로 남아 있다.) |
| Qwen-AgentWorld-35B-A3B | 세계모델(환경 시뮬레이터)이라 에이전트용이 아니다. |
| GLM-5.3-Flash (321B) | 64GB 에 들어가지 않는다. |
| Nemotron 3 Super (120B) | 4비트로도 64GB 이상이 필요하다. |
| Nemotron 3.5 Super-VL (120B, 활성 12B) | IQ1_M 으로도 46GB 인 데다 활성이 커서 제외. |
| Muse Spark Open (816B) | 크기가 64GB 장비 범위를 크게 넘는다. |
| Cyber-Tiel | Ornith 의 abliterated 파생 모델 - 후보 조사에서 제외. |
| Nemotron 3 Ultra (550B-A55B) | 이 서버에서 돌리지 않는다. opencode 의 외부 무료 제공자로 한 번 써 봤을 뿐이다(테트리스: 정육면체를 이어 붙인 진짜 3D 블록이 나왔지만 회전 불가). 코드가 밖으로 나가므로 설치 스크립트는 외부 제공자를 꺼 둔다 - [troubleshooting.md](troubleshooting.md#외부-제공자가-켜져-있어-코드가-밖으로-나간다). |
| Meta Llama 계열 | Llama 4(2025-04) 이후 신작이 없다. Meta 의 에이전트 모델은 Muse Glimmer(`mg`)다. |

## 새 모델을 넣을 때

체크리스트는 [server.md](server.md#새-모델-추가-체크리스트)에 있다. 이 문서에는 머리 주석과 같은 항목(풀네임·출처·공개일·라이선스·양자화·크기·sha256·가속·샘플링·실측)을 채운다.
