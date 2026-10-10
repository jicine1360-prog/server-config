#!/bin/bash
# 상주 MoE 모델 서버 (Qwen3.6-35B-A3B, MoE, 포트 8087)
# - llama.cpp-qwen4 빌드 필요 (qwen35moe / MTP 지원)
# - PARALLEL=auto : GPU 수만큼 동시 슬롯, 슬롯당 컨텍스트(SLOT_CTX) 유지
#   총 ctx-size = SLOT_CTX * PARALLEL (auto 시 GPU 수)
# - --reasoning off : thinking 출력 억제 (content 누출 방지)
set -euo pipefail
BIN=/home/hoony/llama.cpp-qwen4/build/bin/llama-server
MODEL=/home/hoony/models/qwen3.6-35b/qwen3.6-35b-Q4_K_M.gguf
MMPROJ=/home/hoony/models/qwen3.6-35b/mmproj-qwen3.6-35b.gguf
PORT=8087
PARALLEL="${PARALLEL:-auto}"
SLOT_CTX="${SLOT_CTX:-32768}"

if [ "$PARALLEL" = "auto" ]; then
    N=$(ls /dev/nvidia[0-9]* 2>/dev/null | wc -l | tr -d ' ')
    [ "${N:-0}" -lt 1 ] && N=1
    PARALLEL=$N
fi
CTX_SIZE=$(( SLOT_CTX * PARALLEL ))

case "${1:-start}" in
start)
    if pgrep -f "llama-server.*--port $PORT" > /dev/null; then echo "이미 실행 중"; exit 0; fi
    echo "GPU 슬롯: parallel=$PARALLEL, ctx=$CTX_SIZE (slot_ctx=$SLOT_CTX)"
    nohup "$BIN" \
        --model "$MODEL" \
        --mmproj "$MMPROJ" \
        --host 127.0.0.1 --port $PORT \
        --ctx-size $CTX_SIZE \
        --parallel "$PARALLEL" \
        --jinja \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --flash-attn on --n-gpu-layers "${NGL:-99}" \
        --reasoning off \
        --alias qwen3.6-35b \
        > /home/hoony/logs/llama-qwen36.log 2>&1 &
    echo $! > /home/hoony/logs/llama-qwen36.pid
    echo "qwen3.6-35b llama-server 시작: 포트 $PORT"
    ;;
stop) kill "$(cat /home/hoony/logs/llama-qwen36.pid 2>/dev/null)" 2>/dev/null || true; rm -f /home/hoony/logs/llama-qwen36.pid; echo "중지" ;;
status) curl -s --max-time 3 http://127.0.0.1:$PORT/v1/models | head -c 300; echo ;;
*) echo "사용법: $0 {start|stop|status}" ;;
esac
