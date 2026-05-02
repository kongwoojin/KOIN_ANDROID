#!/usr/bin/env bash
set -euo pipefail

export ANTHROPIC_MODEL="claude-sonnet-4-6"

if [[ -z "${1:-}" ]]; then
    echo "❌ 에러: 이슈 번호를 입력하세요"
    echo "사용법: $0 <issue-number> [--fresh]"
    exit 1
fi

ISSUE_ID="$1"
FRESH=false
for arg in "${@:2}"; do
    [[ "$arg" == "--fresh" ]] && FRESH=true
done
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

die() {
    echo "❌ $*" >&2
    exit 1
}

# ──────────────────────────────────────────────
# GitHub 이슈(refactor) 분석 → PLAN.md 생성
# ──────────────────────────────────────────────

echo "📋 GitHub 이슈(refactor) 분석 중..."

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/scripts/prompts/refactor-plan.md"
[ -f "$SYSTEM_PROMPT_FILE" ] || die "system prompt 파일이 없습니다: $SYSTEM_PROMPT_FILE"

USER_FILE="$TMPDIR_LOCAL/user.txt"

{
    printf '## Issue ID\n%s\n' "$ISSUE_ID"
    printf '\n## 작업 지시\n'
    printf -- '- 위 Issue ID 의 GitHub 이슈를 `gh issue view %s --json title,body,labels,comments` 로 조회해 본문과 댓글을 모두 확인합니다.\n' "$ISSUE_ID"
    printf -- '- 신규 브랜치 명: `refactor/%s` 또는 `refactor/%s-{N}`\n' "$ISSUE_ID" "$ISSUE_ID"
    printf -- '- 이슈 타입은 refactor 로 확정되어 있으며 재분류하지 않습니다.\n'

    if [ "$FRESH" = false ]; then
        if [ -f "PLAN.md" ]; then
            printf '\n## Reference: Previous PLAN.md\n\n'
            cat "PLAN.md"
        fi

        if [ -f "REVIEW.md" ]; then
            printf '\n\n## Reference: REVIEW.md\n\n'
            cat "REVIEW.md"
        fi
    fi

    cat <<'EOF'


---
## 최종 리마인더 (응답 직전에 한 번 더 확인)
- 응답 첫 줄은 반드시 `- Issue Type:` 또는 `# [` 로 시작합니다.
- 서문/펜스/안내 문구 절대 금지. 마크다운 본문만 출력합니다.
EOF
} > "$USER_FILE"

PHASE1_RESULT=$(claude \
    --system-prompt "$(cat "$SYSTEM_PROMPT_FILE")" \
    --allowedTools "Read,Glob,Grep,Bash,mcp__context7__resolve-library-id,mcp__context7__query-docs" \
    -p --output-format json \
    "$(cat "$USER_FILE")")

PLAN_CONTENT=$(echo "$PHASE1_RESULT" | jq -r '.result // empty') \
    || die "Claude 응답 파싱 실패"

[ -n "$PLAN_CONTENT" ] || die "PLAN.md 내용이 비어있습니다"

PLAN_CONTENT=$(echo "$PLAN_CONTENT" | awk '/^- Issue Type:|^# \[/{found=1} found{print}')

if [ -z "$PLAN_CONTENT" ] || ! echo "$PLAN_CONTENT" | head -1 | grep -qE '^- Issue Type:|^# \['; then
    die "출력 형식이 올바르지 않습니다. 유효한 시작 줄을 찾을 수 없습니다"
fi

echo "$PLAN_CONTENT" > PLAN.md
echo "✅ PLAN.md 생성 완료 (refactor)"
