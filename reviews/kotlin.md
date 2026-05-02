# Kotlin 리뷰

## Summary
비밀번호 특수문자 정합성 문제를 해결하기 위해 `PasswordUtil`을 리팩토링하고 관련 테스트를 보강한 점은 적절합니다. 특히 `SPECIAL_CHARS_CLASS` 상수를 통해 검증 로직의 단일 소스(SSOT)를 구축한 방향은 훌륭합니다. 그러나 리팩토링 과정에서 **해싱 로직에 치명적인 버그가 유입**되었고, 프로젝트 규칙인 **공개 API 타입 명시**가 일부 누락되었습니다.

## 문제점

### [CRITICAL] 1. PasswordUtil.hashString 의 Hex 변환 버그 (부호 확장)
파일 경로: `domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt`
#### 리뷰 사항
`hashedBytes.joinToString("") { "%02x".format(it) }` 사용 시, `Byte` 타입의 음수 값(예: 0xFF)이 `String.format`에 전달되면서 32비트 `Int`로 부호 확장(Sign Extension)이 발생합니다. 이로 인해 `ff` 대신 `ffffffff`와 같이 8자리의 헥스 문자열이 생성되어, SHA-256 해시 결과가 64자를 초과하게 됩니다. 이는 **로그인 실패 및 비밀번호 불일치**를 야기하는 치명적인 버그입니다.

#### 수정 방향
기존 코드처럼 `0xFF and it.toInt()`를 사용하여 하위 8비트만 취하도록 수정하거나, Kotlin 1.9+의 `toHexString()`(실험적) 또는 명확한 마스킹 처리가 필요합니다.
```kotlin
// 수정 제안
hashedBytes.joinToString("") { "%02x".format(it.toInt() and 0xFF) }
```

### [MAJOR] 2. hashString 로직 회귀 (Regression)
파일 경로: `domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt`
#### 리뷰 사항
기존 코드(`PasswordUtil`이 클래스였을 때)에서는 `0xFF and hashedByte.toInt()`를 통해 정확하게 헥스 변환을 수행하고 있었으나, `object`로 리팩토링하며 `joinToString`을 도입하는 과정에서 해당 마스킹 로직이 누락되었습니다. 리팩토링은 기능 동등성을 유지해야 하는데, 핵심 인증 로직에서 이탈이 발생했습니다.

#### 수정 방향
위 1번 이슈와 동일하게 마스킹 로직을 복구해야 합니다.

### [MINOR] 3. 공개 API(확장 함수)의 명시적 반환 타입 누락
파일 경로: `domain/src/main/java/in/koreatech/koin/domain/util/ext/StringExtensions.kt`, `domain/src/main/java/in/koreatech/koin/domain/util/ext/ValidationExtensions.kt`
#### 리뷰 사항
프로젝트 규칙("Keep public APIs explicitly typed")에 따라 도메인 모듈의 공개 API인 확장 함수들은 반환 타입을 명시해야 합니다.
- `String.toSHA256()`
- `String.isValidPassword()` 등

#### 수정 방향
반환 타입을 명시적으로 선언하세요.
```kotlin
fun String.toSHA256(): String = PasswordUtil.generateSHA256(this)
fun String.isValidPassword(): Boolean = PasswordUtil.isPasswordValidate(this)
```

### [MINOR] 4. toByteArray() 호출 시 Charset 미지정
파일 경로: `domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt`
#### 리뷰 사항
`message.toByteArray()` 호출 시 시스템 기본 인코딩에 의존합니다. 안드로이드 환경에서는 보통 UTF-8이지만, 일관된 해시 결과 보장을 위해 명시적으로 `Charsets.UTF_8`을 지정하는 것이 권장됩니다.

#### 수정 방향
`message.toByteArray(Charsets.UTF_8)`로 수정하세요.

### [MINOR] 5. PLAN.md 범위 초과 리팩토링
파일 경로: `domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt` 및 호출부 파일들
#### 리뷰 사항
PLAN.md에서는 `PasswordUtil`을 `object`로 전환하라는 내용이 없었으며, 오히려 `ValidationExtensions.kt` 등을 "수정 불필요" 파일로 명시했습니다. 하지만 `object` 전환으로 인해 해당 파일들의 호출부(`PasswordUtil()` -> `PasswordUtil`)를 모두 수정하게 되어 PLAN의 의도와 다른 광범위한 변경이 발생했습니다. (물론 `object` 전환 자체는 메모리 효율상 바람직한 방향입니다.)

CRITICAL: 1
MAJOR: 1
MINOR: 3
