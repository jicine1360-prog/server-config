#!/bin/bash
# 사무장/오팀장 전용 llama.cpp 서버 (패치된 Qwen3.8 템플릿, 포트 8087)
# - no-user-query 요청(warmup/압축/제목생성)도 500 없이 처리
# - PARALLEL=auto : GPU 수만큼 동시 슬롯, 슬롯당 컨텍스트(SLOT_CTX) 유지
#   총 ctx-size = SLOT_CTX * PARALLEL  (auto 시 GPU 수)
set -euo pipefail
BIN=/home/hoony/llama.cpp/build/bin/llama-server
MODEL=/home/hoony/models/hunmin-64k-tmpl.gguf
MMPROJ=/home/hoony/models/hunmin-mmproj.gguf
TEMPLATE=/home/hoony/models/Qwen3.8-27B/chat_template.patched.jinja
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
        --jinja --chat-template-file "$TEMPLATE" \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --flash-attn on --n-gpu-layers "${NGL:-99}" \
        --reasoning-budget 128 --chat-template-kwargs '{"enable_thinking":false}' \
        --context-shift \
        --alias hunmin-64k \
        > /home/hoony/logs/llama-hunmin.log 2>&1 &
    echo $! > /home/hoony/logs/llama-hunmin.pid
    echo "hunmin llama-server 시작: 포트 $PORT"
    ;;
stop) kill "$(cat /home/hoony/logs/llama-hunmin.pid 2>/dev/null)" 2>/dev/null || true; rm -f /home/hoony/logs/llama-hunmin.pid; echo "중지" ;;
status) curl -s --max-time 3 http://127.0.0.1:$PORT/v1/models | head -c 300; echo ;;
*) echo "사용법: $0 {start|stop|status}" ;;
esac
