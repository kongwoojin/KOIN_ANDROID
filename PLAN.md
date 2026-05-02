- Issue Type: [bugfix]
- Issue ID: [#46]
- Branch Name: [fix/46]

# [#46] SemesterViewModel 에러 발생 시 사용자 피드백 누락

## Problem
`SemesterViewModel`에서 에러가 발생할 때 `Timber.d()` 로그만 남기고 `SemesterSideEffect`를 발행하지 않아 사용자에게 아무런 피드백이 전달되지 않습니다. 영향 위치는 총 5곳이며, 삭제 성공 SnackBar가 API 완료 전에 Activity에서 즉시 발행되는 타이밍 버그도 동반됩니다.

1. **`initialScreenState` 외부 `.catch {}` 블록** (line 133–136): 에러 발생 시 `ScreenState()` (IDLE)만 emit하고 Toast 없음
2. **`onClickAddTimetable` onFailure** (line 218–219): Timber 로그만 남김
3. **`editTimetableFrame` onFailure** (line 282–283): Timber 로그만 남김
4. **`deleteTimetableFrame` onFailure** (line 320–321): Timber 로그만 남김
5. **`restoreTimetableFrame` onFailure** (line 361–363): Timber 로그만 남김

추가로, `TimetableSemesterActivity`의 `onDeleteFrame` 콜백(line 120–127)에서 `viewModel.deleteTimetableFrame()` 호출 직후 API 응답을 기다리지 않고 즉시 `SemesterSideEffect.SnackBar("...삭제되었어요")`를 발행합니다. 삭제 실패 시에도 "삭제되었어요" SnackBar가 표시되는 구조 버그입니다.

### Root Cause

`SemesterSideEffect`에는 `SnackBar`, `Toast`, `Nothing` 타입이 이미 정의되어 있고, `TimetableSemesterActivity`의 `LaunchedEffect(sideEffect)` 소비 인프라도 갖춰져 있습니다. 그러나 `SemesterViewModel`의 `onFailure` / `.catch {}` 경로에서 `_sideEffect.value`를 설정하지 않아 사용자 알림이 누락됩니다. `TODO::hyeok` 주석으로 미구현 상태임이 표시되어 있습니다.

삭제 SnackBar 조기 발행 문제는 성공 여부를 모르는 시점에 Activity가 직접 side effect를 발행하는 구조에서 비롯됩니다.

## 참고 구현

**`SemesterViewModel` 내 기존 올바른 패턴** (`updateUserSemesters()` line 250–253):
```kotlin
.onFailure {
    it.message?.let { errorMessage ->
        _sideEffect.value = SemesterSideEffect.Toast(errorMessage)
    }
}
```

**`TimetableViewModel`의 에러 핸들링 패턴** (`feature/timetable/.../viewmodel/TimetableViewModel.kt`):
```kotlin
.onFailure {
    updateLoading(false)
    _sideEffect.value = TimetableSideEffect.Toast("Failed get timetable lectures : " + it.message.orEmpty())
}
```

두 ViewModel 모두 `MutableStateFlow<SideEffect>` + `Nothing` 센티널 리셋 패턴을 일관되게 사용합니다. `LaunchedEffect(sideEffect)` key는 `Toast("a") → Nothing → Toast("a")` 전환마다 재실행되므로 동일 메시지 연속 발생 시에도 사용자 피드백이 정상 전달됩니다.

## 설계 결정

**`MutableStateFlow<SemesterSideEffect>` 타입 유지**: 기존 패턴(`MutableStateFlow`, `Nothing` 센티널 리셋)을 그대로 유지합니다. 타입 변경은 이 이슈 범위 밖이며, `_sideEffect.value = ...` 쓰기 방식과 `LaunchedEffect(sideEffect)`·`collectAsStateWithLifecycle()` 소비 방식 모두 기존과 동일하게 유지합니다.

**피드백 방식: `SemesterSideEffect.Toast` 채택**: `ScreenStateUIMode.ERROR` 추가 방안은 `SemesterScreen.kt` 에러 UI 신규 작성이 필요하여 변경 범위가 넓습니다. `SemesterSideEffect.Toast`는 소비 인프라가 완비되어 있어 UI 변경 없이 에러를 사용자에게 전달할 수 있습니다.

**삭제 성공 SnackBar: ViewModel.onSuccess로 이동**: `target` 변수가 `let { target -> ... }` 스코프 내 `onSuccess`까지 접근 가능하므로 `_deletedFrameSemester.value = ...` 직후에 안전하게 SnackBar를 발행할 수 있습니다.

**`initialScreenState` catch 블록 접근 안전성**: `_sideEffect`(line 80)는 `initialScreenState`(line 108)보다 먼저 선언·초기화되므로 `.catch {}` 클로저에서 `_sideEffect.value`를 참조하는 것은 안전합니다.

## 수정 계획

변경 범위는 약 10줄이므로 단일 브랜치 `fix/46`으로 충분합니다. **import, 타입, 수집 방식은 일체 변경하지 않습니다.**

### 수정 대상 파일

| 파일 | 수정 내용 |
|------|-----------|
| `feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt` | 5개 실패 경로 Toast 추가 + 삭제 성공 SnackBar 추가 |
| `koin/src/main/java/in/koreatech/koin/ui/timetablev2/TimetableSemesterActivity.kt` | `onDeleteFrame` 내 즉시 SnackBar 발행 제거 |

---

### 수정 1 — SemesterViewModel.kt: `initialScreenState` 외부 `.catch {}` (line 133–136)

**현재:**
```kotlin
}.catch {
    // TODO::hyeok Error 상태 추가
    emit(ScreenState())
}
```

**수정:**
```kotlin
}.catch {
    _sideEffect.value = SemesterSideEffect.Toast("시간표 데이터를 불러오는 데 실패했습니다.")
    emit(ScreenState())
}
```

- `emit(ScreenState())` 유지: 기존 IDLE 분기 처리와 호환
- TODO 주석 제거

---

### 수정 2 — SemesterViewModel.kt: `onClickAddTimetable` onFailure (line 218–219)

**현재:**
```kotlin
}.onFailure {
    Timber.d("시간표 추가 실패")
}
```

**수정:**
```kotlin
}.onFailure {
    Timber.d("시간표 추가 실패")
    _sideEffect.value = SemesterSideEffect.Toast("시간표 추가에 실패했습니다.")
}
```

---

### 수정 3 — SemesterViewModel.kt: `editTimetableFrame` onFailure (line 282–283)

**현재:**
```kotlin
}.onFailure {
    Timber.d("시간표 프레임 수정 실패")
}
```

**수정:**
```kotlin
}.onFailure {
    Timber.d("시간표 프레임 수정 실패")
    _sideEffect.value = SemesterSideEffect.Toast("시간표 수정에 실패했습니다.")
}
```

---

### 수정 4 — SemesterViewModel.kt: `deleteTimetableFrame` onSuccess 내 SnackBar 추가 + onFailure Toast 추가 (line 293–321)

`_deletedFrameSemester.value = dialogUiState.value.editedSemester` 직후, `if (currentTimetableId.value == target.id)` 블록 이전에 SnackBar 발행을 추가합니다. `target`은 `let` 스코프 내에서 접근 가능합니다.

**현재 (onSuccess 중간 ~ onFailure):**
```kotlin
                // 삭제한 프레임과 학기 저장
                _deletedFrame.value = target
                _deletedFrameSemester.value = dialogUiState.value.editedSemester

                // 시간표에서 선택한 프레임이 삭제된 경우..
                if (currentTimetableId.value == target.id) {
                    ...
                }
            }.onFailure {
                Timber.d("시간표 프레임 삭제 실패")
            }
```

**수정:**
```kotlin
                // 삭제한 프레임과 학기 저장
                _deletedFrame.value = target
                _deletedFrameSemester.value = dialogUiState.value.editedSemester

                _sideEffect.value = SemesterSideEffect.SnackBar("${target.timetableName}가 삭제되었어요")

                // 시간표에서 선택한 프레임이 삭제된 경우..
                if (currentTimetableId.value == target.id) {
                    ...
                }
            }.onFailure {
                Timber.d("시간표 프레임 삭제 실패")
                _sideEffect.value = SemesterSideEffect.Toast("시간표 삭제에 실패했습니다.")
            }
```

---

### 수정 5 — SemesterViewModel.kt: `restoreTimetableFrame` onFailure (line 361–363)

**현재:**
```kotlin
.onFailure {
    // TODO::hyeok 에러 핸들링
    Timber.d("롤백 실패")
}
```

**수정:**
```kotlin
.onFailure {
    Timber.d("롤백 실패")
    _sideEffect.value = SemesterSideEffect.Toast("시간표 복구에 실패했습니다.")
}
```

- TODO 주석 제거

---

### 수정 6 — TimetableSemesterActivity.kt: `onDeleteFrame` 콜백 즉시 SnackBar 발행 제거 (line 120–127)

**현재:**
```kotlin
onDeleteFrame = {
    viewModel.deleteTimetableFrame()
    viewModel.updateEditTimetableDialogVisible(false)
    viewModel.updateSideEffect(
        SemesterSideEffect.SnackBar(
            "${dialogUiState.editedTimetableFrame?.timetableName}가 삭제되었어요"
        )
    )
}
```

**수정:**
```kotlin
onDeleteFrame = {
    viewModel.deleteTimetableFrame()
    viewModel.updateEditTimetableDialogVisible(false)
}
```

- `LaunchedEffect(sideEffect)`, `collectAsStateWithLifecycle`, `Nothing` 리셋 패턴 — **변경하지 않음**

---

## 수정하지 않는 파일

| 파일 | 이유 |
|------|------|
| `SemesterSideEffect.kt` | `Toast`, `SnackBar`, `Nothing` 타입 이미 정의됨 |
| `SemesterScreen.kt` | `ScreenStateUIMode.ERROR` 추가 방안 미채택 |
| `ScreenStateUIMode` enum | ERROR 상태 추가 불필요 (Toast로 커버) |
| `TimetableViewModel.kt` | 이 이슈 범위 밖 |
| `SemesterViewModel.kt` (import, 타입, `_sideEffect` 선언, `updateSideEffect`, line 252) | 기존 패턴 유지, 변경 불필요 |

## 커밋 컨벤션

```
fix: SemesterViewModel 에러 발생 시 사용자 피드백 누락 수정 (#46)
```

## 검증 방법

- 네트워크 단절 상태에서 시간표 학기 관리 화면 진입 → "시간표 데이터를 불러오는 데 실패했습니다." Toast 표시 확인
- 시간표 추가 API 실패 시 "시간표 추가에 실패했습니다." Toast 표시 확인
- 시간표 이름 수정 API 실패 시 "시간표 수정에 실패했습니다." Toast 표시 확인
- 시간표 삭제 API **성공** 시 "X가 삭제되었어요" SnackBar **1회**만 표시 확인 (Activity 즉시 발행 제거 검증)
- 시간표 삭제 API **실패** 시 "시간표 삭제에 실패했습니다." Toast 표시, 성공 SnackBar 미표시 확인
- 롤백 API 실패 시 "시간표 복구에 실패했습니다." Toast 표시 확인
- 정상 시나리오(네트워크 정상)에서 기존 기능 정상 동작 확인
- `./gradlew ktlintCheck` 통과 확인
