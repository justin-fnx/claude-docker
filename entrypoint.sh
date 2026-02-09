#!/bin/bash

echo "============================================"
echo "  Claude Code Docker Environment"
echo "============================================"

# Git 설정 복사 (호스트 설정이 있고, 컨테이너에 없으면)
if [[ -f "/tmp/host-gitconfig" ]] && [[ ! -f "/home/claude/.gitconfig" ]]; then
    cp /tmp/host-gitconfig /home/claude/.gitconfig
    echo "[OK] Git 설정을 복제했습니다."
fi

# Claude 설정 확인 (~/.claude.json에서 mcpServers, allowedTools만 추출)
if [[ ! -f "/home/claude/.claude.json" ]]; then
    echo ""
    if [[ -f "/tmp/host-claude.json" ]]; then
        copy_settings() {
            # jq로 mcpServers, allowedTools만 추출
            jq '{mcpServers: .mcpServers, allowedTools: .allowedTools} | with_entries(select(.value != null))' \
                /tmp/host-claude.json > /home/claude/.claude.json
            echo "[OK] 호스트 설정을 복제했습니다 (mcpServers, allowedTools)"
        }

        # TTY가 있으면 사용자에게 물어보고, 없으면 자동 복사
        if [[ -t 0 ]]; then
            echo "[?] 호스트의 Claude 설정을 복제하시겠습니까?"
            echo "    (mcpServers, allowedTools만 복사됨)"
            echo "    (N 선택 시 기본 설정 사용)"
            read -p "    [y/N]: " COPY_SETTINGS
            if [[ "$COPY_SETTINGS" =~ ^[Yy]$ ]]; then
                copy_settings
            else
                echo "[OK] 기본 설정을 사용합니다."
            fi
        else
            # TTY 없음: 자동으로 호스트 설정 복사
            copy_settings
        fi
    else
        echo "[*] 기본 설정을 사용합니다."
    fi
    echo ""
fi

# Claude 글로벌 디렉토리 복사 (commands, agents, skills, hooks)
for dir in commands agents skills hooks; do
    src="/tmp/host-claude-$dir"
    dest="/home/claude/.claude/$dir"
    if [[ -d "$src" ]] && [[ ! -d "$dest" ]]; then
        mkdir -p /home/claude/.claude
        cp -r "$src" "$dest"
        echo "[OK] $dir 디렉토리를 복제했습니다."
    fi
done

# Claude 인증 확인 및 로그인
if [[ ! -f "/home/claude/.claude/.credentials.json" ]]; then
    echo ""
    echo "[!] 인증이 필요합니다. 로그인을 진행합니다..."
    echo ""
    claude login

    if [[ ! -f "/home/claude/.claude/.credentials.json" ]]; then
        echo "[ERROR] 로그인에 실패했습니다."
        exit 1
    fi
    echo ""
    echo "[OK] 로그인 완료! 다음 실행부터는 자동 인증됩니다."
    echo ""
fi

# Tailscale 설정 (선택적, sudo 필요)
if [[ -n "$TS_AUTHKEY" ]]; then
    echo "[*] Starting Tailscale..."
    sudo tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
    sleep 2

    # Tailscale 연결
    TS_OPTS="--authkey=$TS_AUTHKEY --hostname=${TS_HOSTNAME:-claude-docker}"
    sudo tailscale up $TS_OPTS

    # Tailscale Serve 활성화 (Tailscale 네트워크 내 80 -> 3001 프록시)
    echo "[*] Enabling Tailscale Serve (port 80 -> 3001)..."
    sudo tailscale serve --bg 80 http://localhost:3001

    # Funnel 활성화 (공개 URL 생성)
    if [[ "$TS_FUNNEL" == "true" ]]; then
        echo "[*] Enabling Tailscale Funnel on port 3001..."
        sudo tailscale funnel --bg http://localhost:3001
        FUNNEL_URL=$(sudo tailscale funnel status 2>/dev/null | grep -o 'https://[^ ]*' | head -1)
        if [[ -n "$FUNNEL_URL" ]]; then
            echo "[*] Public URL: $FUNNEL_URL"
        fi
    fi

    TS_IP=$(sudo tailscale ip -4 2>/dev/null)
    if [[ -n "$TS_IP" ]]; then
        echo "[*] Tailscale IP: $TS_IP"
    fi
fi

# Claude Code UI 데이터 디렉토리 권한 확인
if [[ -n "$DATABASE_PATH" ]]; then
    DB_DIR=$(dirname "$DATABASE_PATH")
    if [[ ! -d "$DB_DIR" ]]; then
        mkdir -p "$DB_DIR"
    fi
    # 쓰기 권한 확인 및 수정
    if [[ ! -w "$DB_DIR" ]]; then
        sudo chown -R claude:claude "$DB_DIR"
    fi
fi

# Claude Code UI 백그라운드 실행
echo "[*] Starting Claude Code UI on port 3001..."
claude-code-ui &

# UI 시작 대기
sleep 3

echo ""
echo "[*] Claude Code UI is running at http://localhost:3001"
if [[ -n "$TS_IP" ]]; then
    echo "[*] Tailscale: http://$TS_IP (port 80 -> 3001)"
fi
if [[ -n "$FUNNEL_URL" ]]; then
    echo "[*] Public: $FUNNEL_URL"
fi
echo ""
echo "[*] You can also use Claude Code CLI directly in this terminal"
echo ""
echo "Commands:"
echo "  claude                    - Start Claude Code CLI (interactive)"
echo "  claude --dangerously-skip-permissions  - Skip all permission prompts"
echo "  claude -p \"your prompt\"  - Run a single prompt"
echo ""
echo "============================================"

# 셸 유지 (터미널 접속용)
exec bash
