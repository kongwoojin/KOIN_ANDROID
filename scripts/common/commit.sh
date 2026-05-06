#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

die() { echo "❌ $*" >&2; exit 1; }

[ -f "PLAN.md" ] || die "PLAN.md 파일이 없습니다"
[ -f "IMPL.md" ] || die "IMPL.md 파일이 없습니다"

EXCLUDE_PATTERN='^\?\? (PLAN\.md|REVIEW\.md|IMPL\.md|CODE_REVIEW\.md|E2E_TEST|E2E_TMPDIR|run_test\.sh|reviews/|scripts/|local\.properties|\.maestro/|[^/]+\.yaml$)'

# ── 1. 소스 변경 파일 수집 ─────────────────────────────────────────────────
MODIFIED=$(git status --short 2>/dev/null | grep -E '^ M' | awk '{print $2}' || true)
DELETED=$(git status --short  2>/dev/null | grep -E '^ D' | awk '{print $2}' || true)
UNTRACKED=$(git status --short 2>/dev/null \
    | grep '^??' \
    | grep -vE "$EXCLUDE_PATTERN" \
    | awk '{print $2}' \
    | grep -v '/$' || true)
# 이미 staged 된 변경도 포함 (이전 실행 잔여분)
ALREADY_STAGED=$(git status --short 2>/dev/null \
    | grep -E '^[MADRCU][ MADRCU]' \
    | awk '{print $2}' || true)

ALL_FILES=$(printf "%s\n%s\n%s\n%s" \
    "$MODIFIED" "$DELETED" "$UNTRACKED" "$ALREADY_STAGED" \
    | grep -v '^$' | sort -u || true)

if [[ -z "$ALL_FILES" ]]; then
    echo "ℹ️  커밋할 변경사항이 없습니다"
    exit 0
fi

# ── 2. Shell 이 직접 모든 변경을 stage ────────────────────────────────────
[[ -n "$MODIFIED"       ]] && echo "$MODIFIED"  | xargs git add --  2>/dev/null || true
[[ -n "$UNTRACKED"      ]] && echo "$UNTRACKED" | xargs git add --  2>/dev/null || true
[[ -n "$DELETED"        ]] && echo "$DELETED"   | xargs git rm  --  2>/dev/null || true

# ── 3. LLM 에 넘길 컨텍스트 수집 ─────────────────────────────────────────
GIT_DIFF=$(git diff --cached 2>/dev/null || true)
GIT_STATUS=$(git status --short 2>/dev/null \
    | grep -vE "$EXCLUDE_PATTERN" || true)

if [[ -z "$GIT_DIFF" && -z "$GIT_STATUS" ]]; then
    echo "ℹ️  stage 된 변경사항이 없습니다"
    exit 0
fi

PLAN_MD=$(<PLAN.md)
IMPL_MD=$(<IMPL.md)
ISSUE_TYPE=$(grep '^- Issue Type:' PLAN.md | head -1 | grep -oE 'bug|feature|refactor' || echo "chore")

case "$ISSUE_TYPE" in
    bug)      COMMIT_TYPE_HINT="fix" ;;
    feature)  COMMIT_TYPE_HINT="feat 또는 add" ;;
    refactor) COMMIT_TYPE_HINT="refactor" ;;
    *)        COMMIT_TYPE_HINT="chore" ;;
esac

# ── 4. LLM 에 커밋 메시지만 요청 (tool call 없음) ──────────────────────────
read -r -d '' PROMPT <<'EOF' || true
커밋 메시지만 출력하세요. git 명령어 실행 금지. 다른 설명·서문 없이 커밋 메시지 텍스트만 출력합니다.

## 커밋 컨벤션
형식:
type: Subject

Body (선택 — subject 로 충분하면 생략)

type 목록: feat / add / fix / docs / refactor / test / del / chore
이슈 타입 힌트: __COMMIT_TYPE_HINT__
subject: 영어, 첫 글자 대문자, 50자 이내, 마침표 없음
body: 영어, 필요할 때만, subject 와 빈 줄로 구분

## git status --short
```
__GIT_STATUS__
```

## git diff --cached
```diff
__GIT_DIFF__
```

## PLAN.md
__PLAN.md__

## IMPL.md
__IMPL.md__
EOF

PROMPT="${PROMPT//__COMMIT_TYPE_HINT__/$COMMIT_TYPE_HINT}"
PROMPT="${PROMPT//__GIT_STATUS__/$GIT_STATUS}"
PROMPT="${PROMPT//__GIT_DIFF__/$GIT_DIFF}"
PROMPT="${PROMPT//__PLAN.md__/$PLAN_MD}"
PROMPT="${PROMPT//__IMPL.md__/$IMPL_MD}"

echo "📝 커밋 메시지 생성 중... (모델: gemini-2.5-flash-lite)"

COMMIT_MSG=$(gemini \
    -m gemini-2.5-flash-lite \
    -o json \
    -p "$PROMPT" 2>/dev/null \
    | jq -r '.response // empty') \
    || die "Gemini 응답 파싱 실패"

[ -n "$COMMIT_MSG" ] || die "커밋 메시지가 비어있습니다"

# 마크다운 코드펜스 제거
COMMIT_MSG=$(echo "$COMMIT_MSG" | sed '/^```/d')
COMMIT_MSG=$(echo "$COMMIT_MSG" | sed 's/^[[:space:]]*//' | sed '/^$/N;/^\n$/d')

# ── 5. Shell 이 직접 커밋 ─────────────────────────────────────────────────
git commit -m "$COMMIT_MSG"

echo ""
echo "# 커밋 결과"
echo ""
echo "## 생성된 커밋"
echo "- \`$(git --no-pager log --oneline -1)\`"
echo ""
echo "## git log"
git --no-pager log --oneline -5
