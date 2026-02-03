FROM node:20-slim

# 기본 개발 도구 설치
RUN apt-get update && apt-get install -y \
    git \
    curl \
    jq \
    python3 \
    python3-pip \
    lsof \
    procps \
    iptables \
    iproute2 \
    ca-certificates \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Tailscale 설치
RUN curl -fsSL https://tailscale.com/install.sh | sh

# Claude Code CLI 설치
RUN npm install -g @anthropic-ai/claude-code

# Claude Task Master 설치
RUN npm install -g task-master-ai

# Claude Code UI 설치
RUN npm install -g @siteboon/claude-code-ui

# claude 사용자 생성
RUN useradd -m -s /bin/bash claude && \
    echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 작업 디렉토리 설정
RUN mkdir -p /home/claude/workspace
WORKDIR /home/claude/workspace

# Claude 설정 디렉토리 생성
RUN mkdir -p /home/claude/.claude/projects

# Claude Code UI 데이터 디렉토리 생성
RUN mkdir -p /home/claude/.claude-code-ui

# Cursor MCP 설정 (경고 방지)
RUN mkdir -p /home/claude/.cursor && \
    echo '{"mcpServers":{}}' > /home/claude/.cursor/mcp.json

# 디렉토리 소유권 변경
RUN chown -R claude:claude /home/claude

# 환경 변수
ENV HOME=/home/claude

# 포트 노출 (Claude Code UI 기본 포트 + Tailscale Serve용)
EXPOSE 3001 80

# 시작 스크립트
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# claude 사용자로 전환
USER claude

ENTRYPOINT ["/entrypoint.sh"]
