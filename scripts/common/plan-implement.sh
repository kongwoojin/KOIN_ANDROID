#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

die() {
    echo "❌ $*" >&2
    exit 1
}

[ -f "PLAN.md" ] || die "PLAN.md 파일이 없습니다"

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/scripts/prompts/plan-implement.md"
[ -f "$SYSTEM_PROMPT_FILE" ] || die "system prompt 파일이 없습니다: $SYSTEM_PROMPT_FILE"

USER_FILE="$TMPDIR_LOCAL/user.txt"

# ──────────────────────────────────────────────
# user 메시지 구성 (동적 데이터 + 최종 리마인더만)
# ──────────────────────────────────────────────

{
    printf '## PLAN.md\n\n'
    cat PLAN.md

    if [ -f "REVIEW.md" ]; then
        printf '\n\n## REVIEW.md (PLAN 리뷰 — 반영 대상)\n\n'
        cat REVIEW.md
    fi

    if [ -f "CODE_REVIEW.md" ]; then
        printf '\n\n## CODE_REVIEW.md (이전 구현 리뷰 — 반드시 반영)\n\n'
        cat CODE_REVIEW.md
    fi

    # 브랜치 전체 누적 변경 파일 목록 주입 (IMPL.md 정합성 확보)
    GIT_DIFF_FILES=$(git diff HEAD --name-only 2>/dev/null || true)
    if [[ -n "$GIT_DIFF_FILES" ]]; then
        printf '\n\n## 브랜치 전체 변경 파일 목록 (git diff origin/develop...HEAD)\n'
        printf 'IMPL.md의 '"'"'수정한 파일'"'"'·'"'"'새로 만든 파일'"'"' 섹션은 아래 **전체 목록을 기준**으로 작성하세요.\n'
        printf '이번 라운드에서 건드리지 않은 파일도 이전 라운드에서 변경됐다면 반드시 포함해야 합니다.\n'
        printf '```\n%s\n```\n' "$GIT_DIFF_FILES"
    fi

    cat <<'EOF'


---
## 최종 리마인더 (응답 직전에 한 번 더 확인)
- 모든 Edit/Write/Bash 호출을 마쳤다면, 이제 stdout 에 **`# 구현 결과`** 헤더로 시작하는 마크다운만 출력합니다.
- 서문 절대 금지. `#` 가 첫 글자가 아니면 die 처리되어 같은 라운드가 다시 실행됩니다.
- 응답을 ```markdown 으로 감싸지 마세요. 헤더부터 곧바로 출력합니다.
EOF
} > "$USER_FILE"

# ──────────────────────────────────────────────
# 구현 실행
# ──────────────────────────────────────────────

echo "🛠️  PLAN.md 에 따라 코드 구현 중... (모델: claude-haiku-4-5-20251001)"

RESULT=$(ANTHROPIC_MODEL="claude-haiku-4-5-20251001" claude \
    --dangerously-skip-permissions \
    --system-prompt "$(cat "$SYSTEM_PROMPT_FILE")" \
    --allowedTools "Edit,Write,Read,Bash,Glob,Grep,mcp__context7__query-docs,mcp__context7__resolve-library-id" \
    -p --output-format json \
    "$(cat "$USER_FILE")" 2>/dev/null)

IMPL_RESULT=$(echo "$RESULT" | jq -r '.result // empty') \
    || die "Claude 응답 파싱 실패"

[ -n "$IMPL_RESULT" ] || die "구현 결과가 비어있습니다"

# 서문 자동 제거: 첫 유효 줄(# 구현 결과) 부터 시작
IMPL_RESULT=$(echo "$IMPL_RESULT" | awk '/^# 구현 결과/{found=1} found{print}')

# 출력 포맷 검증
if [ -z "$IMPL_RESULT" ] || ! echo "$IMPL_RESULT" | head -1 | grep -q '^# 구현 결과'; then
    die "출력 형식이 올바르지 않습니다. '# 구현 결과' 시작 줄을 찾을 수 없습니다"
fi

echo "$IMPL_RESULT" > IMPL.md
echo "✅ 구현 완료 — 요약은 IMPL.md 참고"
