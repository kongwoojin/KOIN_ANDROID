#!/usr/bin/env bash
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$PROJECT_ROOT"

mkdir -p reviews

KTLINT_LOG="reviews/.lint_ktlint.log"
SPOTLESS_LOG="reviews/.lint_spotless.log"
DETEKT_LOG="reviews/.lint_detekt.log"
ANDROID_LINT_LOG="reviews/.lint_android.log"
LINT_REVIEW="reviews/lint.md"

echo "✅ Lint 체크 실행 (ktlintCheck + spotlessCheck + detekt + lint)..."

./gradlew ktlintCheck > "$KTLINT_LOG" 2>&1
KTLINT_EXIT=$?

./gradlew spotlessCheck --no-configuration-cache > "$SPOTLESS_LOG" 2>&1
SPOTLESS_EXIT=$?

./gradlew detekt --continue > "$DETEKT_LOG" 2>&1
DETEKT_EXIT=$?

./gradlew lint --continue > "$ANDROID_LINT_LOG" 2>&1
ANDROID_LINT_EXIT=$?

KTLINT_VIOLATIONS=$(grep -cE "^[^:[:space:]]+\.kt:[0-9]+:[0-9]+: " "$KTLINT_LOG" 2>/dev/null || echo 0)
KTLINT_VIOLATIONS=${KTLINT_VIOLATIONS:-0}

DETEKT_VIOLATIONS=$(grep -cE "\.kt:[0-9]+:[0-9]+: (error|warning): " "$DETEKT_LOG" 2>/dev/null || echo 0)
DETEKT_VIOLATIONS=${DETEKT_VIOLATIONS:-0}

ANDROID_LINT_ERRORS=$(grep -oE "Lint found [0-9]+ error" "$ANDROID_LINT_LOG" 2>/dev/null | grep -oE "[0-9]+" | awk '{s+=$1} END {print s+0}')
ANDROID_LINT_WARNINGS=$(grep -oE "[0-9]+ warning" "$ANDROID_LINT_LOG" 2>/dev/null | grep -oE "^[0-9]+" | awk '{s+=$1} END {print s+0}')
ANDROID_LINT_ERRORS=${ANDROID_LINT_ERRORS:-0}
ANDROID_LINT_WARNINGS=${ANDROID_LINT_WARNINGS:-0}

{
    echo "# Lint 리뷰"
    echo ""
    echo "## Summary"
    echo "- \`./gradlew ktlintCheck\`:    $([ $KTLINT_EXIT -eq 0 ] && echo "✅ 통과" || echo "❌ 실패")"
    echo "- \`./gradlew spotlessCheck\`: $([ $SPOTLESS_EXIT -eq 0 ] && echo "✅ 통과" || echo "❌ 실패")"
    echo "- \`./gradlew detekt\`:         $([ $DETEKT_EXIT -eq 0 ] && echo "✅ 통과" || echo "❌ 실패")"
    echo "- \`./gradlew lint\`:           $([ $ANDROID_LINT_EXIT -eq 0 ] && echo "✅ 통과" || echo "❌ 실패")"
    echo "- ktlint 위반 건수: $KTLINT_VIOLATIONS"
    echo "- detekt 위반 건수: $DETEKT_VIOLATIONS"
    echo "- Android lint 오류: $ANDROID_LINT_ERRORS, 경고: $ANDROID_LINT_WARNINGS"
    echo ""

    if [[ $KTLINT_EXIT -ne 0 ]]; then
        echo "## 문제점"
        echo ""
        echo "### [MAJOR] ktlintCheck 실패"
        echo "파일 경로: (아래 목록 참고)"
        echo "#### 리뷰 사항"
        echo "ktlint 규칙 위반으로 CI 가 실패합니다. 커밋 전 \`./gradlew ktlintFormat\` 필요."
        echo "#### 위반 내역 (상위 20건)"
        echo '```'
        grep -E "^[^:[:space:]]+\.kt:[0-9]+:[0-9]+: " "$KTLINT_LOG" 2>/dev/null | head -20
        echo '```'
        echo "#### 수정 방향"
        echo "\`./gradlew ktlintFormat\` 을 실행해 자동 수정 가능한 항목을 일괄 처리하고, 남은 위반은 수동 수정."
        echo ""
    fi

    if [[ $SPOTLESS_EXIT -ne 0 ]]; then
        echo "### [MAJOR] spotlessCheck 실패"
        echo "파일 경로: (spotless 보고 참고)"
        echo "#### 리뷰 사항"
        echo "spotless 포맷 위반 — CI 실패. \`./gradlew spotlessApply\` 필요."
        echo "#### 로그 (상위 20줄)"
        echo '```'
        head -20 "$SPOTLESS_LOG"
        echo '```'
        echo "#### 수정 방향"
        echo "\`./gradlew spotlessApply\` 실행."
        echo ""
    fi

    if [[ $DETEKT_EXIT -ne 0 ]]; then
        echo "### [MAJOR] detekt 실패"
        echo "#### 리뷰 사항"
        echo "detekt 규칙 위반으로 CI 가 실패합니다. \`config/detekt.yml\` 기준 위반을 수정해야 합니다."
        echo "#### 위반 내역 (상위 20건)"
        echo '```'
        grep -E "\.kt:[0-9]+:[0-9]+: (error|warning): " "$DETEKT_LOG" 2>/dev/null | head -20
        echo '```'
        echo "#### 수정 방향"
        echo "각 위반 항목의 규칙명을 확인 후 코드 수정 또는 \`@Suppress\` 처리 (불가피한 경우만)."
        echo ""
    fi

    if [[ $ANDROID_LINT_EXIT -ne 0 ]]; then
        echo "### [MAJOR] Android lint 실패"
        echo "#### 리뷰 사항"
        echo "Android lint 오류로 CI 가 실패합니다. 오류 항목을 수정하거나 \`lint.xml\` 에서 억제해야 합니다."
        echo "- 오류: $ANDROID_LINT_ERRORS 건, 경고: $ANDROID_LINT_WARNINGS 건"
        echo "#### 오류 내역 (상위 20줄)"
        echo '```'
        grep -E "Lint found|\.kt:[0-9]+: (Error|Warning):" "$ANDROID_LINT_LOG" 2>/dev/null | head -20
        echo '```'
        echo "#### 수정 방향"
        echo "각 오류 항목을 수정하거나, 의도적 억제는 \`@SuppressLint\` 또는 프로젝트 \`lint.xml\` 에 등록."
        echo ""
    fi

    CRITICAL=0
    MAJOR=0
    MINOR=0
    [[ $KTLINT_EXIT -ne 0 ]] && MAJOR=$((MAJOR + 1))
    [[ $SPOTLESS_EXIT -ne 0 ]] && MAJOR=$((MAJOR + 1))
    [[ $DETEKT_EXIT -ne 0 ]] && MAJOR=$((MAJOR + 1))
    [[ $ANDROID_LINT_EXIT -ne 0 ]] && MAJOR=$((MAJOR + 1))

    # ktlint 위반 1건 이상일 때 추가 MINOR (세부 위반 수에 따른 가중치)
    if [[ $KTLINT_VIOLATIONS -gt 1 ]]; then
        MINOR=$((MINOR + KTLINT_VIOLATIONS - 1))
    fi
    # detekt 위반 1건 이상일 때 추가 MINOR
    if [[ $DETEKT_VIOLATIONS -gt 1 ]]; then
        MINOR=$((MINOR + DETEKT_VIOLATIONS - 1))
    fi
    # Android lint 오류 1건 이상일 때 추가 MINOR
    if [[ $ANDROID_LINT_ERRORS -gt 1 ]]; then
        MINOR=$((MINOR + ANDROID_LINT_ERRORS - 1))
    fi
    # MINOR 은 최대 10 으로 캡 (수치 폭주 방지)
    [[ $MINOR -gt 10 ]] && MINOR=10

    echo "CRITICAL: $CRITICAL"
    echo "MAJOR: $MAJOR"
    echo "MINOR: $MINOR"
} > "$LINT_REVIEW"

echo "✅ reviews/lint.md"

# 항상 exit 0 — 실패 내용은 리뷰 파일에 반영됨 (오케스트레이터가 집계)
exit 0
