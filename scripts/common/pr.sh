#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

die() {
    echo "❌ $*" >&2
    exit 1
}

[ -f "PLAN.md" ] || die "PLAN.md 파일이 없습니다"
[ -f "IMPL.md" ] || die "IMPL.md 파일이 없습니다"
[ -f ".github/PULL_REQUEST_TEMPLATE.md" ] || die ".github/PULL_REQUEST_TEMPLATE.md 가 없습니다"

# 미커밋 변경 경고
UNCOMMITTED=$(git status --short 2>/dev/null || true)
if [[ -n "$UNCOMMITTED" ]]; then
    echo "⚠️  미커밋 변경사항이 있습니다. 먼저 scripts/common/commit.sh 를 실행하세요."
    echo "$UNCOMMITTED"
    echo ""
fi

# 컨텍스트 수집
PLAN_MD=$(<PLAN.md)
IMPL_MD=$(<IMPL.md)
PR_TEMPLATE=$(<.github/PULL_REQUEST_TEMPLATE.md)
GIT_LOG=$(git log origin/develop..HEAD --oneline 2>/dev/null || git log --oneline -10 2>/dev/null || true)
GIT_STAT=$(git diff origin/develop...HEAD --stat 2>/dev/null || git diff HEAD~1..HEAD --stat 2>/dev/null || true)
[ -n "$GIT_LOG"  ] || GIT_LOG="(커밋 없음)"
[ -n "$GIT_STAT" ] || GIT_STAT="(변경 통계 없음)"

read -r -d '' PROMPT <<'EOF' || true
당신은 KOIN Android 프로젝트의 PR 작성 에이전트입니다.
아래 컨텍스트를 바탕으로 GitHub Pull Request 제목과 본문을 작성하세요.

## 추론·출력 언어
영어로 사고·분석한 뒤, 최종 응답·산출물(PR 제목 포함)은 한글로 출력합니다.

## 작업 규칙
1. PR 제목은 리포지터리 컨벤션 형식 (`[Type] 한글 설명`):
   - Type (대문자 시작): Fix / Feature / Refactor / Chore / Docs
   - 설명: 한글, 간결하게 핵심 변경사항 요약, 마침표 없음
   - 예시: `[Fix] 공지사항 Toolbar 검색 아이콘이 표시되지 않는 문제 수정`
   - 예시: `[Feature] 콜밴팟 알림 설정 추가`
   - 예시: `[Refactor] Deeplink path prefix 수정`
   - 예시: `[Chore] Android Support Library 제거`
2. PR 본문은 아래 PR_TEMPLATE 구조를 **그대로 유지**하며 내용을 채웁니다:
   - `이슈 번호`: PLAN.md 에서 추출한 GitHub 이슈 번호 (예: `#19`)
   - `작업사항`: 이슈 타입에 맞는 항목만 `[x]` 체크 (나머지 `[ ]` 유지)
     - bug → `[x] 버그 수정`
     - feature → `[x] 신규 기능`
     - refactor → `[x] 리팩토링 (기능 수정 X, API 수정 X)`
   - `작업사항의 상세한 설명`: IMPL.md 기반으로 핵심 변경사항 작성
   - `논의 사항`: 특이한 설계 결정이나 트레이드오프가 있으면 작성, 없으면 "(없음)"
   - `스크린샷`: "(UI 변경 없음)" 또는 실제 변경 설명
   - `추가내용`: develop 브랜치 타겟이면 첫 번째 `[x]` 체크
3. PR 체크리스트는 항상 모두 `[x]` 체크 (AI가 컨벤션·lint·assignee 처리했으므로)
4. 서문·설명 없이 아래 출력 형식만 출력합니다.

## 출력 형식 (반드시 이 구조만 출력)
```
PR_TITLE: [Type] 한글 설명
---BODY---
<PR 본문 — 템플릿 구조 유지>
---END---
```

## PR_TEMPLATE
__PR_TEMPLATE__

## PLAN.md
__PLAN.md__

## IMPL.md
__IMPL.md__

## Git Log (origin/develop..HEAD)
```
__GIT_LOG__
```

## Git Diff Stat
```
__GIT_STAT__
```
EOF

PROMPT="${PROMPT//__PR_TEMPLATE__/$PR_TEMPLATE}"
PROMPT="${PROMPT//__PLAN.md__/$PLAN_MD}"
PROMPT="${PROMPT//__IMPL.md__/$IMPL_MD}"
PROMPT="${PROMPT//__GIT_LOG__/$GIT_LOG}"
PROMPT="${PROMPT//__GIT_STAT__/$GIT_STAT}"

echo "📝 PR 작성 중... (모델: gemini-2.5-flash-lite)"

RESULT=$(gemini \
    -m gemini-2.5-flash-lite \
    -o json \
    -p "$PROMPT" 2>/dev/null)

PR_RAW=$(echo "$RESULT" | jq -r '.response // empty') \
    || die "Gemini 응답 파싱 실패"

[ -n "$PR_RAW" ] || die "Gemini 응답이 비어있습니다"

PR_TITLE=$(echo "$PR_RAW" | grep '^PR_TITLE:' | head -1 | sed 's/^PR_TITLE: //' || true)
PR_BODY=$(echo "$PR_RAW" | sed -n '/^---BODY---/,/^---END---/p' | sed '1d;$d' || true)

[ -n "$PR_TITLE" ] || die "PR 제목을 파싱할 수 없습니다"
[ -n "$PR_BODY"  ] || die "PR 본문을 파싱할 수 없습니다"

echo "⬆️  브랜치 push 중..."
git push -u origin HEAD

echo "🚀 PR 생성 중..."

PR_URL=$(gh pr create \
    --title "$PR_TITLE" \
    --body "$PR_BODY" \
    --base develop \
    --assignee @me)

echo ""
echo "✅ PR 생성 완료"
echo "   $PR_URL"
