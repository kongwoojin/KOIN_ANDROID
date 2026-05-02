#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "❌ 에러: 이슈 번호를 입력하세요"
    echo "사용법: $0 <issue-number> [max-rounds]"
    echo ""
    echo "환경변수:"
    echo "  FRESH=1   E2E_TEST_PLAN.md / E2E_TEST_PLAN_REVIEW.md 를 삭제하고 처음부터 다시 작성"
    echo ""
    echo "예시:"
    echo "  FRESH=1 $0 16"
    echo "  $0 20 5"
    exit 1
fi

ISSUE_ID="$1"
MAX_ROUNDS="${2:-10}"
FRESH="${FRESH:-0}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

die() {
    echo "❌ $*" >&2
    exit 1
}

parse_count() {
    local label="$1"
    local value
    value=$(grep "^${label}:" E2E_TEST_PLAN_REVIEW.md | tail -1 | grep -oE '[0-9]+' | tail -1 || true)
    [[ -n "$value" ]] || die "E2E_TEST_PLAN_REVIEW.md 에서 ${label} 카운트를 파싱하지 못했습니다"
    echo "$value"
}

[ -x "scripts/common/e2e-test-plan.sh" ]          || die "scripts/common/e2e-test-plan.sh 가 없거나 실행 권한이 없습니다"
[ -x "scripts/common/e2e-test-plan-reviewer.sh" ] || die "scripts/common/e2e-test-plan-reviewer.sh 가 없거나 실행 권한이 없습니다"

if [[ "$FRESH" == "1" ]]; then
    rm -f E2E_TEST_PLAN.md E2E_TEST_PLAN_REVIEW.md
fi

for ((round = 1; round <= MAX_ROUNDS; round++)); do
    echo "=== ROUND ${round} / ${MAX_ROUNDS} ==="

    scripts/common/e2e-test-plan.sh "$ISSUE_ID"

    # bug 타입 등으로 E2E 계획이 생성되지 않은 경우
    if [[ ! -f E2E_TEST_PLAN.md ]]; then
        echo "ℹ️  E2E_TEST_PLAN.md 가 생성되지 않음 — 리뷰 루프 종료"
        exit 0
    fi

    SKIP=$(grep '^- Skip:' E2E_TEST_PLAN.md | head -1 | grep -oiE 'true|false' || echo "false")
    if [[ "$SKIP" == "true" ]]; then
        echo "⏭️  E2E_TEST_PLAN.md 가 Skip: true — 리뷰 루프 종료"
        scripts/common/e2e-test-plan-reviewer.sh
        exit 0
    fi

    scripts/common/e2e-test-plan-reviewer.sh

    CRITICAL=$(parse_count "CRITICAL")
    MAJOR=$(parse_count "MAJOR")
    MINOR=$(parse_count "MINOR")

    echo "COUNTS C=${CRITICAL} M=${MAJOR} m=${MINOR}"

    if [[ "$CRITICAL" -le 0 && "$MAJOR" -le 0 && "$MINOR" -le 2 ]]; then
        echo "✅ 기준 충족"
        exit 0
    fi
done

echo "❌ 최대 반복 횟수(${MAX_ROUNDS}) 내에 기준을 충족하지 못했습니다"
exit 1
