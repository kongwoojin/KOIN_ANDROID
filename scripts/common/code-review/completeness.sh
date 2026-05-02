#!/usr/bin/env bash
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$PROJECT_ROOT"

die() { echo "❌ $*" >&2; exit 1; }

[ -f "PLAN.md" ] || die "PLAN.md 파일이 없습니다"
[ -f "IMPL.md" ] || die "IMPL.md 파일이 없습니다"

mkdir -p reviews

# ── 사전 결정론적 검사 ────────────────────────────────
# IMPL.md 수정/신규 파일 목록 추출 (백틱으로 감싼 경로)
IMPL_MODIFIED=$(sed -n '/^## 수정한 파일/,/^## /p' IMPL.md \
    | grep '^- ' | grep -oE '`[^`]+`' | tr -d '`' | grep '/' || true)

IMPL_NEW=$(sed -n '/^## 새로 만든 파일/,/^## /p' IMPL.md \
    | grep '^- ' | grep -oE '`[^`]+`' | tr -d '`' | grep '/' || true)

# IMPL.md "범위 외 수정 (accepted)" 섹션에 명시된 파일 — 허용 목록에 추가
IMPL_ACCEPTED=$(sed -n '/^## 범위 외 수정/,/^## /p' IMPL.md \
    | grep '^- ' | grep -oE '`[^`]+`' | tr -d '`' | grep '/' || true)

# 실제 변경 파일 (tracked diff + untracked 신규)
ACTUAL_DIFF=$(git diff origin/develop...HEAD --name-only 2>/dev/null \
    || git diff HEAD~1..HEAD --name-only 2>/dev/null || true)
UNTRACKED=$(git status --short 2>/dev/null \
    | grep '^??' | awk '{print $2}' | sed 's|/$||' || true)
ALL_CHANGES=$(printf "%s\n%s" "$ACTUAL_DIFF" "$UNTRACKED" | sort -u | grep -v '^$' || true)

# IMPL.md 기재 파일 중 실제 변경 없는 파일 감지
MISSING_FILES=""
for f in $IMPL_MODIFIED $IMPL_NEW; do
    [[ -z "$f" ]] && continue
    if ! echo "$ALL_CHANGES" | grep -qxF "$f" && \
       ! echo "$ALL_CHANGES" | grep -qF "$(basename "$f")"; then
        MISSING_FILES="${MISSING_FILES}\n- ${f}"
    fi
done

if [[ -n "$MISSING_FILES" ]]; then
    MISSING_REPORT="⚠️  IMPL.md에 기재됐으나 실제 변경이 감지되지 않은 파일:$(printf "%b" "$MISSING_FILES")"
else
    MISSING_REPORT="없음 (IMPL.md 기재 파일 모두 git diff/status에서 확인됨)"
fi

# PLAN.md 명시 외 파일 수정 감지 (백틱 경로 기준 허용 목록)
PLAN_ALLOWED=$(grep -oE '`[^`]+`' PLAN.md | tr -d '`' | grep '/' | sort -u || true)
# IMPL.md 범위 외 수정 섹션 기재 파일을 허용 목록에 합산
PLAN_ALLOWED_EXT=$(printf "%s\n%s" "$PLAN_ALLOWED" "$IMPL_ACCEPTED" | sort -u | grep -v '^$' || true)

# PLAN.md에서 명시적 무수정 선언 파일 추출 ("수정하지 않는다 / 건드리지 / 무수정" 문구 근방)
PLAN_FORBIDDEN=$(grep -iE '(수정.{0,10}않|건드리지|무수정|do not (edit|modify|touch))' PLAN.md \
    | grep -oE '`[^`]+`' | tr -d '`' | grep '/' | sort -u || true)

FORBIDDEN_FILES=""
UNMENTIONED_FILES=""
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    # 파이프라인 산출물·환경 파일은 PLAN 범위 검사에서 제외
    case "$f" in
        PLAN.md|REVIEW.md|IMPL.md|CODE_REVIEW.md|E2E_TEST_*.md) continue ;;
        reviews|reviews/*|scripts|scripts/*|.maestro|.maestro/*|local.properties) continue ;;
        koin/google-services.json|koin/src/debug/google-services.json) continue ;;
    esac
    # 정확 일치 또는 basename 일치 시 허용 (PLAN.md 표기 변형 허용 + IMPL 범위 외 수정 accepted)
    if ! echo "$PLAN_ALLOWED_EXT" | grep -qxF "$f" && \
       ! echo "$PLAN_ALLOWED_EXT" | grep -qF "$(basename "$f")"; then
        # 명시적 무수정 선언 파일과 단순 미기재 파일을 분리
        if echo "$PLAN_FORBIDDEN" | grep -qxF "$f" || \
           echo "$PLAN_FORBIDDEN" | grep -qF "$(basename "$f")"; then
            FORBIDDEN_FILES="${FORBIDDEN_FILES}\n- ${f}"
        else
            UNMENTIONED_FILES="${UNMENTIONED_FILES}\n- ${f}"
        fi
    fi
done <<< "$ALL_CHANGES"

OUT_OF_SCOPE_REPORT=""
if [[ -n "$FORBIDDEN_FILES" ]]; then
    OUT_OF_SCOPE_REPORT="${OUT_OF_SCOPE_REPORT}🚫 PLAN.md가 명시적으로 무수정 선언한 파일이 변경됨 (CRITICAL):$(printf "%b" "$FORBIDDEN_FILES")\n"
fi
if [[ -n "$UNMENTIONED_FILES" ]]; then
    OUT_OF_SCOPE_REPORT="${OUT_OF_SCOPE_REPORT}ℹ️  PLAN.md에 언급되지 않은 파일이 변경됨 (MAJOR 또는 필요한 의존 수정이면 MINOR — 판단 필요):$(printf "%b" "$UNMENTIONED_FILES")\n"
fi
if [[ -z "$FORBIDDEN_FILES" && -z "$UNMENTIONED_FILES" ]]; then
    OUT_OF_SCOPE_REPORT="없음 (모든 변경 파일이 PLAN.md 명시 범위 내)"
fi

PLAN_MD=$(<PLAN.md)
IMPL_MD=$(<IMPL.md)
GIT_DIFF_STAT=$(git diff origin/develop...HEAD --stat 2>/dev/null \
    || git diff HEAD~1..HEAD --stat 2>/dev/null || true)
[ -n "$GIT_DIFF_STAT" ] || GIT_DIFF_STAT="(변경 통계 없음)"

read -r -d '' PROMPT <<'EOF' || true
당신은 구현 완전성(Completeness) 전담 리뷰어입니다.
주니어 개발자가 PLAN.md 에 따라 작성한 코드가 **계획한 모든 변경을 실제로 수행했는지** 검증하세요.
다른 리뷰어가 Security / Compose / Kotlin / Lint / SonarQube 를 담당합니다. 코드 품질은 검토하지 마세요.

## 추론·출력 언어
입력이 한글로 작성되었더라도 영어로 사고·분석한 뒤, 최종 응답·산출물은 한글로 출력합니다.

## 검토 영역
1. **PLAN.md 대상 파일 포함 여부**: PLAN.md의 리팩토링 대상 / 수정 대상 / 구현 대상 파일이 실제 git 변경에 포함됐는가
2. **IMPL.md 정합성**: IMPL.md에 기재된 수정·신규 파일이 실제 git diff에 존재하는가
3. **완료 조건 충족**: PLAN.md의 완료 조건(체크리스트) 각 항목이 구현됐는가
4. **누락 구현 감지**: PLAN.md에서 요구했으나 IMPL.md에도 git diff에도 없는 파일/변경
5. **PLAN.md 범위 외 파일 수정 감지**: PLAN.md에 명시되지 않은 파일이 변경됐는가 (특히 core 모듈 등 명시적 무수정 대상)

## 판단 기준
- IMPL.md 기재 파일이 git diff에 없음 → **CRITICAL** (할루시네이션 또는 미구현)
- PLAN.md 필수 대상 파일이 변경 없음 → **CRITICAL**
- PLAN.md가 명시적으로 "수정 금지" / "무수정" / "건드리지 않는다"고 선언한 파일이 변경됨 → **CRITICAL**
- PLAN.md에 언급조차 없는 파일이 변경됨 → **MAJOR** (단순 범위 누락 — 필요성 확인 필요)
  - 단, 해당 파일이 PLAN.md 명시 파일의 컴파일·동작에 직접 필요한 의존 파일(예: 파라미터 추가로 인한 호출부 수정, 인터페이스 구현체 변경)이라면 → **MINOR**
  - 단, IMPL.md `## 범위 외 수정 (accepted)` 섹션에 근거와 함께 기재된 파일이라면 → **MINOR** (구현자가 리뷰어 요구를 명시적으로 수용한 범위 확장)
- 완료 조건 항목 미충족 증거 있음 → **MAJOR**
- 범위 내 사소한 누락 → **MINOR**

## 사전 결정론적 분석 결과 (IMPL.md ↔ git diff 정합성)
__MISSING_REPORT__

## 사전 결정론적 분석 결과 (PLAN.md 범위 위반)
__OUT_OF_SCOPE_REPORT__

## 실제 변경 파일 목록 (git diff --stat)
```
__GIT_DIFF_STAT__
```

## PLAN.md
__PLAN.md__

## IMPL.md
__IMPL.md__

## 작업 지시
1. codex -s read-only 로 PLAN.md 완료 조건의 각 파일이 실제 존재·수정됐는지 확인
2. IMPL.md 기재 파일 중 git diff 에 없는 것 확인 (위 사전 분석 결과 참고)
3. PLAN.md 에서 요구하는 파일 중 어느 것도 변경되지 않은 경우 CRITICAL 으로 보고

## Output Format
```markdown
# Completeness 리뷰

## Summary
구현 완전성 전반 요약 한두 문장.

## 문제점

### [CRITICAL] 1. ~~
파일 경로: ...
#### 리뷰 사항

#### 수정 방향

CRITICAL: 0
MAJOR: 0
MINOR: 0
```
EOF

PROMPT="${PROMPT//__MISSING_REPORT__/$MISSING_REPORT}"
PROMPT="${PROMPT//__OUT_OF_SCOPE_REPORT__/$OUT_OF_SCOPE_REPORT}"
PROMPT="${PROMPT//__GIT_DIFF_STAT__/$GIT_DIFF_STAT}"
PROMPT="${PROMPT//__PLAN.md__/$PLAN_MD}"
PROMPT="${PROMPT//__IMPL.md__/$IMPL_MD}"

echo "📋 Completeness 리뷰 실행 (Codex gpt-5.4)..."
codex exec -m gpt-5.4 \
    "$PROMPT" -s read-only --skip-git-repo-check \
    -o "reviews/completeness.md" \
    && echo "✅ reviews/completeness.md"
