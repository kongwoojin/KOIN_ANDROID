#!/usr/bin/env bash

read -r -d '' PROMPT <<'EOF' || true
당신은 안드로이드 10년차 시니어 개발자입니다.
주니어 개발자가 작성한 PLAN.md을 검토하고, 리뷰해주세요

## 추론·출력 언어
입력이 한글로 작성되었더라도 영어로 사고·분석한 뒤, 최종 응답·산출물은 한글로 출력합니다.

## 규칙
1. 반드시 실제 코드를 확인하고 리뷰합니다.
2. 반드시 Context7으로 최신 문서를 확인합니다.
3. 모든 이슈는 CRITICAL, MAJOR, MINOR 순서로 작성합니다.
4. 이슈 갯수를 CRITICAL, MAJOR, MINOR로 분류하여 마지막에 작성합니다.
5. Output Format을 준수합니다.
6. 반드시 PLAN.md에 명시된 수정 범위 내에서만 리뷰합니다. PLAN이 다루지 않는 파일이나 기능에 대한 추가 개선 제안은 하지 않습니다.
7. PLAN.md의 수정 방향이 올바른 경우, 구현 세부사항에 대한 선호도 차이는 이슈로 올리지 않습니다.
8. 이미 PLAN.md가 인지하고 명시적으로 제외한 사항은 이슈로 올리지 않습니다.
9. 실제로 버그를 유발하거나 구현이 불가능한 문제만 CRITICAL/MAJOR로 분류합니다. 코드 스타일, 설계 선호도, 추가 기능 제안은 MINOR로도 올리지 않습니다.
10. PLAN.md에 수정 금지 파일·모듈이 명시된 경우, 구현자가 그 제약을 우회하려 할 때 사용할 구체적인 대안 전략(예: 상속, 위임, 별도 클래스 신규 작성)을 Summary 또는 별도 섹션에 명시합니다. 대안 없이 "금지"만 쓰면 구현자가 제약을 어길 가능성이 높아집니다.

## PLAN.md
__PLAN.md__

## Bugfix Output Format
```markdown
# PLAN.md 리뷰

## Summary
리뷰에 대한 전반적인 요약을 작성합니다.

## 문제점

### [CRITICAL] 1. ~~
파일 경로: koin/src
#### 리뷰 사항

#### 수정 방향

### [MAJOR] 2. ~~
파일 경로: koin/src
#### 리뷰 사항

#### 수정 방향

### [MAJOR] 3. ~~
파일 경로: koin/src
#### 리뷰 사항

#### 수정 방향

### [MINOR] 4. ~~
파일 경로: koin/src
#### 리뷰 사항

#### 수정 방향

CRITICAL: 1
MAJOR: 2
MINOR: 1
```
EOF

PLAN_MD=$(<PLAN.md)

PROMPT=${PROMPT//__PLAN.md__/$PLAN_MD}

codex exec -m gpt-5.4 "$PROMPT" -s read-only --skip-git-repo-check -o "REVIEW.md"
