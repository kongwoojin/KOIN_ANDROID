#!/usr/bin/env bash
set -euo pipefail

export ANTHROPIC_MODEL="claude-sonnet-4-6"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

die() {
    echo "❌ $*" >&2
    exit 1
}

[ -f "E2E_TEST_PLAN.md" ] || die "E2E_TEST_PLAN.md 파일이 없습니다. 먼저 e2e-test-plan.sh 를 실행하세요"

SKIP=$(grep '^- Skip:' E2E_TEST_PLAN.md | head -1 | grep -oiE 'true|false' || echo "false")
if [[ "$SKIP" == "true" ]]; then
    echo "⏭️  E2E 테스트 구현 스킵 (UI 변경 없음)"
    printf '# E2E 테스트 구현 결과\n\n- Skip: true\n\n## Summary\nUI 변경 없음으로 E2E 테스트 구현을 건너뜁니다.\n' > E2E_TEST_IMPL.md
    exit 0
fi

echo "🎭 Maestro E2E 플로우 구현 중..."

E2E_FLOWS_DIR=$(mktemp -d)
echo "$E2E_FLOWS_DIR" > E2E_TMPDIR.txt

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/scripts/prompts/e2e-test-implement.md"
[ -f "$SYSTEM_PROMPT_FILE" ] || die "system prompt 파일이 없습니다: $SYSTEM_PROMPT_FILE"

USER_FILE="$TMPDIR_LOCAL/user.txt"

{
    printf '## E2E_TEST_PLAN.md\n\n'
    cat E2E_TEST_PLAN.md

    printf '\n\n## 임시 디렉토리\n새 YAML 파일은 반드시 다음 경로에 Write 도구로 작성합니다: %s/\n기존 .maestro/ 파일 수정 금지\n' "$E2E_FLOWS_DIR"

    if [ -f "E2E_TEST_RESULT.md" ]; then
        printf '\n\n## E2E_TEST_RESULT.md (이전 실행 결과 — 실패 원인 반영)\n\n'
        cat E2E_TEST_RESULT.md
    fi

    cat <<'EOF'


---
## 최종 리마인더 (응답 직전에 한 번 더 확인)
- 응답 첫 글자는 반드시 `#` 입니다. `# E2E 테스트 구현 결과` 헤더로 즉시 시작합니다.
- 서문/펜스 금지. 응답 본문을 파일로 저장하지 마세요.
EOF
} > "$USER_FILE"

RESULT=$(claude \
    --system-prompt "$(cat "$SYSTEM_PROMPT_FILE")" \
    --allowedTools "Read,Glob,Grep,Write,Bash,mcp__context7__resolve-library-id,mcp__context7__query-docs,mcp__maestro__check_flow_syntax,mcp__maestro__cheat_sheet,mcp__maestro__query_docs" \
    -p --output-format json \
    "$(cat "$USER_FILE")")

IMPL_CONTENT=$(echo "$RESULT" | jq -r '.result // empty') \
    || die "Claude 응답 파싱 실패"

[ -n "$IMPL_CONTENT" ] || die "E2E 구현 결과가 비어있습니다"

IMPL_CONTENT=$(echo "$IMPL_CONTENT" | awk '/^# E2E 테스트 구현 결과/{found=1} found{print}')

if [ -z "$IMPL_CONTENT" ] || ! echo "$IMPL_CONTENT" | head -1 | grep -q '^# E2E 테스트 구현 결과'; then
    die "출력 형식이 올바르지 않습니다. '# E2E 테스트 구현 결과' 시작 줄을 찾을 수 없습니다"
fi

echo "$IMPL_CONTENT" > E2E_TEST_IMPL.md
echo "✅ E2E_TEST_IMPL.md 생성 완료"
