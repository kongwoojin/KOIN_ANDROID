# 구현 결과

## Summary
비밀번호 특수문자 검증 정규식의 불일치 문제를 해결했습니다. `SPECIAL_CHARS_CLASS` 공통 상수를 추출하여 `FILTER_PASSWORD`와 `FILTER_CONTAIN_SYMBOL`을 동일한 화이트리스트 기준으로 통일하고, UI 피드백과 실제 유효성 검사 간의 일관성을 보장하는 테스트 7개를 추가했습니다.

## 브랜치
- `fix/50`

## 수정한 파일
- `domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt` — `SPECIAL_CHARS_CLASS` 공통 상수 추출, `FILTER_PASSWORD`·`FILTER_CONTAIN_SYMBOL` 동일 기준 통일, `TODO` 주석 제거
- `domain/src/test/java/in/koreatech/koin/domain/usecase/user/VerifyPasswordFormatUseCaseTest.kt` — 경계 케이스 5개 + 정합성 검증 테스트 2개 추가

## 새로 만든 파일
- 없음

## 주요 구현 내용

### 1. `PasswordUtil.kt` — 단일 소스(Single Source of Truth) 달성

**추출된 상수**:
```kotlin
private const val SPECIAL_CHARS_CLASS = """`₩~!@#$%<>^&*()=+_?:;"',.{}|\[\]/\\-"""
```
- 원본 `FILTER_PASSWORD`의 line 53 특수문자 클래스 verbatim 추출
- 33개 문자 모두 포함 확인 완료

**정규식 통일**:
- `FILTER_PASSWORD`: `$SPECIAL_CHARS_CLASS` 보간 사용 → 기존과 동일
- `FILTER_CONTAIN_SYMBOL`: 네거티브 매칭(`[^a-zA-Z0-9가-힣...]`)에서 화이트리스트(`[$SPECIAL_CHARS_CLASS]`)로 변경
- 결과: 두 정규식이 동일한 33개 특수문자만 인식 → UI 판정과 실제 유효성 검사 일관성 보장

**하이픈 위치**:
- 기존: 맨 뒤 배치 (`...|\[\]/\\-`) 유지
- 효과: 문자 범위 메타문자로의 오인 방지 (예: `-]` 오인 방지)

### 2. `VerifyPasswordFormatUseCaseTest.kt` — 회귀 방지 테스트 7개 추가

**경계 케이스 5개** (line 81–114):
- `공백(" ")`: `isIncludeSymbol = false` ← 버그 재현 케이스
- `탭("\t")`: `isIncludeSymbol = false` ← 제어 문자 경계
- `이모지("😀")`: `isIncludeSymbol = false` ← 비-BMP 유니코드 경계
- `화이트리스트 문자("@")`: `isIncludeSymbol = true` ← 화이트리스트 추가 검증
- `화이트리스트 문자("[")`: `isIncludeSymbol = true` ← 이스케이프 필요 문자 정상 인식

**정합성 검증 2개** (line 117–135):
- 화이트리스트 밖 문자(공백): `isIncludeSymbol = false` **AND** `isPasswordValidate() = false` → 양쪽 일관성 보장
- 화이트리스트 내 문자("!"): `isIncludeSymbol = true` **AND** `isPasswordValidate() = true` → 양쪽 일관성 보장

**기존 테스트**: 8개 모두 유지 (영문, 숫자, 기호, 길이 검증)

### 3. 패키지 명명 규칙
- 모든 파일: `` `in`.koreatech.koin... `` 백틱 이스케이프 적용
- 어노테이션: `@Inject`, `@Before`, `@Test` 모두 정상 유지

## Gradle 검증
- `./gradlew ktlintFormat`: ✅
- `./gradlew ktlintCheck`: ✅
- `./gradlew :domain:test`: ✅ (UP-TO-DATE)

## 범위 외 수정
- 없음

## 남은 TODO
- 없음
