# 코드 리뷰 (통합)

## 요약

| 영역 | CRITICAL | MAJOR | MINOR |
|---|---|---|---|
| 🔒 Security  | 0   | 0   | 0   |
| 🎨 Compose   | 0  | 2  | 2  |
| 🔵 Kotlin    | 2    | 2    | 1    |
| ✅ Lint      | 0  | 0  | 0  |
| 🔎 SonarQube | 0 | 0 | 0 |
| 📋 Completeness | 0 | 1 | 0 |
| **합계**     | **2** | **5** | **3** |

---

## 🔒 Security

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
---

## 🎨 Compose

# Compose 리뷰

## Summary
`PLAN.md`에 명시된 에러 핸들링 및 피드백 누락 문제를 충실히 구현했습니다. 특히 삭제 성공 피드백을 ViewModel의 `onSuccess`로 옮겨 비즈니스 로직과 UI 피드백의 정합성을 맞춘 점과, `@Stable` 어노테이션 추가 및 `CancellationException` 처리를 통해 안정성을 높인 점이 우수합니다. 다만, `StateFlow` 초기화 구조에서 발생할 수 있는 잠재적 레이스 컨디션과 `LaunchedEffect`를 통한 상태 업데이트 방식은 개선이 필요합니다.

## 문제점

### [MAJOR] 1. ScreenState 초기화 및 업데이트 레이스 컨디션
파일 경로: `feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt`
#### 리뷰 사항
`screenState`를 생성할 때 `flow { ... emitAll(_screenState) }` 패턴을 사용하고 있습니다. `initialScreenState.first()`가 비동기로 데이터를 가져오는 동안 외부에서 `updateXXXXDialogVisible` 등의 함수가 호출되어 `_screenState`를 업데이트하면, 나중에 `initialState`가 방출되면서 이전의 업데이트 내용이 덮어씌워질 위험이 있습니다.
#### 수정 방향
`initialScreenState`와 `_screenState`를 개별적으로 관리하기보다, `combine`이나 `stateIn`의 `initialValue`를 활용하여 상태가 원자적으로(atomically) 합쳐지도록 구조를 변경해야 합니다. (이미 `IMPL.md` 남은 TODO에 인지된 사항이나, Compose UI의 상태 일관성에 치명적일 수 있어 MAJOR로 분류합니다.)

### [MAJOR] 2. Side Effect를 통한 상태 업데이트 (LaunchedEffect 내 updateScreenMode)
파일 경로: `koin/src/main/java/in/koreatech/koin/ui/timetablev2/TimetableSemesterActivity.kt`
#### 리뷰 사항
```kotlin
LaunchedEffect(screenState.userTimetableFrames) {
    if (screenState.mode == ScreenStateUIMode.IDLE) return@LaunchedEffect
    if (screenState.userTimetableFrames.isEmpty()) {
        viewModel.updateScreenMode(ScreenStateUIMode.EMPTY)
    } else {
        viewModel.updateScreenMode(ScreenStateUIMode.BASIC)
    }
}
```
`userTimetableFrames` 변경에 따라 `mode`를 업데이트하는 로직이 UI 레이어의 `LaunchedEffect`에 존재합니다. 이는 불필요한 리컴포지션을 유발하며, "UI 상태가 다시 UI 상태를 변경"하는 안티 패턴입니다.
#### 수정 방향
해당 로직은 ViewModel 내에서 `screenState`를 정의할 때 `map` 또는 `combine`을 통해 파생 상태(derived state)로 처리해야 합니다.

### [MINOR] 3. 삭제 중 상태(isDeletingFrame)의 UI 미적용
파일 경로: `feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt`
#### 리뷰 사항
중복 클릭 방지를 위해 `_isDeletingFrame` 상태를 추가하고 `deleteTimetableFrame()` 내부에서 가드 로직을 넣었으나, 실제 UI(`EditTimetableFrameDialog`)에는 이 상태가 전달되지 않아 사용자는 버튼을 계속 클릭할 수 있는 상태로 남을 수 있습니다.
#### 수정 방향
`EditTimetableFrameDialog`에 `isDeleting` 파라미터를 추가하여 삭제 중일 때는 버튼을 `enabled = false` 처리하거나 로딩 인디케이터를 보여주는 것이 좋습니다. (현재는 다이얼로그를 즉시 닫으므로 영향이 적으나, 네트워크 지연 시 사용자 경험을 위해 필요합니다.)

### [MINOR] 4. @Stable 어노테이션의 적절성
파일 경로: `feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt`
#### 리뷰 사항
`SemesterDialogUiState`에 `@Stable`을 추가한 것은 좋으나, 내부 프로퍼티인 `SemesterModel`, `TimetableFrame` 등이 실제 불변(Immutable)인지 확인이 필요합니다. 만약 이들이 `data class`이고 모든 필드가 `val`이라면 안정성이 보장되지만, 그렇지 않다면 컴파일러를 속이는 결과가 될 수 있습니다.
#### 수정 방향
도메인 모델(`SemesterModel`, `TimetableFrame`) 자체에 `@Immutable` 또는 `@Stable`을 부여하거나, UI 레이어 전용 안정적 모델을 사용하는 것을 권장합니다.

CRITICAL: 0
MAJOR: 2
MINOR: 2

---

## 🔵 Kotlin

# Kotlin 리뷰

## Summary
코드 내에 파일 경로가 식별자(Label, Annotation, Qualifier) 자리에 삽입되는 치명적인 구문 오류가 다수 발견되었습니다. 또한 프로젝트의 특수 규칙인 `in` 패키지 백틱 이스케이프가 준수되지 않았습니다. 아키텍처적으로 에러 핸들링과 중복 요청 방지 로직을 추가한 방향성은 적절하나, 실제 코드가 컴파일 불가능한 상태입니다.

## 문제점

### [CRITICAL] 1. 컴파일 불가능한 구문 오류 (Hallucinated Identifiers)
파일 경로: `feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt`

#### 리뷰 사항
코드의 여러 곳에서 실제 Kotlin 키워드나 식별자 대신 파일 경로가 삽입되어 있습니다. 이는 정상적인 코드로 볼 수 없으며 컴파일이 불가능합니다.
- **Label 오류**: `restoreTimetableFrame` 함수 내 `return @feature/callvan/...` (line 359-360). `launch` 블록 내에서의 반환은 `return@launch` 형태여야 하며, 파일 경로를 라벨로 사용할 수 없습니다.
- **Annotation 오류**: `SemesterDialogUiState` 클래스 선언 위 `@core/designsystem/.../StableIcon.kt` (line 451). `@Stable` 어노테이션 대신 파일 경로가 들어갔습니다.
- **Qualifier 오류**: 클래스 생성자 내 `@core/src/main/java/in/koreatech/koin/core/qualifier/InjectQualifier.kt` (line 23). `@Inject` 또는 특정 Qualifier 대신 경로가 삽입되었습니다.
- **논리 연산자 파손**: `_deletedFrame.value != null __GIT_DIFF____GIT_DIFF__ _deletedFrameSemester.value != null` (line 357). `&&` 연산자가 깨진 문자열로 대체되었습니다.

#### 수정 방향
모든 파일 경로 형태의 텍스트를 실제 Kotlin 문법(`@Stable`, `@Inject`, `return@launch`, `&&` 등)으로 교체해야 합니다.

### [MAJOR] 2. 프로젝트 규칙 위반: `in` 패키지 백틱 이스케이프 누락
파일 경로: `feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt` 등 수정된 모든 파일

#### 리뷰 사항
프로젝트 가이드라인(AGENTS.md)에 따라 `in` 예약어가 포함된 패키지명은 반드시 백틱으로 감싸야 합니다 (`` `in`.koreatech.koin... ``). 현재 수정된 파일들의 import 구문에서 이 규칙이 지켜지지 않았습니다.
- 예: `import in.koreatech.koin.feature.timetable.model.SemesterModel`

#### 수정 방향
모든 `in` 패키지 경로를 `` `in`.koreatech.koin `` 형태로 수정하세요.

### [MAJOR] 3. Coroutine 비정상 반환 (Non-local return)
파일 경로: `feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt`

#### 리뷰 사항
`restoreTimetableFrame` 함수의 `viewModelScope.launch` 블록 내부에서 `return`을 시도하고 있습니다. Kotlin에서 `launch`와 같은 고차 함수(lambda) 내부에서는 라벨이 없는 일반 `return`을 사용할 수 없습니다(inline 함수 제외). 

#### 수정 방향
`return@launch`를 사용하여 해당 코루틴 블록만 종료하도록 수정해야 합니다. (단, 현재는 파일 경로 라벨 문제와 겹쳐 있습니다.)

### [MINOR] 4. `_isDeletingFrame` 상태 관리의 안전성
파일 경로: `feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt`

#### 리뷰 사항
`deleteTimetableFrame`에서 중복 클릭 방지를 위해 `_isDeletingFrame`을 사용한 것은 좋으나, `onSuccess`/`onFailure` 내부에서만 해제하고 있습니다. 만약 `deleteTimetableFrameUseCase` 호출 전후로 예상치 못한 예외가 발생할 경우(비록 `runCatching`이 되어 있더라도 코루틴 내부 로직 등에서) 상태가 `true`로 고정될 위험이 있습니다.

#### 수정 방향
`try-finally` 블록을 활용하여 어떤 상황에서도 `_isDeletingFrame.value = false`가 호출되도록 보장하는 것이 더 안전합니다.

---

CRITICAL: 2
MAJOR: 2
MINOR: 1

---

## ✅ Lint

# Lint 리뷰

## Summary
- `./gradlew ktlintCheck`:    ✅ 통과
- `./gradlew spotlessCheck`: ✅ 통과
- `./gradlew detekt`:         ✅ 통과
- `./gradlew lint`:           ✅ 통과
- ktlint 위반 건수: 0
0
- detekt 위반 건수: 0
0
- Android lint 오류: 0, 경고: 915

CRITICAL: 0
MAJOR: 0
MINOR: 0

---

## 🔎 SonarQube

## SonarQube 리뷰

### Summary
**SonarQube 미설정** — 프로젝트에 연결된 SonarQube 인스턴스를 찾을 수 없어 스니펫 분석으로 대체했습니다. 수동 코드 검토 결과, **변경된 Kotlin 코드에서 SonarQube 수준의 CRITICAL/MAJOR 이슈는 발견되지 않았습니다.**

---

### 분석 결과

#### ✅ 올바른 에러 처리 패턴
- **CancellationException 처리**: 모든 `onFailure` 및 `.catch` 블록에서 `if (it is CancellationException) throw it` 추가 ✓
- **Side Effect 발행**: 5개 실패 경로 모두 `_sideEffect.value = SemesterSideEffect.Toast(...)` 추가 ✓
- **Side Effect 리셋 패턴**: 기존 `Nothing` 센티널 리셋 패턴 유지 ✓

#### ✅ Null Safety & 상태 관리
- `?.let { ... }` 스코프 안전 사용
- `?: return@launch` 조기 반환으로 null pointer 방지
- `_isDeletingFrame` 상태 플래그로 중복 클릭 방지 (메인 스레드 실행이므로 race condition 없음)

#### ✅ 복잡도 검토
- `deleteTimetableFrame()` onSuccess 블록:
  - 인지 복잡도(Cognitive Complexity) ~6 (임계 15 이내)
  - 명확한 로직 흐름 (학기 삭제 여부에 따른 분기)
  - 과도한 복잡도 없음 ✓

- `restoreTimetableFrame()` 리팩토링:
  - `takeIf { ... }?.let` → `val x = ... ?: return` 패턴으로 개선
  - 가독성 및 유지보수성 향상

#### ✅ 메모리/리소스 관리
- 모든 비동기 작업이 `viewModelScope.launch` 내에서 수행 → ViewModel 소멸 시 자동 취소
- `StateFlow` 초기화 및 관리 정상

#### ⚠️ 코드 중복 (경미)
```kotlin
_isDeletingFrame.value = false  // 2회 반복 (success, failure)
```
→ 명시적 에러 처리를 위한 필요한 반복 (허용 범위)

---

### Quality Gate
- **상태**: NOT_CONFIGURED (SonarQube 미설정)
- **스니펫 분석 결과**: CRITICAL 0 / MAJOR 0 / MINOR 0

---

### 결론
**SonarQube 코드 품질 관점**: 🟢 **통과**

변경된 코드는:
- 에러 처리 규칙을 일관되게 준수
- Kotlin null safety 지킴
- CoroutineScope 관리 정상
- 인지 복잡도 임계 범위 내

**다른 리뷰어(Security/Compose/Kotlin/Lint)의 피드백에 따른 추가 수정 사항은 본 리뷰 범위 외입니다.**

---

## 📋 Completeness

# Completeness 리뷰

## Summary
PLAN.md의 핵심 목적이었던 사용자 피드백 누락 보완과 삭제 성공 SnackBar 발행 위치 이동은 실제 코드에 반영돼 있습니다. 다만 구현 결과가 PLAN.md에서 합의한 최소 변경 범위를 넘어섰고, 그 범위 확장이 `IMPL.md`의 accepted 범위로 정리되지 않아 계획-구현 정합성에는 문제가 있습니다.

## 문제점

### [MAJOR] 1. PLAN.md에서 무변경으로 둔다고 한 영역까지 실제 구현이 확장됐습니다
파일 경로: [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:23)

#### 리뷰 사항
PLAN.md는 이 이슈를 “약 10줄” 수준의 수정으로 정의했고, 특히 `SemesterViewModel.kt`의 `import, 타입, 수집 방식은 일체 변경하지 않습니다`, `import, 타입, _sideEffect 선언 ... 변경 불필요`라고 명시했습니다. 그런데 실제 diff에는 다음과 같은 추가 확장이 포함돼 있습니다.

- `CancellationException` import 추가: [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:23)
- 삭제 중복 방지 상태 추가: `_isDeletingFrame`, `isDeletingFrame`: [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:104)
- PLAN에 없던 학기 삭제 실패 Toast 추가: [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:250)
- `refreshSemesterTimetableFrames()`의 catch 동작 변경: [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:393)
- `restoreTimetableFrame()` 내부 구조 리팩터링: [SemesterViewModel.kt](/home/kongjak/Work/Android/KOIN_ANDROID/.worktrees/KOIN_ANDROID-46/feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:349)

이 중 `@Stable` 추가만 `IMPL.md`의 `범위 외 수정 (accepted)`에 적혀 있고, 나머지 범위 확장은 accepted로 정리되지 않았습니다. 즉, “계획한 변경을 그대로 수행했는지” 기준에서는 계획-구현 일치성이 깨졌습니다.

#### 수정 방향
다음 둘 중 하나로 정리돼야 합니다.

- 실제 확장이 필요했다면, `PLAN.md`와 `IMPL.md`의 accepted 범위에 `_isDeletingFrame`, `CancellationException` 처리, 학기 삭제 실패 Toast, restore 로직 정리까지 명시해 범위 확장을 합의된 작업으로 문서화합니다.
- 최소 변경 계획을 엄격히 지키려면, 이번 이슈 목적과 직접 무관한 확장 수정은 되돌리고 PLAN에 적힌 6개 변경만 남깁니다.

CRITICAL: 0  
MAJOR: 1  
MINOR: 0
---

CRITICAL: 2
MAJOR: 5
MINOR: 3
