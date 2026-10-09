#!/bin/bash
# 사무장/오팀장 전용 llama.cpp 서버 (패치된 Qwen3.8 템플릿, 포트 8086)
# - no-user-query 요청(warmup/압축/제목생성)도 500 없이 처리
set -euo pipefail
BIN=/home/hoony/llama.cpp/build/bin/llama-server
MODEL=/home/hoony/models/hunmin-64k-tmpl.gguf
MMPROJ=/home/hoony/models/hunmin-mmproj.gguf
TEMPLATE=/home/hoony/models/Qwen3.8-27B/chat_template.patched.jinja
PORT=8087

case "${1:-start}" in
start)
    if pgrep -f "llama-server.*--port $PORT" > /dev/null; then echo "이미 실행 중"; exit 0; fi
    nohup "$BIN" \
        --model "$MODEL" \
        --mmproj "$MMPROJ" \
        --host 127.0.0.1 --port $PORT \
        --ctx-size 65536 \
        --parallel "${PARALLEL:-2}" \
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
