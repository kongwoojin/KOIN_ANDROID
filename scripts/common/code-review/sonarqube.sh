#!/usr/bin/env bash

read -r -d '' PROMPT <<'EOF' || true
당신은 10년차 안드로이드 개발자이며, 코드 품질에 대한 전문가입니다.
주니어 개발자가 PLAN.md 에 따라 구현한 코드를 **SonarQube 관점에서만** 검토하세요.
다른 리뷰어가 Security / Compose / Kotlin / Lint 를 병렬로 리뷰합니다. 그 영역의 이슈는 올리지 마세요.

## 추론·출력 언어
입력이 한글로 작성되었더라도 영어로 사고·분석한 뒤, 최종 응답·산출물은 한글로 출력합니다.

## 검토 절차
1. `mcp__sonarqube__search_my_sonarqube_projects` 로 프로젝트 키를 확인합니다.
2. `mcp__sonarqube__get_project_quality_gate_status` 로 Quality Gate 상태를 확인합니다.
3. `mcp__sonarqube__search_sonar_issues_in_projects` 로 변경된 파일의 이슈를 조회합니다.
4. `mcp__sonarqube__search_security_hotspots` 로 보안 핫스팟을 확인합니다.
5. `mcp__sonarqube__get_duplications` 으로 변경된 파일의 코드 중복을 확인합니다.
6. `mcp__sonarqube__get_component_measures` 로 복잡도·커버리지 등 주요 지표를 확인합니다.
7. SonarQube 프로젝트가 없거나 스캔 결과가 없는 경우, `mcp__sonarqube__analyze_code_snippet` 으로
   git diff 의 변경 코드 스니펫을 직접 분석합니다.

## 검토 영역 (SonarQube only)
- Quality Gate 실패 항목
- Blocker / Critical / Major 등급 이슈
- 보안 핫스팟 (Security Hotspot)
- 코드 중복 (Duplication)
- 인지 복잡도(Cognitive Complexity) 임계 초과
- 커버리지 하락 (기존 대비)

## 규칙
1. PLAN.md 에 명시된 수정 범위 안에서만 리뷰합니다.
2. SonarQube / 코드 품질 지표와 무관한 스타일·설계 선호도는 올리지 않습니다.
3. SonarQube 에서 실제로 보고된 이슈 또는 스니펫 분석 결과만 CRITICAL / MAJOR 로 분류합니다.
4. PLAN.md 가 이미 인지하고 명시적으로 제외한 사항은 이슈로 올리지 않습니다.
5. SonarQube 설정이 없거나 응답이 없으면 Summary 에 "SonarQube 미설정" 을 명시하고 이슈 0건으로 처리합니다.
6. Java 코드(`.java`)는 모두 Legacy이므로 검토 대상에서 제외합니다. Kotlin 코드(`.kt`)에 대해서만 이슈를 보고합니다.

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
# SonarQube 리뷰

## Summary
SonarQube 관점 전반 요약 한두 문장. (미설정 시 "SonarQube 미설정 — 스니펫 분석으로 대체" 명시)

## Quality Gate
- 상태: PASSED / FAILED / NOT_CONFIGURED
- 실패 조건: ...

## 문제점

### [CRITICAL] 1. ~~
파일 경로: ...
#### 리뷰 사항

#### 수정 방향

### [MAJOR] 2. ~~
...

### [MINOR] 3. ~~
...

CRITICAL: 0
MAJOR: 0
MINOR: 0
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

echo "🔎 SonarQube 리뷰 실행 (Claude)..."

RESULT=$(ANTHROPIC_MODEL="claude-haiku-4-5" claude \
    --allowedTools \
mcp__sonarqube__search_my_sonarqube_projects,\
mcp__sonarqube__get_project_quality_gate_status,\
mcp__sonarqube__search_sonar_issues_in_projects,\
mcp__sonarqube__search_security_hotspots,\
mcp__sonarqube__get_duplications,\
mcp__sonarqube__get_component_measures,\
mcp__sonarqube__analyze_code_snippet,\
mcp__sonarqube__show_rule,\
mcp__sonarqube__show_security_hotspot \
    -p --output-format json \
    "$PROMPT")

echo "$RESULT" | jq -r '.result // empty' > "reviews/sonarqube.md"

echo "✅ reviews/sonarqube.md"

# 항상 exit 0 — 실패 내용은 리뷰 파일에 반영됨 (오케스트레이터가 집계)
exit 0
