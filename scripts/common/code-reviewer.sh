#!/usr/bin/env bash
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

die() {
    echo "❌ $*" >&2
    exit 1
}

[ -f "PLAN.md" ] || die "PLAN.md 파일이 없습니다"
[ -f "IMPL.md" ] || die "IMPL.md 파일이 없습니다. 먼저 plan-implement.sh 를 실행하세요"

for s in security compose kotlin lint sonarqube completeness; do
    [ -x "scripts/common/code-review/${s}.sh" ] || die "scripts/common/code-review/${s}.sh 가 없거나 실행 권한이 없습니다"
done

mkdir -p reviews
rm -f reviews/security.md reviews/compose.md reviews/kotlin.md reviews/lint.md reviews/sonarqube.md reviews/completeness.md reviews/.*.log

echo "🔍 6개 리뷰 병렬 실행 (security, compose, kotlin, lint, sonarqube, completeness)..."

scripts/common/code-review/security.sh     > reviews/.security.log     2>&1 &
PID_SEC=$!
scripts/common/code-review/compose.sh      > reviews/.compose.log      2>&1 &
PID_COMP=$!
scripts/common/code-review/kotlin.sh       > reviews/.kotlin.log       2>&1 &
PID_KT=$!
scripts/common/code-review/lint.sh         > reviews/.lint.log         2>&1 &
PID_LINT=$!
scripts/common/code-review/sonarqube.sh    > reviews/.sonarqube.log    2>&1 &
PID_SONAR=$!
scripts/common/code-review/completeness.sh > reviews/.completeness.log 2>&1 &
PID_COMP2=$!

FAIL=0
wait $PID_SEC   || { echo "❌ Security 리뷰 실패 (로그: reviews/.security.log)";       FAIL=1; }
wait $PID_COMP  || { echo "❌ Compose 리뷰 실패 (로그: reviews/.compose.log)";         FAIL=1; }
wait $PID_KT    || { echo "❌ Kotlin 리뷰 실패 (로그: reviews/.kotlin.log)";           FAIL=1; }
wait $PID_LINT  || { echo "❌ Lint 리뷰 실패 (로그: reviews/.lint.log)";               FAIL=1; }
wait $PID_SONAR || { echo "❌ SonarQube 리뷰 실패 (로그: reviews/.sonarqube.log)";     FAIL=1; }
wait $PID_COMP2 || { echo "❌ Completeness 리뷰 실패 (로그: reviews/.completeness.log)"; FAIL=1; }

[ $FAIL -eq 0 ] || die "일부 리뷰가 실패했습니다. 위 로그 확인"

# ──────────────────────────────────────────────
# 집계
# ──────────────────────────────────────────────

parse_count() {
    local file="$1"
    local label="$2"
    local value
    value=$(grep "^${label}:" "$file" 2>/dev/null | tail -1 | grep -oE '[0-9]+' | tail -1 || true)
    echo "${value:-0}"
}

for f in reviews/security.md reviews/compose.md reviews/kotlin.md reviews/lint.md reviews/sonarqube.md reviews/completeness.md; do
    [ -f "$f" ] || die "서브 리뷰 파일이 생성되지 않음: $f"
done

SEC_C=$(parse_count reviews/security.md CRITICAL)
SEC_M=$(parse_count reviews/security.md MAJOR)
SEC_m=$(parse_count reviews/security.md MINOR)
COMP_C=$(parse_count reviews/compose.md CRITICAL)
COMP_M=$(parse_count reviews/compose.md MAJOR)
COMP_m=$(parse_count reviews/compose.md MINOR)
KT_C=$(parse_count reviews/kotlin.md CRITICAL)
KT_M=$(parse_count reviews/kotlin.md MAJOR)
KT_m=$(parse_count reviews/kotlin.md MINOR)
LINT_C=$(parse_count reviews/lint.md CRITICAL)
LINT_M=$(parse_count reviews/lint.md MAJOR)
LINT_m=$(parse_count reviews/lint.md MINOR)
SONAR_C=$(parse_count reviews/sonarqube.md CRITICAL)
SONAR_M=$(parse_count reviews/sonarqube.md MAJOR)
SONAR_m=$(parse_count reviews/sonarqube.md MINOR)
COMPLETE_C=$(parse_count reviews/completeness.md CRITICAL)
COMPLETE_M=$(parse_count reviews/completeness.md MAJOR)
COMPLETE_m=$(parse_count reviews/completeness.md MINOR)

TOTAL_C=$((SEC_C + COMP_C + KT_C + LINT_C + SONAR_C + COMPLETE_C))
TOTAL_M=$((SEC_M + COMP_M + KT_M + LINT_M + SONAR_M + COMPLETE_M))
TOTAL_m=$((SEC_m + COMP_m + KT_m + LINT_m + SONAR_m + COMPLETE_m))

{
    echo "# 코드 리뷰 (통합)"
    echo ""
    echo "## 요약"
    echo ""
    echo "| 영역 | CRITICAL | MAJOR | MINOR |"
    echo "|---|---|---|---|"
    echo "| 🔒 Security  | $SEC_C   | $SEC_M   | $SEC_m   |"
    echo "| 🎨 Compose   | $COMP_C  | $COMP_M  | $COMP_m  |"
    echo "| 🔵 Kotlin    | $KT_C    | $KT_M    | $KT_m    |"
    echo "| ✅ Lint      | $LINT_C  | $LINT_M  | $LINT_m  |"
    echo "| 🔎 SonarQube | $SONAR_C | $SONAR_M | $SONAR_m |"
    echo "| 📋 Completeness | $COMPLETE_C | $COMPLETE_M | $COMPLETE_m |"
    echo "| **합계**     | **$TOTAL_C** | **$TOTAL_M** | **$TOTAL_m** |"
    echo ""
    echo "---"
    echo ""
    echo "## 🔒 Security"
    echo ""
    cat reviews/security.md
    echo ""
    echo "---"
    echo ""
    echo "## 🎨 Compose"
    echo ""
    cat reviews/compose.md
    echo ""
    echo "---"
    echo ""
    echo "## 🔵 Kotlin"
    echo ""
    cat reviews/kotlin.md
    echo ""
    echo "---"
    echo ""
    echo "## ✅ Lint"
    echo ""
    cat reviews/lint.md
    echo ""
    echo "---"
    echo ""
    echo "## 🔎 SonarQube"
    echo ""
    cat reviews/sonarqube.md
    echo ""
    echo "---"
    echo ""
    echo "## 📋 Completeness"
    echo ""
    cat reviews/completeness.md
    echo ""
    echo "---"
    echo ""
    echo "CRITICAL: $TOTAL_C"
    echo "MAJOR: $TOTAL_M"
    echo "MINOR: $TOTAL_m"
} > CODE_REVIEW.md

echo ""
echo "✅ CODE_REVIEW.md 생성 완료 (통합)"
echo "   C=$TOTAL_C  M=$TOTAL_M  m=$TOTAL_m (completeness: C=$COMPLETE_C M=$COMPLETE_M m=$COMPLETE_m)"
