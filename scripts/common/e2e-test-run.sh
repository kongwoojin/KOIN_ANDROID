#!/usr/bin/env bash
set -euo pipefail

export ANTHROPIC_MODEL="claude-haiku-4-5"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

die() {
    echo "❌ $*" >&2
    exit 1
}

[ -f "E2E_TEST_IMPL.md" ] || die "E2E_TEST_IMPL.md 파일이 없습니다. 먼저 e2e-test-implement.sh 를 실행하세요"

SKIP=$(grep '^- Skip:' E2E_TEST_IMPL.md | head -1 | grep -oiE 'true|false' || echo "false")
if [[ "$SKIP" == "true" ]]; then
    echo "⏭️  E2E 테스트 실행 스킵 (UI 변경 없음)"
    printf '# E2E 테스트 실행 결과\n\nUI 변경 없음으로 E2E 테스트를 건너뜁니다.\n\nE2E_PASS: true\n' > E2E_TEST_RESULT.md
    exit 0
fi

echo "🚀 Maestro E2E 테스트 실행 중..."

E2E_FLOWS_DIR=$(cat E2E_TMPDIR.txt 2>/dev/null) \
    || die "E2E_TMPDIR.txt 가 없습니다. e2e-test-implement.sh 를 먼저 실행하세요"
[ -d "$E2E_FLOWS_DIR" ] \
    || die "임시 디렉토리가 없습니다: ${E2E_FLOWS_DIR}"
YAML_FILES=$(find "$E2E_FLOWS_DIR" -name "*.yaml" -type f | sort | tr '\n' ' ')
[ -n "$YAML_FILES" ] \
    || die "임시 디렉토리에 YAML 파일이 없습니다: ${E2E_FLOWS_DIR}"

SYSTEM_PROMPT_FILE="$PROJECT_ROOT/scripts/prompts/e2e-test-run.md"
[ -f "$SYSTEM_PROMPT_FILE" ] || die "system prompt 파일이 없습니다: $SYSTEM_PROMPT_FILE"

USER_FILE="$TMPDIR_LOCAL/user.txt"

{
    printf '## 실행 대상 YAML 파일 (mcp__maestro__run_flow_files 로 실행)\n%s\n' "$YAML_FILES"
    printf '\n## E2E_TEST_IMPL.md\n\n'
    cat E2E_TEST_IMPL.md

    cat <<'EOF'


---
## 최종 리마인더 (응답 직전에 한 번 더 확인)
- 응답 첫 글자는 반드시 `#` 입니다. `# E2E 테스트 실행 결과` 헤더로 즉시 시작합니다.
- 마지막 줄은 반드시 `E2E_PASS: true` 또는 `E2E_PASS: false` 입니다.
- 서문/펜스 금지. 응답 본문을 파일로 저장하지 마세요.
EOF
} > "$USER_FILE"

RESULT=$(claude \
    --system-prompt "$(cat "$SYSTEM_PROMPT_FILE")" \
    --allowedTools "Bash,mcp__maestro__list_devices,mcp__maestro__start_device,mcp__maestro__launch_app,mcp__maestro__stop_app,mcp__maestro__run_flow_files,mcp__maestro__run_flow,mcp__maestro__take_screenshot,mcp__maestro__inspect_view_hierarchy" \
    -p --output-format json \
    "$(cat "$USER_FILE")")

RESULT_CONTENT=$(echo "$RESULT" | jq -r '.result // empty') \
    || die "Claude 응답 파싱 실패"

[ -n "$RESULT_CONTENT" ] || die "E2E 실행 결과가 비어있습니다"

RESULT_CONTENT=$(echo "$RESULT_CONTENT" | awk '/^# E2E 테스트 실행 결과/{found=1} found{print}')

if [ -z "$RESULT_CONTENT" ] || ! echo "$RESULT_CONTENT" | head -1 | grep -q '^# E2E 테스트 실행 결과'; then
    die "출력 형식이 올바르지 않습니다. '# E2E 테스트 실행 결과' 시작 줄을 찾을 수 없습니다"
fi

echo "$RESULT_CONTENT" > E2E_TEST_RESULT.md

E2E_PASS=$(grep '^E2E_PASS:' E2E_TEST_RESULT.md | tail -1 | grep -oiE 'true|false' | tr '[:upper:]' '[:lower:]' || echo "unknown")
echo "✅ E2E_TEST_RESULT.md 생성 완료 (E2E_PASS=${E2E_PASS})"

E2E_FLOWS_DIR_CLEANUP=$(cat E2E_TMPDIR.txt 2>/dev/null || echo "")
if [[ -n "$E2E_FLOWS_DIR_CLEANUP" && -d "$E2E_FLOWS_DIR_CLEANUP" ]]; then
    rm -rf "$E2E_FLOWS_DIR_CLEANUP"
fi
rm -f E2E_TMPDIR.txt
find . -maxdepth 1 -name "*.yaml" -delete 2>/dev/null || true
rm -f run_test.sh 2>/dev/null || true
echo "🧹 임시 파일 정리 완료"

if [[ "$E2E_PASS" != "true" ]]; then
    echo "❌ E2E 테스트 실패 — E2E_TEST_RESULT.md 확인"
    exit 1
fi
