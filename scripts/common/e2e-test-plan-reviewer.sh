#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

die() { echo "❌ $*" >&2; exit 1; }

[ -f "PLAN.md" ]           || die "PLAN.md 가 없습니다"
[ -f "E2E_TEST_PLAN.md" ]  || die "E2E_TEST_PLAN.md 가 없습니다. e2e-test-plan.sh 를 먼저 실행하세요"

SKIP=$(grep '^- Skip:' E2E_TEST_PLAN.md | head -1 | grep -oiE 'true|false' || echo "false")
if [[ "$SKIP" == "true" ]]; then
    echo "⏭️  E2E_TEST_PLAN.md 가 Skip: true — 리뷰 스킵 (placeholder 생성)"
    cat > E2E_TEST_PLAN_REVIEW.md <<'EOF'
# E2E_TEST_PLAN.md 리뷰

## Summary
E2E_TEST_PLAN.md 가 Skip: true — 리뷰를 건너뜁니다.

CRITICAL: 0
MAJOR: 0
MINOR: 0
EOF
    exit 0
fi

read -r -d '' PROMPT <<'EOF' || true
당신은 안드로이드 10년차 시니어 QA 엔지니어입니다.
주니어 QA 가 작성한 E2E_TEST_PLAN.md 를 검토하고, 리뷰해주세요.
Maestro 기반 E2E 테스트 계획이 PLAN.md 의 구현 범위를 충실히 커버하는지, 실행 가능한지 확인합니다.

## 추론·출력 언어
입력이 한글로 작성되었더라도 영어로 사고·분석한 뒤, 최종 응답·산출물은 한글로 출력합니다.

## 검토 영역
1. **시나리오 커버리지** — PLAN.md 의 신규/수정 화면 및 기능 중 핵심 사용자 플로우가 누락 없이 포함됐는가
2. **딥링크 정확성** — `koin://...` 경로가 실제 Navigation 코드(`feature/*/navigation/*.kt`, `Activity` 의 intent-filter)와 일치하는가
3. **Maestro timeout 규칙 준수** — `waitForAnimationToEnd` / `extendedWaitUntil` 최대 15000ms, 30000ms 이상 timeout 금지
4. **Maestro 패턴 일치** — `appId: ${APP_ID}` + `env: APP_ID: in.koreatech.koin` 헤더 패턴, `.maestro/common/launch_app.yaml` 등 기존 패턴 사용 여부
5. **임시 디렉토리 규칙** — 새 플로우는 임시 디렉토리에만 생성, 기존 `.maestro/` 파일 수정 금지가 명시됐는가
6. **assertion 명세** — `assertVisible` 의 텍스트/ID 가 실제 Compose UI 의 `Text(...)` 또는 `testTag` 와 일치하는가

## 규칙
1. 반드시 실제 코드(PLAN.md 가 명시한 화면 코드, 기존 `.maestro/` 플로우, Navigation 코드)를 확인합니다.
2. 반드시 Context7 으로 필요한 최신 문서(Maestro 등)를 확인합니다.
3. 모든 이슈는 CRITICAL, MAJOR, MINOR 순서로 작성합니다.
4. 이슈 갯수를 CRITICAL, MAJOR, MINOR 로 분류하여 마지막에 작성합니다.
5. Output Format 을 준수합니다.
6. PLAN.md 가 다루지 않는 추가 시나리오 제안은 하지 않습니다 (E2E_TEST_PLAN.md 의 범위 = PLAN.md 의 범위).
7. 실제로 테스트 실패를 유발하거나 시나리오 누락을 일으키는 문제만 CRITICAL/MAJOR 로 분류합니다. 단순 표현 차이·선호도는 이슈로 올리지 않습니다.
8. E2E_TEST_PLAN.md 가 이미 인지하고 명시적으로 제외한 사항은 이슈로 올리지 않습니다.

## PLAN.md
__PLAN.md__

## E2E_TEST_PLAN.md
__E2E_TEST_PLAN.md__

## Output Format
```markdown
# E2E_TEST_PLAN.md 리뷰

## Summary
리뷰에 대한 전반적인 요약을 작성합니다.

## 문제점

### [CRITICAL] 1. ~~
파일 경로: feature/xxx/...
#### 리뷰 사항

#### 수정 방향

### [MAJOR] 2. ~~
파일 경로: feature/xxx/...
#### 리뷰 사항

#### 수정 방향

### [MINOR] 3. ~~
파일 경로: feature/xxx/...
#### 리뷰 사항

#### 수정 방향

CRITICAL: 1
MAJOR: 1
MINOR: 1
```
EOF

PLAN_MD=$(<PLAN.md)
E2E_PLAN_MD=$(<E2E_TEST_PLAN.md)

PROMPT=${PROMPT//__PLAN.md__/$PLAN_MD}
PROMPT=${PROMPT//__E2E_TEST_PLAN.md__/$E2E_PLAN_MD}

echo "🎭 E2E_TEST_PLAN 리뷰 실행 (Codex gpt-5.4)..."
codex exec -m gpt-5.4 "$PROMPT" -s read-only --skip-git-repo-check -o "E2E_TEST_PLAN_REVIEW.md"
