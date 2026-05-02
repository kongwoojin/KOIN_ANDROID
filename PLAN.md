- Issue Type: [bugfix]
- Issue ID: [#50]
- Branch Name: [fix/50]

# [#50] 비밀번호 특수문자 정규식 불일치 — FILTER_PASSWORD vs FILTER_CONTAIN_SYMBOL

## Problem

`PasswordUtil.kt`에 비밀번호 특수문자를 검증하는 두 정규식이 서로 다른 기준으로 "특수문자"를 정의하고 있습니다.

- `FILTER_PASSWORD` (line 53): **화이트리스트 방식** — 명시된 33개 문자만 특수문자로 허용
- `FILTER_CONTAIN_SYMBOL` (line 63): **네거티브 매칭 방식** — 영문·숫자·한글이 아닌 **모든** 문자를 특수문자로 인식

결과적으로 공백(` `), 이모지(`😀`), 탭(`\t`) 등 `FILTER_PASSWORD` 화이트리스트에 없는 문자를 입력하면 다음 불일치가 발생합니다.

- UI 특수문자 포함 조건: ✓ (`isContainSymbol` → `true`)
- 실제 비밀번호 유효성 검사: 실패 (`isPasswordValidate` → `false`)

사용자 입장에서는 조건을 모두 만족했다고 표시되지만 제출 시 오류가 발생합니다. line 62의 `// TODO::특수문자 명세 확인 후 수정` 주석은 이 불일치가 의도적으로 미해결 상태로 남겨진 것임을 나타냅니다.

### Root Cause

`VerifyPasswordFormatUseCase`는 UI 피드백(`isIncludeSymbol`)을 위해 `isContainSymbol()`(→ `FILTER_CONTAIN_SYMBOL`)을 사용하고, `isValidPassword()`(→ `FILTER_PASSWORD`)는 실제 비밀번호 유효성 검사(`SignupCheckingUseCase`, `OwnerSignupRequestEmailVerificationUseCase`, `ChangePasswordSmsUseCase`, `OwnerChangePasswordUseCase`)에 사용됩니다. 두 정규식이 서로 다른 특수문자 집합을 정의하므로 두 함수의 결과가 불일치합니다.

**수정 방향**: `FILTER_CONTAIN_SYMBOL`을 `FILTER_PASSWORD`의 화이트리스트 기준으로 **좁히는(tighten)** 방향으로 수정합니다. 반대로 `FILTER_PASSWORD`를 완화하는 방향은 서버 API 허용 범위를 초과하는 문자를 비밀번호로 받아들일 위험이 있으며, 서버 명세 변경을 수반하므로 채택하지 않습니다.

**단일 소스(Single Source of Truth)**: 특수문자 클래스 본체를 공통 상수 `SPECIAL_CHARS_CLASS`로 추출하고, `FILTER_PASSWORD`와 `FILTER_CONTAIN_SYMBOL` 양쪽이 이를 참조하도록 리팩토링합니다. 향후 허용 특수문자 목록이 변경될 때 두 곳을 별도로 수정해야 하는 실수를 구조적으로 방지합니다.

**참고 구현**: `FILTER_CONTAIN_ALPHABET`(`.*[a-zA-Z].*`)과 `FILTER_CONTAIN_NUMBER`(`.*[0-9].*`)는 이미 `FILTER_PASSWORD`의 각 조건과 동일한 문자 집합을 사용하여 일관성을 유지합니다. `FILTER_CONTAIN_SYMBOL`도 이와 동일한 패턴을 따라야 합니다.

**수정 불필요 파일**: `SignupCheckingUseCase`, `OwnerSignupRequestEmailVerificationUseCase`, `ChangePasswordSmsUseCase`, `OwnerChangePasswordUseCase`, `ValidationExtensions.kt`는 모두 `isPasswordValidate()`(= `FILTER_PASSWORD`) 경로만 사용하므로 수정 불필요합니다. `feature/user`의 `ChangePasswordViewModel`, `ChangePasswordChangePwdFragment`, `PasswordFormatState.kt`도 `PasswordFormat` 모델을 소비할 뿐이므로 수정 불필요합니다.

**별도 이슈 메모**: `OwnerSignupRequestEmailVerificationUseCase`에는 `SignupCheckingUseCase`와 달리 `password.contains(" ")` 체크가 없습니다. 본 픽스 후 공백은 `isIncludeSymbol = false`가 되어 UI 피드백은 정상화되지만, owner signup 흐름에서의 공백 입력 거부는 별도 이슈로 남습니다. 본 이슈 범위에 포함하지 않습니다.

## Changes

> 예상 변경 줄 수 ≈ 40줄 이내. 200줄 분할 기준 미해당, 단일 브랜치로 처리합니다.

### 1. `domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt`

**목표**: `SPECIAL_CHARS_CLASS` 공통 상수 추출, `FILTER_CONTAIN_SYMBOL` 화이트리스트로 통일, `TODO` 주석 제거.

**⚠️ 구현 주의사항 — `SPECIAL_CHARS_CLASS` 추출 방법**

`SPECIAL_CHARS_CLASS`의 값은 이 PLAN 본문에 렌더링된 예시를 복사하지 말고, 반드시 `PasswordUtil.kt:53`의 `(?=.*[…])` 룩어헤드 대괄호 안 본문을 소스 코드에서 직접(verbatim) 추출해 사용한다. 마크다운 렌더링은 특수문자를 누락·변형할 수 있으므로 PLAN 예시를 복사하면 정규식이 의도와 다르게 컴파일될 수 있다.

추출 후 다음 33개 항목이 모두 포함되었는지 반드시 점검한다:

`` ` ``, `₩`, `~`, `!`, `@`, `#`, `$`, `%`, `<`, `>`, `^`, `&`, `*`, `(`, `)`, `\-`, `=`, `+`, `_`, `?`, `:`, `;`, `"`, `'`, `,`, `.`, `{`, `}`, `|`, `\[`, `\]`, `/`, `\\`

**`companion object` 수정 내용**:

```kotlin
companion object {
    // 허용되는 특수문자 클래스 본체 — PasswordUtil.kt:53의 (?=.*[…]) 안에서 verbatim 추출
    // PLAN 본문 복사 금지. 추출 후 33개 문자 점검 필수.
    private const val SPECIAL_CHARS_CLASS = /* PasswordUtil.kt:53 룩어헤드 내부 본문 */

    // const val → val 변경 필수 (SPECIAL_CHARS_CLASS 보간 사용 시 const val 불가)
    private val FILTER_PASSWORD =
        """^(?=.*[a-zA-Z])(?=.*[$SPECIAL_CHARS_CLASS])(?=.*[0-9]).{6,18}${'$'}"""
    val PASSWORD_REGEX: Pattern = Pattern.compile(FILTER_PASSWORD)

    private const val FILTER_CONTAIN_ALPHABET = """.*[a-zA-Z].*"""
    val CONTAIN_ALPHABET_REGEX: Pattern = Pattern.compile(FILTER_CONTAIN_ALPHABET)

    private const val FILTER_CONTAIN_NUMBER = """.*[0-9].*"""
    val CONTAIN_NUMBER_REGEX: Pattern = Pattern.compile(FILTER_CONTAIN_NUMBER)

    // SPECIAL_CHARS_CLASS와 동일한 화이트리스트 기준 사용 (const val → val)
    // TODO::특수문자 명세 확인 후 수정 주석 제거
    private val FILTER_CONTAIN_SYMBOL = """.*[$SPECIAL_CHARS_CLASS].*"""
    val CONTAIN_SYMBOL_REGEX: Pattern = Pattern.compile(FILTER_CONTAIN_SYMBOL)
}
```

**검증 단계**: `FILTER_PASSWORD`를 출력하거나 단위 테스트에서 `PASSWORD_REGEX.pattern()`을 확인하여, 변경 후 생성된 정규식 문자열이 기존 line 53의 문자열과 byte-identical한지 확인한다.

변경 사항 요약:
- `SPECIAL_CHARS_CLASS` `private const val` 신규 추가 (단순 문자열 리터럴이므로 `const val` 가능; `%`는 식별자 시작 문자가 아니므로 `$%` 보간 충돌 없음)
- `FILTER_PASSWORD`: `const val` → `val` 변경, `$SPECIAL_CHARS_CLASS` 보간 사용
- `FILTER_CONTAIN_SYMBOL`: `const val` → `val` 변경, 기존 네거티브 매칭 패턴(`[^a-zA-Z0-9가-힣ㄱ-ㅎㅏ-ㅣ]`) → `[$SPECIAL_CHARS_CLASS]` 화이트리스트 교체
- line 62의 `// TODO::특수문자 명세 확인 후 수정` 주석 제거

### 2. `domain/src/test/java/in/koreatech/koin/domain/usecase/user/VerifyPasswordFormatUseCaseTest.kt`

**목표**: 버그 재현 케이스 추가 및 두 경로의 정합성(UI 판정 ↔ 실제 유효성 검사)을 직접 검증하는 테스트 추가.

기존 테스트는 모두 유지하고 아래를 추가합니다.

#### 2-1. `isIncludeSymbol` 경계 케이스 (단독 검증)

| 테스트 이름 | 입력 | 기대 `isIncludeSymbol` | 비고 |
|---|---|---|---|
| `비밀번호에 공백이 포함된 경우 기호로 인식하지 않는다` | `"abcde1 "` | `false` | 버그 재현 케이스 — 수정 전 정규식은 `true` 반환 |
| `비밀번호에 탭이 포함된 경우 기호로 인식하지 않는다` | `"abcde1\t"` | `false` | 제어 문자 경계 케이스 |
| `비밀번호에 이모지가 포함된 경우 기호로 인식하지 않는다` | `"abcde😀"` | `false` | 비-BMP 유니코드 경계 케이스 |
| `비밀번호에 화이트리스트 특수문자(@)가 포함된 경우 기호로 인식한다` | `"abcde@"` | `true` | 화이트리스트 추가 검증 |
| `비밀번호에 화이트리스트 특수문자([)가 포함된 경우 기호로 인식한다` | `"abcde["` | `true` | 이스케이프 필요 문자 정상 인식 검증 |

#### 2-2. 두 경로 정합성 검증 (MAJOR 회귀 방지)

두 정규식이 동일한 문자 집합을 사용하는지 직접 검증하는 테스트 2개를 추가합니다. 누군가 어느 한 쪽 정규식만 수정하면 이 테스트가 즉시 실패합니다.

```kotlin
@Test
fun `화이트리스트에 없는 공백은 isIncludeSymbol과 isPasswordValidate 양쪽에서 모두 특수문자로 인정되지 않는다`() {
    val password = "abcde1 "
    val result = VerifyPasswordFormatUseCase().invoke(password)
    // UI 피드백: 공백은 특수문자가 아님
    assertFalse(result.isIncludeSymbol)
    // 실제 유효성: 공백은 화이트리스트에 없으므로 통과 불가
    assertFalse(PasswordUtil().isPasswordValidate(password))
}

@Test
fun `화이트리스트 특수문자는 isIncludeSymbol과 isPasswordValidate 양쪽에서 모두 일관되게 특수문자로 인정된다`() {
    val password = "abcde1!"
    val result = VerifyPasswordFormatUseCase().invoke(password)
    // UI 피드백: 화이트리스트 문자(!)는 특수문자로 인정
    assertTrue(result.isIncludeSymbol)
    // 실제 유효성: 영문 + 숫자 + 화이트리스트 특수문자 + 길이 충족 → 통과
    assertTrue(PasswordUtil().isPasswordValidate(password))
}
```

## Commit Convention

```
fix: 비밀번호 특수문자 판별 정규식 불일치 수정 (#50)
```

## Checklist

- [ ] `domain/.../util/regex/PasswordUtil.kt` — `PasswordUtil.kt:53` 소스에서 `SPECIAL_CHARS_CLASS` verbatim 추출 (33개 문자 점검표 확인)
- [ ] `domain/.../util/regex/PasswordUtil.kt` — `FILTER_PASSWORD`, `FILTER_CONTAIN_SYMBOL` `const val` → `val` 변경
- [ ] `domain/.../util/regex/PasswordUtil.kt` — `FILTER_CONTAIN_SYMBOL` 화이트리스트(`[$SPECIAL_CHARS_CLASS]`) 교체, `TODO` 주석 제거
- [ ] `domain/.../util/regex/PasswordUtil.kt` — `PASSWORD_REGEX.pattern()` 출력으로 기존 line 53 문자열과 byte-identical 검증
- [ ] `domain/.../usecase/user/VerifyPasswordFormatUseCaseTest.kt` — 경계 케이스 5개 추가 (`isIncludeSymbol` 단독)
- [ ] `domain/.../usecase/user/VerifyPasswordFormatUseCaseTest.kt` — 두 경로 정합성 테스트 2개 추가
- [ ] `./gradlew ktlintFormat` 실행
- [ ] `./gradlew ktlintCheck` 통과 확인
- [ ] `./gradlew :domain:test` 단위 테스트 통과 확인
