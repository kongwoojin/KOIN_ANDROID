# Security 리뷰

## Summary
PLAN.md에 명시된 범위의 실제 Kotlin 변경분인 [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:133), [TimetableSemesterActivity.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/koin/src/main/java/in/koreatech/koin/ui/timetablev2/TimetableSemesterActivity.kt:120)을 코드 기준으로 확인했습니다. 이번 변경에서 보안 관점의 신규 취약점이나 민감정보 유출 문제는 확인되지 않았습니다.

## 문제점
발견된 보안 이슈 없음.

검토한 변경 기준 확인 사항:
- `SemesterSideEffect.Toast`/`SnackBar` 추가 구간에 하드코딩된 API 키, 토큰, 비밀번호 없음.
- 실패 로그는 `Timber.d("시간표 추가 실패")`, `Timber.d("시간표 프레임 수정 실패")`, `Timber.d("시간표 프레임 삭제 실패")`, `Timber.d("롤백 실패")` 수준으로, 이번 변경에서 토큰·이메일·전화번호 등 민감정보를 로깅하지 않음. 참고 위치: [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:218), [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:283), [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:324), [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:366)
- 이번 수정에서 SharedPreferences/DataStore/Room 저장 로직 추가 없음.
- Intent extra 처리 변경은 삭제 성공 SnackBar의 발행 위치 제거뿐이며, 민감 extra 추가나 implicit intent 노출 확대 없음. 참고 위치: [TimetableSemesterActivity.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/koin/src/main/java/in/koreatech/koin/ui/timetablev2/TimetableSemesterActivity.kt:120)
- WebView, `@JavascriptInterface`, file access, cleartext HTTP, 인증서/호스트 검증 우회, SQL 문자열 결합 관련 변경 없음.
- 삭제 성공 SnackBar를 Activity에서 ViewModel `onSuccess`로 옮긴 변경은 보안상 권한 우회나 인증 흐름 변경을 만들지 않음. 참고 위치: [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:300)

CRITICAL: 0  
MAJOR: 0  
MINOR: 0