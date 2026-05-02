#!/usr/bin/env bash
set -euo pipefail

MAX_ROUNDS="${1:-10}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

die() {
    echo "❌ $*" >&2
    exit 1
}

parse_count() {
    local label="$1"
    local value
    value=$(grep "^${label}:" CODE_REVIEW.md | tail -1 | grep -oE '[0-9]+' | tail -1 || true)
    [[ -n "$value" ]] || die "CODE_REVIEW.md 에서 ${label} 카운트를 파싱하지 못했습니다"
    echo "$value"
}

[ -f "PLAN.md" ]                       || die "PLAN.md 가 없습니다. 먼저 scripts/common/plan_review_loop.sh 등을 실행해 PLAN.md 를 준비하세요"
[ -x "scripts/common/plan-implement.sh" ] || die "scripts/common/plan-implement.sh 가 없거나 실행 권한이 없습니다"
[ -x "scripts/common/code-reviewer.sh" ]  || die "scripts/common/code-reviewer.sh 가 없거나 실행 권한이 없습니다"

# 이전 세션의 잔여 코드 리뷰 제거 (이전 피드백 오염 방지)
rm -f CODE_REVIEW.md

for ((round = 1; round <= MAX_ROUNDS; round++)); do
    echo ""
    echo "=== ROUND ${round} / ${MAX_ROUNDS} ==="

    scripts/common/plan-implement.sh
    scripts/common/code-reviewer.sh

    CRITICAL=$(parse_count "CRITICAL")
    MAJOR=$(parse_count "MAJOR")
    MINOR=$(parse_count "MINOR")

    echo "COUNTS C=${CRITICAL} M=${MAJOR} m=${MINOR}"

    if [[ "$CRITICAL" -le 0 && "$MAJOR" -le 0 && "$MINOR" -le 2 ]]; then
        echo ""
        echo "✅ 코드 리뷰 기준 충족"
        echo ""
        echo "📋 최종 산출물:"
        echo "  - IMPL.md:        $PROJECT_ROOT/IMPL.md"
        echo "  - CODE_REVIEW.md: $PROJECT_ROOT/CODE_REVIEW.md"
        exit 0
    fi
done

echo ""
echo "❌ 최대 반복 횟수(${MAX_ROUNDS}) 내에 코드 리뷰 기준을 충족하지 못했습니다"
echo "  - IMPL.md:        $PROJECT_ROOT/IMPL.md"
echo "  - CODE_REVIEW.md: $PROJECT_ROOT/CODE_REVIEW.md"
exit 1
