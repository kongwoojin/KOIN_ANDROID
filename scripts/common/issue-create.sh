#!/usr/bin/env bash
set -euo pipefail

export ANTHROPIC_MODEL="claude-opus-4-6"

if [[ -z "${1:-}" ]]; then
    echo "❌ 에러: 이슈 설명을 입력하세요"
    echo "사용법: $0 <description | path/to/desc.txt | -> [figma-url] [swagger-url]"
    echo "  - '-' 을 입력하면 stdin 에서 읽습니다"
    echo "  - figma-url:   선택사항. feature 이슈에 디자인 스펙을 첨부할 때 사용"
    echo "  - swagger-url: 선택사항. feature 이슈에 API 명세를 첨부할 때 사용"
    exit 1
fi

ISSUE_INPUT="$1"
FIGMA_URL="${2:-}"
SWAGGER_URL="${3:-}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

die() {
    echo "❌ $*" >&2
    exit 1
}

# ──────────────────────────────────────────────
# 입력 확보 (문자열 / 파일 / stdin)
# ──────────────────────────────────────────────

if [[ "$ISSUE_INPUT" == "-" ]]; then
    ISSUE_DESCRIPTION=$(cat)
elif [[ -f "$ISSUE_INPUT" ]]; then
    ISSUE_DESCRIPTION=$(cat "$ISSUE_INPUT")
else
    ISSUE_DESCRIPTION="$ISSUE_INPUT"
fi

[ -n "$ISSUE_DESCRIPTION" ] || die "이슈 설명이 비어있습니다"

# ──────────────────────────────────────────────
# 이슈 분석 → GitHub 등록
# ──────────────────────────────────────────────

echo "📋 이슈 분석 및 GitHub 이슈 생성 중..."

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/scripts/prompts/issue-create.md"
[ -f "$SYSTEM_PROMPT_FILE" ] || die "system prompt 파일이 없습니다: $SYSTEM_PROMPT_FILE"

USER_FILE="$TMPDIR_LOCAL/user.txt"
BODY_FILE="$TMPDIR_LOCAL/issue_body.md"

{
    printf '## 이슈 설명\n%s\n' "$ISSUE_DESCRIPTION"

    printf '\n## Figma URL\n'
    if [ -n "$FIGMA_URL" ]; then
        printf '%s\n' "$FIGMA_URL"
    else
        printf '(제공되지 않음 — feature 이슈라면 참고 자료 섹션에 placeholder 를 남겨두세요)\n'
    fi

    printf '\n## Swagger URL\n'
    if [ -n "$SWAGGER_URL" ]; then
        printf '%s\n' "$SWAGGER_URL"
    else
        printf '(제공되지 않음 — feature 이슈라면 참고 자료 섹션에 placeholder 를 남겨두세요)\n'
    fi

    printf '\n## body file 경로 (gh issue create --body-file 에 사용)\n%s\n' "$BODY_FILE"

    cat <<'EOF'


---
## 최종 리마인더 (응답 직전에 한 번 더 확인)
- 응답 첫 줄은 반드시 `Issue URL: ...` 으로 시작합니다.
- 두 번째 줄은 `Title: ...` 입니다.
- 다른 서문·후문·코드 펜스를 출력하지 않습니다.
EOF
} > "$USER_FILE"

RESULT=$(claude \
    --system-prompt "$(cat "$SYSTEM_PROMPT_FILE")" \
    --allowedTools "Read,Glob,Grep,Bash,WebFetch,WebSearch,mcp__context7__resolve-library-id,mcp__context7__query-docs,mcp__maestro__list_devices,mcp__maestro__start_device,mcp__maestro__launch_app,mcp__maestro__stop_app,mcp__maestro__tap_on,mcp__maestro__input_text,mcp__maestro__take_screenshot,mcp__maestro__inspect_view_hierarchy,mcp__maestro__back,mcp__maestro__run_flow,mcp__maestro__run_flow_files,mcp__maestro__check_flow_syntax,mcp__maestro__cheat_sheet,mcp__maestro__query_docs,mcp__figma__get_design_context,mcp__figma__get_metadata,mcp__figma__get_screenshot,mcp__figma__get_variable_defs,mcp__figma__search_design_system" \
    -p --output-format json \
    "$(cat "$USER_FILE")")

ISSUE_RESULT=$(echo "$RESULT" | jq -r '.result // empty') \
    || die "Claude 응답 파싱 실패"

[ -n "$ISSUE_RESULT" ] || die "이슈 생성 결과가 비어있습니다"

# 서문 자동 제거: 첫 유효 줄(Issue URL:) 부터 시작
ISSUE_RESULT=$(echo "$ISSUE_RESULT" | awk '/^Issue URL:/{found=1} found{print}')

if [ -z "$ISSUE_RESULT" ] || ! echo "$ISSUE_RESULT" | head -1 | grep -qE '^Issue URL:'; then
    die "출력 형식이 올바르지 않습니다. 유효한 시작 줄(Issue URL:)을 찾을 수 없습니다"
fi

echo "$ISSUE_RESULT"
echo "✅ GitHub 이슈 등록 완료"
