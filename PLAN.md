- Issue Type: [bugfix]
- Issue ID: [#50]
- Branch Name: [fix/50]

# [#50] 비밀번호 특수문자 정규식 불일치 수정

## Problem

`PasswordUtil.kt`에 비밀번호 특수문자를 판별하는 두 정규식이 서로 다른 기준으로 특수문자를 정의하여, UI에서 특수문자 포함 조건이 ✓로 표시되지만 실제 비밀번호 유효성 검사가 실패하는 불일치가 발생한다.

`FILTER_CONTAIN_SYMBOL`은 화이트리스트 전환이 완료되었으나, `FILTER_PASSWORD` 본문(line 14)이 여전히 `.{6,18}`이어서 화이트리스트 특수문자와 비허용 문자(공백·이모지 등)가 함께 포함된 입력을 잘못 허용한다.

| 입력 | 현재 결과 | 수정 후 |
|------|-----------|---------|
| `"abcde1! "` (화이트리스트 `!` + 공백) | `isPasswordValidate` → **true** ← 버그 | **false** |
| `"abc1!😀"` (화이트리스트 `!` + 이모지) | `isPasswordValidate` → **true** ← 버그 | **false** |

### Root Cause

`FILTER_PASSWORD` 패턴은 lookahead로 화이트리스트 특수문자 **존재**를 요구하지만, 본문 `.{6,18}`은 화이트리스트 외 임의 문자도 허용한다. 따라서 화이트리스트 특수문자와 비허용 문자가 함께 있으면 두 조건을 모두 통과하여 잘못된 `true`가 반환된다.

```kotlin
// PasswordUtil.kt line 13–14 — 버그 잔존
private val FILTER_PASSWORD =
    """^(?=.*[a-zA-Z])(?=.*[$SPECIAL_CHARS_CLASS])(?=.*[0-9]).{6,18}${'$'}"""
//                                                              ^^^^^^^^
//                               화이트리스트 외 공백·이모지 등 모든 문자 허용 ← 버그
```

---

## 이미 반영됨 (수정 불필요)

| 항목 | 파일 위치 |
|------|-----------|
| `SPECIAL_CHARS_CLASS` 공유 상수 추출 | `PasswordUtil.kt` line 11 |
| `FILTER_CONTAIN_SYMBOL` 화이트리스트 전환 | `PasswordUtil.kt` line 23 |
| `hashString` `Charsets.UTF_8` 명시 | `PasswordUtil.kt` line 49 |
| `hashString` `0xFF` 마스킹 | `PasswordUtil.kt` line 54 |
| `TODO` 주석 제거 | 잔존 없음 |
| 공백/탭/이모지 `isIncludeSymbol` 거부 테스트 | `VerifyPasswordFormatUseCaseTest.kt` lines 82–101 |
| 화이트리스트 문자 `isIncludeSymbol` 인정 테스트 | `VerifyPasswordFormatUseCaseTest.kt` lines 103–115 |
| 공백 `isPasswordValidate` false 정합성 테스트 | `VerifyPasswordFormatUseCaseTest.kt` lines 117–136 |

---

## 참고 구현

- `domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt` — 버그 발생 지점 (수정 대상, line 14)
- `domain/src/test/java/in/koreatech/koin/domain/usecase/user/VerifyPasswordFormatUseCaseTest.kt` — 단위 테스트 업데이트 (lines 139–162, 신규 케이스 추가)

---

## 수정 계획

### 1. `domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt`

**변경 범위**: line 14 한 줄, `.{6,18}` → `[a-zA-Z0-9$SPECIAL_CHARS_CLASS]{6,18}` 교체

**Before** (lines 13–14):
```kotlin
private val FILTER_PASSWORD =
    """^(?=.*[a-zA-Z])(?=.*[$SPECIAL_CHARS_CLASS])(?=.*[0-9]).{6,18}${'$'}"""
```

**After** (lines 13–14):
```kotlin
private val FILTER_PASSWORD =
    """^(?=.*[a-zA-Z])(?=.*[$SPECIAL_CHARS_CLASS])(?=.*[0-9])[a-zA-Z0-9$SPECIAL_CHARS_CLASS]{6,18}${'$'}"""
```

> `$SPECIAL_CHARS_CLASS`는 Kotlin string interpolation으로 line 11의 raw string 값이 그대로 삽입된다. `${'$'}` 는 regex 종단 앵커 `$`를 리터럴로 삽입하는 기존 표기 — 수정하지 않는다.

---

### 2. `domain/src/test/java/in/koreatech/koin/domain/usecase/user/VerifyPasswordFormatUseCaseTest.kt`

> **⚠️ 구현 주의**: 아래 `specialCharsClass` 로컬 변수의 raw string 값은 반드시 **`PasswordUtil.kt` line 11의 `SPECIAL_CHARS_CLASS` raw string 리터럴을 IDE에서 직접 복사**해야 한다. PLAN 문서 본문에서 복사하면 마크다운 렌더링으로 인한 문자 오염(예: `&` 변형, 역슬래시 표현 변형) 위험이 있다.

#### (A) [Update] `PASSWORD_REGEX` 패턴 문자열 검증 테스트 (lines 139–143)

장문 리터럴을 두 번 수기 관리하는 대신, 로컬 변수로 한 번 정의하고 interpolation으로 조립한다.

**Before** (lines 139–143):
```kotlin
@Test
fun `PASSWORD_REGEX 정규식 문자열이 올바르게 생성되었다`() {
    val expectedPattern =
        """^(?=.*[a-zA-Z])(?=.*[`₩~!@#$%<>^&*()\-=+_?:;"',.{}|\[\]/\\])(?=.*[0-9]).{6,18}$"""
    assertEquals(expectedPattern, PasswordUtil.PASSWORD_REGEX.pattern())
}
```

**After** (lines 139–145):
```kotlin
@Test
fun `PASSWORD_REGEX 정규식 문자열이 올바르게 생성되었다`() {
    // specialCharsClass: PasswordUtil.kt:11의 SPECIAL_CHARS_CLASS와 동일한 raw string
    val specialCharsClass = /* PasswordUtil.kt:11에서 직접 복사 */
    val expectedPattern =
        """^(?=.*[a-zA-Z])(?=.*[$specialCharsClass])(?=.*[0-9])[a-zA-Z0-9$specialCharsClass]{6,18}$"""
    assertEquals(expectedPattern, PasswordUtil.PASSWORD_REGEX.pattern())
}
```

이 방식을 사용하면 `&`, `\]`, `\\` 등 문자 클래스 내 민감한 표기가 단일 소스에서만 관리되므로, 역슬래시 표현 불일치(`\\]` vs `\]`)나 `&` 오염 문제가 발생하지 않는다.

#### (B) [Update] 화이트리스트 루프 테스트 강화 (lines 154–162)

픽스처를 6자로 늘리고 `isPasswordValidate` 검증을 추가한다.

**Before** (lines 155–162):
```kotlin
for (symbol in whitelistSymbols) {
    val password = "abc1$symbol"
    val containSymbolResult = PasswordUtil.isContainSymbol(password)
    assertTrue(
        "Symbol '$symbol' should match CONTAIN_SYMBOL_REGEX",
        containSymbolResult
    )
}
```

**After** (lines 155–164):
```kotlin
for (symbol in whitelistSymbols) {
    // 영문(abc) + 숫자(1) + 화이트리스트 특수문자 + 영문(d) = 6자 → isPasswordValidate 최소 길이 충족
    val password = "abc1${symbol}d"
    assertTrue(
        "Symbol '$symbol' should match CONTAIN_SYMBOL_REGEX",
        PasswordUtil.isContainSymbol(password)
    )
    assertTrue(
        "Symbol '$symbol' should pass isPasswordValidate",
        PasswordUtil.isPasswordValidate(password)
    )
}
```

#### (C) [Add] 잔존 버그 회귀 테스트 추가

```kotlin
@Test
fun `화이트리스트 특수문자와 공백이 함께 있으면 isPasswordValidate는 false를 반환한다`() {
    // 수정 전 .{6,18}은 공백을 허용해 true → 수정 후 false
    assertFalse(PasswordUtil.isPasswordValidate("abcde1! "))
}

@Test
fun `화이트리스트 특수문자와 이모지가 함께 있으면 isPasswordValidate는 false를 반환한다`() {
    // 수정 전 .{6,18}은 이모지 서로게이트 페어를 허용해 true → 수정 후 false
    assertFalse(PasswordUtil.isPasswordValidate("abc1!😀"))
}
```

---

## 변경 불필요 파일

| 파일 | 이유 |
|------|------|
| `VerifyPasswordFormatUseCase.kt` | `isContainSymbol()` 호출 — PasswordUtil 수정만으로 해결 |
| `ValidationExtensions.kt` | `isPasswordValidate()` → PasswordUtil 위임 (정상) |
| `SignupCheckingUseCase.kt` | `isNotValidPassword()` 사용 — 영향 없음 |
| `OwnerSignupRequestEmailVerificationUseCase.kt` | `isNotValidPassword()` 사용 — 영향 없음 |
| `ChangePasswordSmsUseCase.kt` | `isNotValidPassword()` 사용 — 영향 없음 |
| `OwnerChangePasswordUseCase.kt` | `isNotValidPassword()` 사용 — 영향 없음 |

---

## 체크리스트

- [ ] `FILTER_PASSWORD` line 14: `.{6,18}` → `[a-zA-Z0-9$SPECIAL_CHARS_CLASS]{6,18}` 교체 완료
- [ ] 테스트의 `specialCharsClass` 값이 `PasswordUtil.kt:11` IDE 직접 복사본과 일치하는지 확인 (PLAN 본문 복사 금지)
- [ ] `expectedPattern`이 로컬 `specialCharsClass` 변수 interpolation으로 조립되어 있는지 확인 (장문 리터럴 수기 작성 금지)
- [ ] 화이트리스트 루프 픽스처가 6자(`"abc1${symbol}d"`)이고 `isContainSymbol` + `isPasswordValidate` 양쪽 검증하는지 확인
- [ ] `isPasswordValidate("abcde1! ")` → `false` 테스트 통과 (화이트리스트 특수문자 + 공백 조합)
- [ ] `isPasswordValidate("abc1!😀")` → `false` 테스트 통과 (화이트리스트 특수문자 + 이모지 조합)
- [ ] `./gradlew :domain:test` 전체 통과 확인
- [ ] `./gradlew ktlintFormat` 실행 후 `./gradlew ktlintCheck` 통과 확인
