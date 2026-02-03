# Claude Code Docker Environment

Claude Code UI + Claude Code CLI를 Docker 컨테이너에서 실행합니다.

## 빠른 시작

```bash
# 1. 이미지 빌드
docker build -t claude-docker .

# 2. 실행 스크립트를 PATH에 등록 (선택)
sudo cp claude-docker /usr/local/bin/

# 3. 실행
claude-docker /path/to/your/project
```

## 실행 방법

### 방법 1: claude-docker 스크립트 사용 (권장)

```bash
# 현재 디렉토리를 프로젝트로 실행
claude-docker .

# 특정 프로젝트 경로 지정
claude-docker /path/to/myproject

# 포트 변경
claude-docker . -p 9000

# 백그라운드 실행
claude-docker . -d

# 백그라운드 + 맥북 sleep 방지
claude-docker . -d -k
```

### 방법 2: docker run 직접 사용

```bash
docker run -it --rm \
  -p 8000:3001 \
  -v /path/to/project:/home/claude/workspace \
  -v claude-auth:/home/claude/.claude \
  -v claude-code-ui-data:/home/claude/.claude-code-ui \
  claude-docker
```

## 접속

- **웹 UI**: http://localhost:8000
- **터미널 접속**: `docker exec -it <컨테이너이름> bash`

컨테이너 이름은 `claude-code-<프로젝트폴더명>` 형태입니다.

## 컨테이너 내부에서 Claude Code 사용

```bash
# 터미널 접속
docker exec -it claude-code-myproject bash

# 프로젝트 폴더로 이동
cd /workspace        # 마운트된 프로젝트 루트
cd /workspace/subdir # 하위 디렉토리로 이동

# Claude Code 실행 (권한 확인 건너뛰기)
claude --dangerously-skip-permissions
```

## 폴더 구조

```
claude-code-docker/
├── Dockerfile
├── entrypoint.sh
├── claude-docker        # 실행 스크립트
├── .env.example
├── .env                 # 직접 생성 (gitignore)
└── Readme.md
```

## 프로젝트 마운트 방식

| 방식 | 설정 | 컨테이너 경로 |
|------|------|--------------|
| 단일 프로젝트 | `claude-docker /home/user/dev/myapp` | `/workspace` = myapp |
| 여러 프로젝트 | `claude-docker /home/user/dev` | `/workspace/myapp`, `/workspace/other` |

## 인증

첫 실행 시 컨테이너 내에서 Claude 로그인이 진행됩니다. 로그인 정보는 Docker volume에 저장되어 이후 실행 시 자동 인증됩니다.

## 원격 접속 설정 (Tailscale)

```bash
# Tailscale 인증키로 원격 접속 설정
claude-docker . --tailscale tskey-auth-xxxxx

# 호스트 이름 지정
claude-docker . --tailscale tskey-auth-xxxxx --hostname my-claude

# 공개 URL 생성 (Funnel)
claude-docker . --tailscale tskey-auth-xxxxx --funnel
```

## 문제 해결

### 인증 오류

```bash
# 인증 정보 초기화 후 재실행
docker volume rm claude-auth
claude-docker .
```

### 세션 오류

```bash
# 세션 초기화
docker exec -it <컨테이너이름> rm -rf /home/claude/.claude/projects/*/sessions/*
docker restart <컨테이너이름>
```

## claude-docker 스크립트 옵션

```
Usage: claude-docker [PROJECT_PATH] [OPTIONS]

Arguments:
  PROJECT_PATH    프로젝트 경로 (기본: 현재 디렉토리)

Options:
  -p, --port          호스트 노출 포트 (기본: 8000)
  -n, --name          컨테이너 이름
  -d, --detach        백그라운드 실행
  -k, --keep-awake    맥북 sleep 방지 (caffeinate)
  -h, --help          도움말

Tailscale Options:
  --tailscale KEY     Tailscale 인증키로 네트워크 연결
  --hostname NAME     Tailscale 호스트 이름 (기본: claude-docker)
  --funnel            Tailscale Funnel로 공개 URL 생성
```
