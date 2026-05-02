#!/usr/bin/env bash

read -r -d '' PROMPT <<'EOF' || true
당신은 10년차 Android 보안 전문가입니다.
주니어 개발자가 PLAN.md 에 따라 구현한 코드를 **보안 관점에서만** 검토하세요.
다른 리뷰어가 Compose / Kotlin / Lint 를 병렬로 리뷰합니다. 그 영역의 이슈는 올리지 마세요.

## 추론·출력 언어
입력이 한글로 작성되었더라도 영어로 사고·분석한 뒤, 최종 응답·산출물은 한글로 출력합니다.

## 검토 영역 (Security only)
- 하드코딩된 API 키·시크릿·토큰·비밀번호
- 민감 데이터 로깅 (PII, 토큰, 전화번호, 이메일)
- SharedPreferences / DataStore / Room 에 평문 민감 데이터 저장
- Intent hijacking, implicit intent 에 sensitive extras
- WebView `@JavascriptInterface` / `setAllowFileAccess(true)` / file:// 로드
- 쿼리 삽입 가능성 (Room `@RawQuery`, 문자열 연결로 SQL 생성)
- 인증 토큰 처리 — auth bypass, refresh token leak
- 네트워크: cleartext HTTP, 인증서·호스트네임 검증 회피 (OkHttp HostnameVerifier 등)
- AndroidManifest: 과도한 permission, `exported=true` 노출 컴포넌트
- 외부 저장소 경로 traversal, FileProvider 미사용
- 딥링크 파라미터 검증 누락
- Log.d / println 에 토큰·PII 유출

## 규칙
1. 반드시 실제 코드를 읽어 검증합니다 (codex -s read-only).
2. PLAN.md 에 명시된 수정 범위 안에서만 리뷰합니다.
3. 보안과 무관한 스타일·성능·설계 선호도는 이슈로 올리지 않습니다.
4. 실제로 exploit 가능하거나 민감 정보가 유출되는 문제만 CRITICAL / MAJOR 로 분류합니다.
5. PLAN.md 가 이미 인지하고 명시적으로 제외한 사항은 이슈로 올리지 않습니다.
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
# Security 리뷰

## Summary
보안 관점 전반 요약 한두 문장.

## 문제점

### [CRITICAL] 1. ~~
파일 경로: koin/src
#### 리뷰 사항

#### 수정 방향

### [MAJOR] 2. ~~
파일 경로: koin/src
#### 리뷰 사항

#### 수정 방향

### [MINOR] 3. ~~
파일 경로: koin/src
#### 리뷰 사항

#### 수정 방향

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
[ -f "IMPL.md" ] || die "IMPL.md 파일이 없습니다. 먼저 plan-implement.sh 를 실행하세요"

mkdir -p reviews

PLAN_MD=$(<PLAN.md)
IMPL_MD=$(<IMPL.md)
GIT_DIFF=$(git diff HEAD 2>/dev/null || true)
[ -n "$GIT_DIFF" ] || GIT_DIFF="(변경 내역이 감지되지 않음 — 파일을 직접 읽어 리뷰하세요)"

PROMPT=${PROMPT//__PLAN.md__/$PLAN_MD}
PROMPT=${PROMPT//__IMPL.md__/$IMPL_MD}
PROMPT=${PROMPT//__GIT_DIFF__/$GIT_DIFF}

echo "🔒 Security 리뷰 실행 (Codex)..."
codex exec -m gpt-5.4 "$PROMPT" -s read-only --skip-git-repo-check -o "reviews/security.md" \
    && echo "✅ reviews/security.md"
