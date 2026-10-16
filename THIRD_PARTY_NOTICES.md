# 제3자 소프트웨어 · 모델 고지 (Third-party notices)

이 레포는 아래 소프트웨어와 모델 가중치를 **포함하거나 재배포하지 않는다.** 설치 스크립트와 문서는 공식 배포처에서 받는 방법만 안내한다.
받아서 쓰는 사람은 각 항목의 라이선스를 직접 확인하고 따라야 한다.

이 레포 자체의 내용(문서, 스크립트, 설정)은 아직 라이선스를 정하지 않았다 - **라이선스 미지정(추후 결정)**.

## 소프트웨어

### opencode

- 라이선스: **MIT License** - Copyright (c) 2025 opencode
- 저장소: https://github.com/anomalyco/opencode
- 라이선스 전문: https://github.com/anomalyco/opencode/blob/dev/LICENSE
- 이 레포에서의 사용: [`client/windows/install.ps1`](client/windows/install.ps1) 이 **공식 릴리스 바이너리 v1.18.35** 를 GitHub Releases 에서 내려받아 sha256 을 검증한 뒤 설치한다. 이 레포는 opencode 를 재배포하지 않는다.

### llama.cpp

- 라이선스: **MIT License** - Copyright (c) 2023-2026 The ggml authors
- 저장소: https://github.com/ggml-org/llama.cpp
- 라이선스 전문: https://github.com/ggml-org/llama.cpp/blob/master/LICENSE
- 이 레포에서의 사용: 서버는 공식 사전빌드 릴리스 **b11539 (Vulkan)** 를 쓴다 - https://github.com/ggml-org/llama.cpp/releases/tag/b11539. 이 레포는 llama.cpp 를 포함하지 않는다.

## 모델 가중치

모델 파일은 Hugging Face 에서 직접 받는다([`server/models.tsv`](server/models.tsv)에 저장소·파일명·크기·sha256). 이 레포는 가중치를 재배포하지 않는다.
**각 모델의 라이선스 조건을 따라야 한다.** 표의 라이선스는 해당 저장소가 표기한 값이며, 법률 자문이 아니다.

| 별칭 | 모델 | 라이선스 | 모델 페이지 |
|---|---|---|---|
| `cn` | Qwen3-Coder-Next 80B-A3B (bartowski GGUF) | Apache-2.0 | https://huggingface.co/bartowski/Qwen_Qwen3-Coder-Next-GGUF · 원본 https://huggingface.co/Qwen/Qwen3-Coder-Next |
| `q36` | Qwen3.6-35B-A3B (unsloth MTP GGUF) | Apache-2.0 | https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF · 원본 https://huggingface.co/Qwen/Qwen3.6-35B-A3B |
| `mg` | Muse Glimmer 30B (Meta) | Apache-2.0 | https://huggingface.co/meta-models/Muse-Glimmer-30B-GGUF |
| `orn` | Ornith-1.5-35B-A3B (ornith-ai) | MIT | https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B-GGUF |
| `fn` | Qwen3.8-Flash-Next GSQ-RCO Coder (ISTA-DASLab) | Apache-2.0 (저장소 표기) - 아래 주석 참고 | https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF |
| `mel` | Mellum2.1-12B-A2.5B Thinking (JetBrains) | Apache-2.0 | https://huggingface.co/JetBrains/Mellum2.1-12B-A2.5B-Thinking-GGUF |
| `bolt` (추가 중) | NVIDIA Nemotron 3.5 Bolt 74B-A9B 24GB | OpenMDW-1.1 - https://openmdw.ai/license/1-1/ | https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB-GGUF (초안 모델 LiLiCorr 도 OpenMDW-1.1) |
| `lfm` (추가 중) | LFM2.5-24B-A2B (Liquid AI) | LFM Open License 1.0 - 연 매출 1천만 달러(USD 10M) 미만이면 무료 상업 이용. 조건 전문은 모델 페이지의 LICENSE | https://huggingface.co/LiquidAI/LFM2.5-24B-A2B-GGUF |
| `mcv` (추가 중) | MiniCPM-V 4.7 35B-A3B (OpenBMB) | Apache-2.0 (초안 모델 DSpark 도 Apache-2.0) | https://huggingface.co/openbmb/MiniCPM-V-4.7-35B-A3B-gguf |

주석:
- **`fn`**: GGUF 저장소(ISTA-DASLab)는 Apache-2.0 으로 표기하지만, 원본 `Qwen/Qwen3.8-Flash-Next` 의 모델 카드는 **Qwen Community License 1.0** 이다 - https://huggingface.co/Qwen/Qwen3.8-Flash-Next/blob/main/LICENSE (예: 제3자에게 모델 추론 접근을 제공하는 MaaS 사업이나 AI 코딩·업무 보조 제품 사업은 상업 목적 사용에 Qwen 의 별도 라이선스가 필요하고, 제3자에게 제공하지 않는 내부 사용은 예외라고 적혀 있다). 두 곳을 모두 확인하고 더 엄격한 쪽을 따른다.
- **`orn`**: 저장소는 MIT 로 표기한다. 모델 카드에 따르면 이전 버전(Ornith-1.0)이 Qwen3.5 와 Gemma4 위에서 개발되었으므로, 상속되는 조건이 있는지 원 모델의 라이선스도 확인한다.
- **`lfm`**: 매출 조건을 충족하지 못하면 별도 계약이 필요하다. 사용 전에 라이선스 전문을 읽는다.
- 모델 가중치는 이 서버 안에서만 쓰며, 서버는 API 키로 보호된 로컬 네트워크 서비스다. 외부 공개 서비스로 제공하는 경우 각 라이선스의 조건이 달라질 수 있다.

## 그 밖의 참고

- **Nemotron 3 Ultra** 등 opencode 의 외부 제공자로 시험해 본 모델은 이 레포의 구성에 포함되지 않는다(설치 스크립트는 외부 제공자를 꺼 둔다).
- 문서의 벤치마크 수치는 이 레포 작성자가 직접 잰 값이며, 모델 제작사의 공식 수치가 아니다.
