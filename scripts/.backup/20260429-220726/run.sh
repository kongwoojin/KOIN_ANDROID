#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "❌ 에러: GitHub 이슈 번호를 입력하세요"
    echo "사용법: $0 <issue-number>"
    echo ""
    echo "동작:"
    echo "  1. GitHub 이슈 타입 분류 (라벨 우선, Claude Haiku fallback)"
    echo "  2. Git 브랜치 준비 (fix|feature|refactor/<issue-id>)"
    echo "  3. Phase 2: scripts/<type>/plan.sh + plan-reviewer.sh 루프 (max 3)"
    echo "  4. Phase 3: plan-implement.sh + code-reviewer.sh 루프 (max 3)"
    echo "  5. Phase 4: E2E 테스트 작성·실행 (feature/refactor 타입만)"
    echo "  6. Phase 5: 커밋 생성 (컨벤션 기반 다중 커밋)"
    echo "  7. Phase 6: PR 생성 (PR 템플릿 기반 GitHub PR)"
    echo ""
    echo "환경변수:"
    echo "  BASE_BRANCH=<branch>  베이스 브랜치 (기본값: develop)"
    echo ""
    echo "예시:"
    echo "  $0 16"
    echo "  BASE_BRANCH=develop $0 16"
    exit 1
fi

ISSUE_ID="$1"
BASE_BRANCH="${BASE_BRANCH:-develop}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

die() {
    echo "❌ $*" >&2
    exit 1
}

[ -x "scripts/common/plan_review_loop.sh" ]      || die "scripts/common/plan_review_loop.sh 가 없거나 실행 권한이 없습니다"
[ -x "scripts/common/implement_review_loop.sh" ] || die "scripts/common/implement_review_loop.sh 가 없거나 실행 권한이 없습니다"
[ -x "scripts/common/e2e-test-plan.sh" ]         || die "scripts/common/e2e-test-plan.sh 가 없거나 실행 권한이 없습니다"
[ -x "scripts/common/e2e-test-implement.sh" ]    || die "scripts/common/e2e-test-implement.sh 가 없거나 실행 권한이 없습니다"
[ -x "scripts/common/e2e-test-run.sh" ]          || die "scripts/common/e2e-test-run.sh 가 없거나 실행 권한이 없습니다"
[ -x "scripts/common/commit.sh" ]               || die "scripts/common/commit.sh 가 없거나 실행 권한이 없습니다"
[ -x "scripts/common/pr.sh" ]                   || die "scripts/common/pr.sh 가 없거나 실행 권한이 없습니다"

# ──────────────────────────────────────────────
# Phase 1: 이슈 타입 분류 (GitHub 라벨 → Claude Haiku fallback)
# ──────────────────────────────────────────────

echo "=== Phase 1: 이슈 타입 분류 ==="

CLASSIFY_PROMPT="GitHub 이슈 ${ISSUE_ID} 를 Bash 도구로 \`gh issue view ${ISSUE_ID} --json title,body,labels\` 로 조회하세요.
1) 이슈의 labels 배열에 다음 중 하나가 있으면 정규화한 한 단어만 소문자로 출력:
   - bug, bugfix → bug
   - feature, feat → feature
   - refactor, refactoring → refactor
2) 위 라벨이 없으면 제목·본문을 읽고 bug, feature, refactor 중 가장 적합한 한 단어만 소문자로 출력.
출력은 정확히 bug, feature, refactor 중 한 단어. 설명·공백·따옴표·줄바꿈 금지."

CLASSIFY_RESULT=$(ANTHROPIC_MODEL="claude-haiku-4-5" claude \
    --allowedTools Bash \
    -p --output-format json \
    "$CLASSIFY_PROMPT")

ISSUE_TYPE=$(echo "$CLASSIFY_RESULT" | jq -r '.result // empty' \
    | tr -d '[:space:]' | tr -d '"' | tr '[:upper:]' '[:lower:]')

echo "📌 분류 결과: ${ISSUE_TYPE:-<empty>}"

case "$ISSUE_TYPE" in
    bug)      PLAN_SCRIPT="scripts/bug/plan.sh";      BRANCH_PREFIX="fix" ;;
    feature)  PLAN_SCRIPT="scripts/feature/plan.sh";  BRANCH_PREFIX="feature" ;;
    refactor) PLAN_SCRIPT="scripts/refactor/plan.sh"; BRANCH_PREFIX="refactor" ;;
    *)        die "알 수 없는 이슈 타입 '$ISSUE_TYPE' — bug / feature / refactor 중 하나여야 합니다" ;;
esac

[ -x "$PLAN_SCRIPT" ] || die "$PLAN_SCRIPT 가 없거나 실행 권한이 없습니다"

# ──────────────────────────────────────────────
# Phase 1.5: Git Worktree 준비
# ──────────────────────────────────────────────

echo ""
echo "=== Git Worktree 준비 ==="

BRANCH="${BRANCH_PREFIX}/${ISSUE_ID}"
ISSUE_ID_LOWER=$(echo "$ISSUE_ID" | tr '[:upper:]' '[:lower:]')
PROJECT_NAME=$(basename "$PROJECT_ROOT")
WORKTREE_DIR="$PROJECT_ROOT/.worktrees/${PROJECT_NAME}-${ISSUE_ID_LOWER}"

# 최신 베이스 브랜치 fetch
echo "🔄 origin/${BASE_BRANCH} fetch 중..."
git fetch origin "$BASE_BRANCH"

if [[ -d "$WORKTREE_DIR" ]]; then
    echo "🔀 기존 worktree 재사용: ${WORKTREE_DIR}"
elif git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    echo "🌿 기존 브랜치 '${BRANCH}' 로 worktree 생성..."
    git worktree add "$WORKTREE_DIR" "$BRANCH"
else
    echo "🌿 새 브랜치 '${BRANCH}' + worktree 생성 (from origin/${BASE_BRANCH})..."
    git worktree add -b "$BRANCH" "$WORKTREE_DIR" "origin/${BASE_BRANCH}"
fi

echo "✅ Branch:   ${BRANCH}"
echo "✅ Worktree: ${WORKTREE_DIR}"

# 이후 모든 작업은 worktree 안에서 실행
cd "$WORKTREE_DIR"

# TODO: scripts/ 가 아직 커밋되지 않았으므로 worktree 에 수동으로 복사.
#       scripts/ 를 develop 브랜치에 커밋한 뒤 이 블록을 제거한다.
if [[ ! -d "scripts" ]]; then
    echo "📂 scripts/ 를 worktree 에 복사 중 (미커밋 상태)..."
    cp -r "$PROJECT_ROOT/scripts" .
fi

# google-services.json 복사 (gitignore 대상이므로 worktree 에 수동 복사)
for GS_SRC in \
    "$PROJECT_ROOT/koin/google-services.json" \
    "$PROJECT_ROOT/koin/src/debug/google-services.json"; do
    GS_REL="${GS_SRC#$PROJECT_ROOT/}"
    GS_DST="$GS_REL"
    if [[ -f "$GS_SRC" && ! -f "$GS_DST" ]]; then
        mkdir -p "$(dirname "$GS_DST")"
        cp "$GS_SRC" "$GS_DST"
        echo "📋 복사: $GS_REL"
    fi
done

# 이전 세션 산출물 초기화
if [[ -f E2E_TMPDIR.txt ]]; then
    OLD_TMPDIR=$(cat E2E_TMPDIR.txt 2>/dev/null || echo "")
    [[ -n "$OLD_TMPDIR" && -d "$OLD_TMPDIR" ]] && rm -rf "$OLD_TMPDIR"
fi
rm -f PLAN.md REVIEW.md IMPL.md CODE_REVIEW.md \
      E2E_TEST_PLAN.md E2E_TEST_IMPL.md E2E_TEST_RESULT.md E2E_TMPDIR.txt

# ──────────────────────────────────────────────
# Phase 2: PLAN 작성(Claude Sonnet) + PLAN 리뷰(Codex) 루프
# ──────────────────────────────────────────────

echo ""
echo "=== Phase 2: PLAN 작성 + 리뷰 루프 ($PLAN_SCRIPT) ==="

FRESH=1 scripts/common/plan_review_loop.sh "$ISSUE_ID" "$PLAN_SCRIPT"

# ──────────────────────────────────────────────
# Phase 3: 구현(Haiku) + 코드 리뷰(Codex) 루프
# ──────────────────────────────────────────────

echo ""
echo "=== Phase 3: 구현 + 코드 리뷰 루프 ==="

PHASE3_EXIT=0
scripts/common/implement_review_loop.sh || PHASE3_EXIT=$?

echo ""
if [[ $PHASE3_EXIT -ne 0 ]]; then
    echo "❌ Phase 3 실패"
fi

# ──────────────────────────────────────────────
# Phase 4: E2E 테스트 (feature/refactor only)
# ──────────────────────────────────────────────

PHASE4_EXIT=0
ISSUE_TYPE_FOR_E2E=$(grep '^- Issue Type:' "$WORKTREE_DIR/PLAN.md" 2>/dev/null \
    | head -1 | grep -oE 'bug|feature|refactor' | head -1 || echo "")

if [[ $PHASE3_EXIT -ne 0 ]]; then
    echo ""
    echo "⏭️  Phase 3 실패 — Phase 4 E2E 테스트 스킵"
elif [[ "$ISSUE_TYPE_FOR_E2E" == "feature" || "$ISSUE_TYPE_FOR_E2E" == "refactor" ]]; then
    echo ""
    echo "=== Phase 4: E2E 테스트 (${ISSUE_TYPE_FOR_E2E}) ==="

    scripts/common/e2e-test-plan.sh "$ISSUE_ID"      || PHASE4_EXIT=$?
    if [[ $PHASE4_EXIT -eq 0 ]]; then
        scripts/common/e2e-test-implement.sh          || PHASE4_EXIT=$?
    fi
    if [[ $PHASE4_EXIT -eq 0 ]]; then
        scripts/common/e2e-test-run.sh                || PHASE4_EXIT=$?
    fi

    echo ""
    if [[ $PHASE4_EXIT -eq 0 ]]; then
        echo "✅ E2E 테스트 완료"
    else
        echo "❌ E2E 테스트 실패"
    fi
fi

# ──────────────────────────────────────────────
# Phase 5: 커밋 생성
# ──────────────────────────────────────────────

PHASE5_EXIT=0
if [[ $PHASE3_EXIT -eq 0 && $PHASE4_EXIT -eq 0 ]]; then
    echo ""
    echo "=== Phase 5: 커밋 생성 ==="
    scripts/common/commit.sh || PHASE5_EXIT=$?
    echo ""
    if [[ $PHASE5_EXIT -ne 0 ]]; then
        echo "❌ 커밋 실패"
    fi
fi

# ──────────────────────────────────────────────
# Phase 6: PR 생성
# ──────────────────────────────────────────────

PHASE6_EXIT=0
if [[ $PHASE3_EXIT -eq 0 && $PHASE4_EXIT -eq 0 && $PHASE5_EXIT -eq 0 ]]; then
    echo ""
    echo "=== Phase 6: PR 생성 ==="
    scripts/common/pr.sh || PHASE6_EXIT=$?
    echo ""
    if [[ $PHASE6_EXIT -ne 0 ]]; then
        echo "❌ PR 생성 실패"
    fi
fi

FINAL_EXIT=$(( PHASE3_EXIT != 0 || PHASE4_EXIT != 0 || PHASE5_EXIT != 0 || PHASE6_EXIT != 0 ? 1 : 0 ))

echo ""
if [[ $FINAL_EXIT -eq 0 ]]; then
    echo "✅ 전체 플로우 완료"
else
    echo "❌ 일부 단계 실패"
fi

echo ""
echo "📋 최종 산출물:"
echo "  - Issue ID:          $ISSUE_ID"
echo "  - Issue Type:        $ISSUE_TYPE"
echo "  - Branch:            $BRANCH"
echo "  - Worktree:          $WORKTREE_DIR"
echo "  - PLAN.md:           $WORKTREE_DIR/PLAN.md"
echo "  - REVIEW.md:         $WORKTREE_DIR/REVIEW.md"
echo "  - IMPL.md:           $WORKTREE_DIR/IMPL.md"
echo "  - CODE_REVIEW.md:    $WORKTREE_DIR/CODE_REVIEW.md"
if [[ "$ISSUE_TYPE_FOR_E2E" == "feature" || "$ISSUE_TYPE_FOR_E2E" == "refactor" ]]; then
    echo "  - E2E_TEST_PLAN.md:   $WORKTREE_DIR/E2E_TEST_PLAN.md"
    echo "  - E2E_TEST_IMPL.md:   $WORKTREE_DIR/E2E_TEST_IMPL.md"
    echo "  - E2E_TEST_RESULT.md: $WORKTREE_DIR/E2E_TEST_RESULT.md"
fi
echo ""
echo "💡 작업 완료 후 worktree 정리:"
echo "   git worktree remove $WORKTREE_DIR"

exit $FINAL_EXIT
