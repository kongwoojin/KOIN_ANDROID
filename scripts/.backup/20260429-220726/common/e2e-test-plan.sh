#!/usr/bin/env bash
set -euo pipefail

export ANTHROPIC_MODEL="claude-sonnet-4-6"

if [[ -z "${1:-}" ]]; then
    echo "❌ 에러: 이슈 번호를 입력하세요"
    echo "사용법: $0 <issue-id>"
    exit 1
fi

ISSUE_ID="$1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

die() {
    echo "❌ $*" >&2
    exit 1
}

[ -f "PLAN.md" ] || die "PLAN.md 파일이 없습니다"

# 이슈 타입 감지 — bug 이면 스킵
ISSUE_TYPE=$(grep '^- Issue Type:' PLAN.md | head -1 | grep -oE 'bug|feature|refactor' | head -1 || echo "")
case "$ISSUE_TYPE" in
    bug)
        echo "⏭️  bug 타입 — E2E 테스트 계획 스킵"
        exit 0
        ;;
    feature|refactor)
        ;;
    *)
        die "PLAN.md 에서 이슈 타입을 파악할 수 없습니다 (값: '${ISSUE_TYPE:-<empty>}'). feature 또는 refactor 여야 합니다"
        ;;
esac

echo "📋 E2E 테스트 계획 작성 중 (${ISSUE_TYPE})..."

PROMPT_FILE="$TMPDIR_LOCAL/prompt.txt"

cat > "$PROMPT_FILE" << 'EOF'
당신은 10년차 안드로이드 QA 엔지니어입니다.
PLAN.md 에 따라 구현될 기능/리팩토링에 대해 Maestro E2E 테스트 계획을 작성합니다.
스크립트가 당신의 응답을 `E2E_TEST_PLAN.md` 로 저장하므로, 파일을 직접 작성하지 말고 최종 마크다운만 출력합니다.

## 추론·출력 언어
입력이 한글로 작성되었더라도 영어로 사고·분석한 뒤, 최종 응답·산출물은 한글로 출력합니다.

## 프로젝트 컨텍스트
- 앱 패키지 ID: `in.koreatech.koin`
- Maestro 플로우 위치: `.maestro/` 디렉토리
- 기존 플로우 패턴: `.maestro/common/launch_app.yaml`, `.maestro/guest/*.yaml` 참조
- 딥링크 패턴: `koin://xxx/activity` (Navigation 코드에서 실제 경로 확인 필수)

## 규칙
1. PLAN.md 의 구현 대상 화면/기능에서 핵심 사용자 플로우 3-5개를 도출합니다.
2. 기존 `.maestro/` 디렉토리의 플로우를 Read 로 읽어 패턴을 참조합니다.
3. Navigation 코드를 Read 로 읽어 실제 딥링크 경로를 확인합니다.
4. PLAN.md 가 Compose UI 화면(Screen.kt, @Composable, feature/ 모듈 UI)을 신규 생성하거나
   수정하는 경우에만 E2E 테스트를 계획합니다. 순수 데이터·도메인·ViewModel 변경이면
   `- Skip: true` 를 출력하고 Skip 이유만 작성한 뒤 멈춥니다.
5. refactor 이슈라면 동작 변경 없음 확인용 회귀 플로우를 작성합니다.
6. 새 플로우 파일 이름만 명시합니다 (경로 제외 — 임시 디렉토리에 저장됨).
   기존 `.maestro/` 파일은 절대 수정하지 않습니다.
7. 반드시 Output Format을 준수합니다.
8. 응답의 첫 줄은 반드시 `- Issue Type:` 으로 시작합니다.

## Maestro timeout 규칙
- waitForAnimationToEnd / extendedWaitUntil: 최대 15000ms
- 그 외 단순 assertion: timeout 설정 불필요
- 30000ms 이상 timeout 사용 금지

## 출력 계약
- 응답 본문은 최종 `E2E_TEST_PLAN.md`에 저장될 순수 마크다운만 포함합니다.
- Code fence 바깥의 서문·후문·메타 코멘트는 출력하지 않습니다.
- 응답 첫 번째 문자부터 즉시 마크다운 내용을 출력합니다.

## Output Format (Skip: false 인 경우)
```markdown
- Issue Type: [feature|refactor]
- Issue ID: [#XX]
- Skip: false

# [#XX] E2E 테스트 계획

## Summary
E2E 테스트 목적 한두 줄 요약

## 대상 화면
- `feature/xxx/.../XxxScreen.kt` → 딥링크: `koin://xxx/activity`

## E2E 플로우 파일 (임시 디렉토리에 저장, 기존 .maestro/ 수정 금지)
### 새로 만들 파일
- `xxx_main.yaml` — 메인 기능 플로우

## 플로우별 시나리오
### xxx_main.yaml
- 단계:
  1. stopApp
  2. openLink: "koin://xxx/activity"
  3. waitForAnimationToEnd (최대 15000ms)
  4. assertVisible: "화면 제목 또는 핵심 텍스트"
  5. ...
- 검증 조건: assertVisible 대상 텍스트/ID 목록
```

## Output Format (Skip: true 인 경우)
```markdown
- Issue Type: [feature|refactor]
- Issue ID: [#XX]
- Skip: true

# [#XX] E2E 테스트 스킵

## Skip 이유
UI 변경 없음 — (구체적인 이유)
```

## PLAN.md
EOF

printf '\n' >> "$PROMPT_FILE"
cat PLAN.md >> "$PROMPT_FILE"

RESULT=$(claude \
    --allowedTools Read,Glob,Grep,\
mcp__context7__resolve-library-id,\
mcp__context7__query-docs,\
mcp__maestro__cheat_sheet,\
mcp__maestro__query_docs \
    -p --output-format json \
    "$(cat "$PROMPT_FILE")")

PLAN_CONTENT=$(echo "$RESULT" | jq -r '.result // empty') \
    || die "Claude 응답 파싱 실패"

[ -n "$PLAN_CONTENT" ] || die "E2E 테스트 계획 내용이 비어있습니다"

PLAN_CONTENT=$(echo "$PLAN_CONTENT" | awk '/^- Issue Type:/{found=1} found{print}')

if [ -z "$PLAN_CONTENT" ] || ! echo "$PLAN_CONTENT" | head -1 | grep -qE '^- Issue Type:'; then
    die "출력 형식이 올바르지 않습니다. 유효한 시작 줄(- Issue Type:)을 찾을 수 없습니다"
fi

echo "$PLAN_CONTENT" > E2E_TEST_PLAN.md

SKIP=$(grep '^- Skip:' E2E_TEST_PLAN.md | head -1 | grep -oiE 'true|false' || echo "false")
if [[ "$SKIP" == "true" ]]; then
    echo "⏭️  UI 변경 없음 — E2E 테스트 계획 스킵"
    exit 0
fi

echo "✅ E2E_TEST_PLAN.md 생성 완료"
