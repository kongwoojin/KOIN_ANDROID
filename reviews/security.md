# Security 리뷰

## Summary
PLAN 범위의 Kotlin 변경(`PasswordUtil.kt`, `VerifyPasswordFormatUseCaseTest.kt`, 그리고 호출부의 정적 접근 변경)만 실제 코드로 확인했습니다. 보안 관점에서는 하드코딩된 시크릿, 민감정보 로깅, 평문 저장, 네트워크/인텐트/WebView/Manifest 노출 등 실질적인 취약점은 발견되지 않았습니다.

## 문제점
발견된 보안 이슈 없음.

검토 메모:
- `FILTER_CONTAIN_SYMBOL`을 화이트리스트 기준으로 좁힌 변경은 입력 판정 일관성을 높이는 수정이며, 보안상 허용 범위를 불필요하게 넓히지 않았습니다.
- `NoSuchAlgorithmException`에서 `printStackTrace()`를 제거한 현재 구현은 예외 상세가 로그로 노출될 가능성을 줄이는 방향입니다.
- 테스트 추가분에도 토큰, 이메일, 전화번호, 비밀번호 실데이터 로깅이나 외부 노출 요소는 없습니다.

CRITICAL: 0
MAJOR: 0
MINOR: 0