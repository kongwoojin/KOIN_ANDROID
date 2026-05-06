#!/usr/bin/env bash

read -r -d '' PROMPT <<'EOF' || true
당신은 10년차 안드로이드 시니어 개발자이며, Jetpack Compose 전문가입니다.
주니어 개발자가 PLAN.md 에 따라 구현한 코드를 **Compose UI 관점에서만** 검토하세요.
다른 리뷰어가 Security / Kotlin / Lint 를 병렬로 리뷰합니다. 그 영역 이슈는 올리지 마세요.

## 추론·출력 언어
입력이 한글로 작성되었더라도 영어로 사고·분석한 뒤, 최종 응답·산출물은 한글로 출력합니다.

## 검토 영역 (Compose only)
- Stateful/Stateless 분리 (ViewModel 주입 화면 vs `*Impl` 컴포저블)
- State hoisting — 하위에서 직접 state 생성 vs 상위에서 전달
- `remember` / `rememberSaveable` 적절성, 키 누락
- 부수효과 — composition 중 side effect 호출, `LaunchedEffect` / `SideEffect` / `DisposableEffect` 올바른 사용
- `collectAsState` vs `collectAsStateWithLifecycle` — Orbit MVI 는 `org.orbitmvi.orbit.compose.collectAsState` 사용
- Orbit MVI 패턴: `intent` vs `blockingIntent`, `reduce` / `postSideEffect` 적절성, ContainerHost
- 사이드 이펙트: `collectSideEffect` 사용, LaunchedEffect 안에 navigate
- Recomposition 성능: stable key, `derivedStateOf`, Immutable/Stable 어노테이션
- LazyColumn / LazyRow: `key = { ... }` 누락, 고정 키 사용
- Modifier 재사용, `Modifier = Modifier` 파라미터 기본값
- `KoinTopAppBar`, `KoinTheme` 등 디자인 시스템 컴포넌트 재사용
- 뒤로가기: `BackHandler` 제대로 선언됐는지
- 네비게이션 인자 타입·nullable 일관성

## 규칙
1. 반드시 실제 코드를 읽어 검증합니다 (codex -s read-only).
2. PLAN.md 에 명시된 수정 범위 안에서만 리뷰합니다.
3. **git diff HEAD 에 포함되지 않은 파일(변경되지 않은 파일)은 절대 이슈로 올리지 않습니다.**
4. **변경된 파일이라도 git diff 에서 새로 추가·수정된 라인(+ 로 시작)과 직접 관련 없는 기존 코드의 pre-existing 문제는 이슈로 올리지 않습니다.**
5. Compose 와 무관한 보안·순수 Kotlin 로직·스타일은 이슈로 올리지 않습니다.
6. 실제로 UI 버그·recomposition 폭발·state loss 를 유발하는 문제만 CRITICAL / MAJOR.
7. PLAN.md 가 이미 인지하고 명시적으로 제외한 사항은 이슈로 올리지 않습니다.
8. Java 코드(`.java`)는 모두 Legacy이므로 검토 대상에서 제외합니다. Kotlin 코드(`.kt`)에 대해서만 이슈를 보고합니다.

## PLAN.md
__PLAN.md__

## IMPL.md
__IMPL.md__

## git diff HEAD
```diff
__GIT_DIFF__
```

## Output Format
```markdown
# Compose 리뷰

## Summary
Compose 관점 전반 요약 한두 문장.

## 문제점

### [CRITICAL] 1. ~~
파일 경로: feature/xxx/...
#### 리뷰 사항

#### 수정 방향

### [MAJOR] 2. ~~
...

### [MINOR] 3. ~~
...

CRITICAL: 1
MAJOR: 1
MINOR: 1
```
EOF

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$PROJECT_ROOT"

die() {
    echo "❌ $*" >&2
    exit 1
}

[ -f "PLAN.md" ] || die "PLAN.md 파일이 없습니다"
[ -f "IMPL.md" ] || die "IMPL.md 파일이 없습니다"

mkdir -p reviews

PLAN_MD=$(<PLAN.md)
IMPL_MD=$(<IMPL.md)
GIT_DIFF=$(git diff HEAD 2>/dev/null || true)
[ -n "$GIT_DIFF" ] || GIT_DIFF="(변경 내역이 감지되지 않음)"

PROMPT=${PROMPT//__PLAN.md__/$PLAN_MD}
PROMPT=${PROMPT//__IMPL.md__/$IMPL_MD}
PROMPT=${PROMPT//__GIT_DIFF__/$GIT_DIFF}

echo "🎨 Compose 리뷰 실행 (Gemini 3.1 pro preview)..."
RESULT=$(gemini \
    -m gemini-3.1-pro-preview \
    --approval-mode plan \
    -o json \
    -p "$PROMPT" 2>/dev/null)

echo "$RESULT" | jq -r '.response // empty' > "reviews/compose.md" \
    && echo "✅ reviews/compose.md"
