# PLAN.md 리뷰

## Summary
실제 코드 기준으로 보면 문제 정의와 수정 범위는 적절합니다. [`PasswordUtil.kt`](</home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-50/domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt:53>)의 `FILTER_PASSWORD`와 [`PasswordUtil.kt`](</home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-50/domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt:63>)의 `FILTER_CONTAIN_SYMBOL`가 실제로 서로 다른 특수문자 집합을 사용하고 있고, [`VerifyPasswordFormatUseCase.kt`](</home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-50/domain/src/main/java/in/koreatech/koin/domain/usecase/user/VerifyPasswordFormatUseCase.kt:12>)가 UI 판정에 `isContainSymbol()`을 사용하므로 PLAN의 버그 인식 자체는 정확합니다. 테스트를 `VerifyPasswordFormatUseCaseTest`에 추가하겠다는 방향도 범위에 맞습니다.

Context7로 최신 Kotlin 문서를 확인한 결과, PLAN의 핵심 수정 방향은 맞지만 `const val -> val 변경 필수`라는 전제는 현재 Kotlin 기준으로 맞지 않습니다. 이 부분만 정정하면 구현 계획으로 충분합니다.

## 문제점

### [MINOR] 1. `const val → val 변경 필수` 전제가 최신 Kotlin 기준과 맞지 않습니다
파일 경로: [PasswordUtil.kt](</home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-50/domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt:53>)
#### 리뷰 사항
PLAN은 `SPECIAL_CHARS_CLASS`를 추출한 뒤 `FILTER_PASSWORD`, `FILTER_CONTAIN_SYMBOL`를 반드시 `val`로 바꿔야 한다고 적고 있습니다. 그런데 Context7의 Kotlin 문서(`/jetbrains/kotlin`) 기준으로, `const val`은 다른 compile-time constant를 포함한 문자열 초기화도 허용됩니다. 즉 `SPECIAL_CHARS_CLASS`를 `const val`로 두고, 이를 이용해 만든 정규식 문자열도 compile-time constant로 유지할 수 있습니다.

현재 이 항목이 그대로 구현되더라도 기능 버그가 생기지는 않지만, PLAN이 “불가능해서 바꿔야 한다”고 단정한 근거는 부정확합니다. 구현자가 불필요하게 런타임 초기화 `val`로 낮추게 만들 수 있습니다.

#### 수정 방향
`FILTER_PASSWORD`, `FILTER_CONTAIN_SYMBOL`의 목적은 “단일 소스화”이지 “반드시 `val`로 변경”이 아닙니다. 따라서 PLAN 문구를 다음 수준으로 정정하는 것이 맞습니다.

- `SPECIAL_CHARS_CLASS`를 공통 상수로 추출한다.
- `FILTER_PASSWORD`, `FILTER_CONTAIN_SYMBOL`는 동일한 상수를 참조하도록 맞춘다.
- `const val` 유지 가능 여부는 Kotlin compile-time constant 규칙에 맞춰 결정한다.

즉, 이 이슈의 올바른 핵심은 “두 정규식의 문자 집합 통일”이고, `const val` 변경은 필수 요구사항으로 적지 않는 편이 맞습니다.

CRITICAL: 0
MAJOR: 0
MINOR: 1