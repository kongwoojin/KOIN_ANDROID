#!/usr/bin/env bash
set -euo pipefail

export ANTHROPIC_MODEL="claude-sonnet-4-6"

if [[ -z "${1:-}" ]]; then
    echo "❌ 에러: 이슈 번호를 입력하세요"
    echo "사용법: $0 <issue-id>"
    exit 1
fi

ISSUE_ID="$1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

die() {
    echo "❌ $*" >&2
    exit 1
}

[ -f "PLAN.md" ] || die "PLAN.md 파일이 없습니다"

# 이슈 타입 감지 — bug 이면 스킵
ISSUE_TYPE=$(grep '^- Issue Type:' PLAN.md | head -1 | grep -oE 'bug|feature|refactor' | head -1 || echo "")
case "$ISSUE_TYPE" in
    bug)
        echo "⏭️  bug 타입 — E2E 테스트 계획 스킵"
        exit 0
        ;;
    feature|refactor)
        ;;
    *)
        die "PLAN.md 에서 이슈 타입을 파악할 수 없습니다 (값: '${ISSUE_TYPE:-<empty>}'). feature 또는 refactor 여야 합니다"
        ;;
esac

echo "📋 E2E 테스트 계획 작성 중 (${ISSUE_TYPE})..."

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/scripts/prompts/e2e-test-plan.md"
[ -f "$SYSTEM_PROMPT_FILE" ] || die "system prompt 파일이 없습니다: $SYSTEM_PROMPT_FILE"

USER_FILE="$TMPDIR_LOCAL/user.txt"

{
    printf '## PLAN.md\n\n'
    cat PLAN.md

    if [ -f "E2E_TEST_PLAN.md" ]; then
        printf '\n\n## Reference: Previous E2E_TEST_PLAN.md\n\n'
        cat E2E_TEST_PLAN.md
    fi

    if [ -f "E2E_TEST_PLAN_REVIEW.md" ]; then
        printf '\n\n## Reference: E2E_TEST_PLAN_REVIEW.md\n\n'
        cat E2E_TEST_PLAN_REVIEW.md
    fi

    cat <<'EOF'


---
## 최종 리마인더 (응답 직전에 한 번 더 확인)
- 응답 첫 줄은 반드시 `- Issue Type:` 으로 시작합니다.
- 서문/펜스 금지. 마크다운 본문만 출력합니다.
EOF
} > "$USER_FILE"

RESULT=$(claude \
    --system-prompt "$(cat "$SYSTEM_PROMPT_FILE")" \
    --allowedTools "Read,Glob,Grep,mcp__context7__resolve-library-id,mcp__context7__query-docs,mcp__maestro__cheat_sheet,mcp__maestro__query_docs" \
    -p --output-format json \
    "$(cat "$USER_FILE")")

PLAN_CONTENT=$(echo "$RESULT" | jq -r '.result // empty') \
    || die "Claude 응답 파싱 실패"

[ -n "$PLAN_CONTENT" ] || die "E2E 테스트 계획 내용이 비어있습니다"

PLAN_CONTENT=$(echo "$PLAN_CONTENT" | awk '/^- Issue Type:/{found=1} found{print}')

if [ -z "$PLAN_CONTENT" ] || ! echo "$PLAN_CONTENT" | head -1 | grep -qE '^- Issue Type:'; then
    die "출력 형식이 올바르지 않습니다. 유효한 시작 줄(- Issue Type:)을 찾을 수 없습니다"
fi

echo "$PLAN_CONTENT" > E2E_TEST_PLAN.md

SKIP=$(grep '^- Skip:' E2E_TEST_PLAN.md | head -1 | grep -oiE 'true|false' || echo "false")
if [[ "$SKIP" == "true" ]]; then
    echo "⏭️  UI 변경 없음 — E2E 테스트 계획 스킵"
    exit 0
fi

echo "✅ E2E_TEST_PLAN.md 생성 완료"
