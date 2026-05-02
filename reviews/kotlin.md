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
