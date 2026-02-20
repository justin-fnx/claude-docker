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
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI 설치 (호스트 Docker 소켓 마운트용)
RUN curl -fsSL https://get.docker.com | sh

# JDK 21 (Eclipse Temurin) 설치
RUN apt-get update && apt-get install -y wget apt-transport-https gpg && \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(. /etc/os-release && echo $VERSION_CODENAME) main" > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && apt-get install -y temurin-21-jdk && \
    rm -rf /var/lib/apt/lists/*

# Gradle 설치
ENV GRADLE_VERSION=8.12
RUN wget -q https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -O /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt && \
    ln -s /opt/gradle-${GRADLE_VERSION} /opt/gradle && \
    rm /tmp/gradle.zip
ENV GRADLE_HOME=/opt/gradle
ENV PATH="${GRADLE_HOME}/bin:${PATH}"

# Tailscale 설치
RUN curl -fsSL https://tailscale.com/install.sh | sh

# npm 패키지 캐시 무효화 (빌드 시 항상 최신 버전 설치)
# 사용법: docker build --build-arg CACHEBUST=$(date +%s) -t claude-docker .
ARG CACHEBUST=1

# Claude Code CLI 설치
RUN npm install -g @anthropic-ai/claude-code

# Claude Task Master 설치
RUN npm install -g task-master-ai

# Claude Code UI 설치
RUN npm install -g @siteboon/claude-code-ui

# Playwright 설치 (브라우저 + 시스템 의존성)
RUN npx playwright install --with-deps chromium

# pnpm 설치
RUN npm install -g pnpm

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
