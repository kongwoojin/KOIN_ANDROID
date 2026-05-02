#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" || -z "${2:-}" ]]; then
    echo "❌ 에러: 이슈 번호와 plan 스크립트 경로를 입력하세요"
    echo "사용법: $0 <issue-number> <plan-script-path> [max-rounds]"
    echo ""
    echo "환경변수:"
    echo "  FRESH=1   PLAN.md / REVIEW.md 를 삭제하고 처음부터 다시 작성"
    echo ""
    echo "예시:"
    echo "  FRESH=1 $0 16 scripts/bug/plan.sh"
    echo "  $0 20 scripts/feature/plan.sh 5"
    exit 1
fi

ISSUE_ID="$1"
PLAN_SCRIPT="$2"
MAX_ROUNDS="${3:-10}"
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
    value=$(grep "^${label}:" REVIEW.md | tail -1 | grep -oE '[0-9]+' | tail -1 || true)
    [[ -n "$value" ]] || die "REVIEW.md에서 ${label} 카운트를 파싱하지 못했습니다"
    echo "$value"
}

[ -x "$PLAN_SCRIPT" ]           || die "plan 스크립트가 없거나 실행 권한이 없습니다: $PLAN_SCRIPT"
[ -x "scripts/common/plan-reviewer.sh" ] || die "scripts/common/plan-reviewer.sh 가 없거나 실행 권한이 없습니다"

if [[ "$FRESH" == "1" ]]; then
    rm -f PLAN.md REVIEW.md
fi

for ((round = 1; round <= MAX_ROUNDS; round++)); do
    echo "=== ROUND ${round} / ${MAX_ROUNDS} ==="

    if [[ $round -eq 1 && "$FRESH" == "1" ]]; then
        "$PLAN_SCRIPT" "$ISSUE_ID" --fresh
    else
        "$PLAN_SCRIPT" "$ISSUE_ID"
    fi

    scripts/common/plan-reviewer.sh

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
