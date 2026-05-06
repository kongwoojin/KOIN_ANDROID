#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "❌ 에러: GitHub 이슈 번호를 입력하세요"
    echo "사용법: $0 <issue-number>"
    echo ""
    echo "동작:"
    echo "  1. 산출물 파일을 분석해 실패한 단계를 자동 감지"
    echo "  2. 해당 단계부터 횟수를 초기화해 재시작"
    echo "  3. 이후 단계를 순서대로 계속 실행"
    exit 1
fi

ISSUE_ID="$1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISSUE_ID_LOWER=$(echo "$ISSUE_ID" | tr '[:upper:]' '[:lower:]')
PROJECT_NAME=$(basename "$PROJECT_ROOT")
WORKTREE_DIR="$PROJECT_ROOT/.worktrees/${PROJECT_NAME}-${ISSUE_ID_LOWER}"

die() { echo "❌ $*" >&2; exit 1; }

[[ -d "$WORKTREE_DIR" ]] || die "워크트리가 없습니다: $WORKTREE_DIR (먼저 scripts/run.sh $ISSUE_ID 를 실행하세요)"
[[ -f "$WORKTREE_DIR/PLAN.md" ]] || die "PLAN.md 가 없습니다. Phase 2 이전에 실패했습니다. scripts/run.sh $ISSUE_ID 를 실행하세요"

cd "$WORKTREE_DIR"

parse_count() {
    local file="$1" label="$2"
    grep "^${label}:" "$file" 2>/dev/null | tail -1 | grep -oE '[0-9]+' | tail -1 || echo 0
}

detect_failed_phase() {
    local c m

    if [[ ! -f REVIEW.md ]]; then echo 2; return; fi
    c=$(parse_count REVIEW.md CRITICAL); m=$(parse_count REVIEW.md MAJOR)
    if [[ "$c" -gt 0 || "$m" -gt 0 ]]; then echo 2; return; fi

    if [[ ! -f CODE_REVIEW.md ]]; then echo 3; return; fi
    c=$(parse_count CODE_REVIEW.md CRITICAL); m=$(parse_count CODE_REVIEW.md MAJOR)
    if [[ "$c" -gt 0 || "$m" -gt 0 ]]; then echo 3; return; fi

    local issue_type
    issue_type=$(grep '^- Issue Type:' PLAN.md | head -1 | grep -oE 'bug|feature|refactor' | head -1 || echo bug)
    # if [[ "$issue_type" == "feature" || "$issue_type" == "refactor" ]]; then
    #     local e2e_skip="false"
    #     if [[ -f E2E_TEST_PLAN.md ]]; then
    #         e2e_skip=$(grep '^- Skip:' E2E_TEST_PLAN.md | head -1 | grep -oiE 'true|false' | tr '[:upper:]' '[:lower:]' || echo "false")
    #     fi
    #
    #     if [[ "$e2e_skip" != "true" ]]; then
    #         if [[ ! -f E2E_TEST_PLAN.md ]]; then echo 4; return; fi
    #         if [[ ! -f E2E_TEST_PLAN_REVIEW.md ]]; then echo 4; return; fi
    #         c=$(parse_count E2E_TEST_PLAN_REVIEW.md CRITICAL); m=$(parse_count E2E_TEST_PLAN_REVIEW.md MAJOR)
    #         if [[ "$c" -gt 0 || "$m" -gt 0 ]]; then echo 4; return; fi
    #
    #         if [[ ! -f E2E_TEST_RESULT.md ]]; then echo 4; return; fi
    #         local e2e_pass
    #         e2e_pass=$(grep '^E2E_PASS:' E2E_TEST_RESULT.md | tail -1 | grep -oiE 'true|false' | tr '[:upper:]' '[:lower:]' || echo false)
    #         [[ "$e2e_pass" == "true" ]] || { echo 4; return; }
    #     fi
    # fi

    # Phase 5: 추적된 파일 중 미커밋 변경사항 존재
    if git status --short | grep -qvE '^\?\?'; then echo 5; return; fi

    # Phase 6: develop 보다 앞선 커밋이 있으나 PR이 없음
    local commits_ahead
    commits_ahead=$(git log origin/develop..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$commits_ahead" -gt 0 ]]; then
        local current_branch
        current_branch=$(git branch --show-current)
        local pr_count
        pr_count=$(gh pr list --head "$current_branch" --state open --json number --jq 'length' 2>/dev/null || echo 0)
        if [[ "$pr_count" -eq 0 ]]; then echo 6; return; fi
    fi

    echo done
}

ISSUE_TYPE=$(grep '^- Issue Type:' PLAN.md | head -1 | grep -oE 'bug|feature|refactor' | head -1)
PLAN_SCRIPT="scripts/${ISSUE_TYPE}/plan.sh"
FAILED_PHASE=$(detect_failed_phase)

echo "🔍 감지된 실패 단계: Phase ${FAILED_PHASE}"

run_phase2() {
    echo ""
    echo "=== Phase 2: PLAN 작성 + 리뷰 루프 (횟수 초기화) ==="
    scripts/common/plan_review_loop.sh "$ISSUE_ID" "$PLAN_SCRIPT"
}

run_phase3() {
    echo ""
    echo "=== Phase 3: 구현 + 코드 리뷰 루프 (횟수 초기화) ==="
    scripts/common/implement_review_loop.sh
}

# run_phase4() {
#     echo ""
#     echo "=== Phase 4: E2E 테스트 (계획 리뷰 루프 횟수 초기화) ==="
#     scripts/common/e2e_test_plan_review_loop.sh "$ISSUE_ID"
#     scripts/common/e2e-test-implement.sh
#     scripts/common/e2e-test-run.sh
# }

run_phase5() {
    echo ""
    echo "=== Phase 5: 커밋 생성 ==="
    scripts/common/commit.sh
}

run_phase6() {
    echo ""
    echo "=== Phase 6: PR 생성 ==="
    scripts/common/pr.sh
}

case "$FAILED_PHASE" in
    2)
        run_phase2
        run_phase3
        # [[ "$ISSUE_TYPE" == "feature" || "$ISSUE_TYPE" == "refactor" ]] && run_phase4
        run_phase5
        run_phase6
        ;;
    3)
        run_phase3
        # [[ "$ISSUE_TYPE" == "feature" || "$ISSUE_TYPE" == "refactor" ]] && run_phase4
        run_phase5
        run_phase6
        ;;
    4)
        # run_phase4
        run_phase5
        run_phase6
        ;;
    5)
        run_phase5
        run_phase6
        ;;
    6)
        run_phase6
        ;;
    done)
        echo "✅ 모든 단계가 이미 성공 상태입니다. 재시작할 단계가 없습니다."
        exit 0
        ;;
    *)
        die "예상치 못한 감지 결과: $FAILED_PHASE"
        ;;
esac
