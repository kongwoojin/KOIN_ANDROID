# Completeness 리뷰

## Summary
핵심 대상 파일 2개는 실제로 변경됐고, 테스트 7개 추가도 확인됐습니다. 다만 현재 워크트리 기준으로는 `PLAN.md`/`IMPL.md`에 없는 범위 외 수정이 존재하고, `PasswordUtil.kt`의 정규식 추출 방식도 PLAN이 요구한 “verbatim + byte-identical” 조건을 충족하지 않습니다.

## 문제점

### [MAJOR] 1. PLAN/IMPL에 없는 범위 외 파일 3개가 실제로 수정됨
파일 경로: [VerifyPasswordFormatUseCase.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-50/domain/src/main/java/in/koreatech/koin/domain/usecase/user/VerifyPasswordFormatUseCase.kt:10), [StringExtensions.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-50/domain/src/main/java/in/koreatech/koin/domain/util/ext/StringExtensions.kt:9), [ValidationExtensions.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-50/domain/src/main/java/in/koreatech/koin/domain/util/ext/ValidationExtensions.kt:15)
#### 리뷰 사항
`PLAN.md`의 변경 대상은 `PasswordUtil.kt`, `VerifyPasswordFormatUseCaseTest.kt` 두 파일뿐입니다. 그런데 실제 diff에는 위 3개 파일이 추가로 포함돼 있습니다. 특히 `PLAN.md` 본문은 `ValidationExtensions.kt`를 “수정 불필요 파일”로 명시했고, `IMPL.md`도 “수정한 파일”에 이 3개를 적지 않은 채 “범위 외 수정: 없음”이라고 기록했습니다.  
실제 원인은 [PasswordUtil.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-50/domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt:7) 를 `class`에서 `object`로 바꾼 추가 리팩토링 때문인데, 이 변경 자체가 PLAN에 없었습니다.

#### 수정 방향
`PasswordUtil`을 PLAN대로 정규식만 수정하는 형태로 되돌리고, 호출부 3개 파일 수정은 제거하세요. 정말 `object` 전환이 필요했다면 최소한 `PLAN.md`와 `IMPL.md`에 범위 확장 근거를 명시했어야 합니다.

### [MAJOR] 2. `SPECIAL_CHARS_CLASS`가 PLAN 요구대로 verbatim 추출되지 않아 `byte-identical` 완료 조건을 충족하지 못함
파일 경로: [PasswordUtil.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-50/domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt:45)
#### 리뷰 사항
`PLAN.md`는 기존 `PasswordUtil.kt:53`의 `(?=.*[…])` 내부 본문을 “소스에서 직접 verbatim 추출”하고, 변경 후 `PASSWORD_REGEX.pattern()`이 기존 문자열과 `byte-identical`해야 한다고 요구했습니다.  
하지만 현재 구현의 `SPECIAL_CHARS_CLASS`는 기존 `FILTER_PASSWORD`의 문자 클래스와 동일한 순서/표현을 그대로 옮긴 것이 아닙니다. 기존에는 `...*()\\-=+.../\\\\]` 형태였는데, 현재는 `...*()=+.../\\\\-`로 하이픈 위치와 이스케이프 배치가 바뀌었습니다. 동작이 같을 수는 있어도, PLAN의 완료 조건인 “verbatim 추출”과 “byte-identical 검증”을 만족한 구현으로 볼 수 없습니다.

#### 수정 방향
기존 `FILTER_PASSWORD`의 특수문자 클래스 본문을 순서와 이스케이프까지 그대로 `SPECIAL_CHARS_CLASS`로 옮기고, 그 값을 사용해 만들어진 `PASSWORD_REGEX.pattern()`이 원래 문자열과 동일함을 테스트나 검증 근거로 남기세요.

CRITICAL: 0  
MAJOR: 2  
MINOR: 0