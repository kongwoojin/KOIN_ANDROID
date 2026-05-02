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
