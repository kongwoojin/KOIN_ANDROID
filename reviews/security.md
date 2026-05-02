# Security 리뷰

## Summary
PLAN.md에 명시된 범위의 Kotlin 변경분 `SemesterViewModel.kt`, `TimetableSemesterActivity.kt`를 실제 코드 기준으로 확인했습니다. 이번 변경에서 보안 관점의 신규 취약점이나 민감정보 유출 문제는 확인되지 않았습니다.

## 문제점
발견된 보안 이슈 없음.

검토한 범위에서 확인한 사항:
- 하드코딩된 API 키, 시크릿, 토큰, 비밀번호 추가 없음
- 토큰, 이메일, 전화번호 등 민감정보 로깅 없음
- SharedPreferences, DataStore, Room 등에 민감정보를 평문 저장하는 변경 없음
- implicit intent, sensitive extras, exported component 노출 관련 변경 없음
- WebView, `@JavascriptInterface`, file access, cleartext HTTP, 인증서 검증 우회 관련 변경 없음
- SQL 문자열 결합이나 `@RawQuery` 기반 주입 가능성 없음
- 삭제 성공/실패 피드백 이동 과정에서 인증 우회나 권한 상승 흐름 없음

참고:
- `Timber.d("시간표 추가 실패")`, `Timber.d("시간표 프레임 수정 실패")`, `Timber.d("시간표 프레임 삭제 실패")`, `Timber.d("롤백 실패")`는 현재 메시지 기준으로 민감정보를 포함하지 않습니다.
- `SnackBar("${target.timetableName}가 삭제되었어요")`는 사용자 생성 문자열을 그대로 노출하지만, 이 값은 시간표 이름으로 보이며 본 리뷰 기준 민감정보로 판단되지는 않았습니다.

CRITICAL: 0  
MAJOR: 0  
MINOR: 0