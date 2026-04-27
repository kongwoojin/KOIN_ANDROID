충분한 컨텍스트를 확보했습니다. 리뷰를 작성합니다.

---

# Compose 리뷰

## Summary

이번 PR의 수정 범위(`SemesterViewModel.kt`)는 순수 ViewModel 로직 변경이며, Compose UI 레이어에서 `_sideEffect`(`MutableStateFlow`) 소비 구조는 이미 `Toast` 분기를 처리하고 있어 신규 Compose 버그 없이 올바르게 동작합니다.

## 문제점

### [MINOR] 1. `_sideEffect` StateFlow 중복 이벤트 소실 가능성

파일 경로: `feature/timetable/src/main/java/in/koreatech/koin/feature/timetable/viewmodel/SemesterViewModel.kt:81`  
소비처: `koin/src/main/java/in/koreatech/koin/ui/timetablev2/TimetableSemesterActivity.kt:190`

#### 리뷰 사항

`_sideEffect`가 `MutableStateFlow<SemesterSideEffect>`이고, UI 쪽에서는 `LaunchedEffect(sideEffect)`로 소비합니다. `StateFlow`는 연속으로 같은 값이 emit되면 두 번째 이후를 무시(deduplication)합니다.

`updateUserSemesters()` 내 `forEach`에서 학기 A, B 삭제가 연달아 실패할 경우:

```
delete A 실패 → _sideEffect = Toast("학기 삭제에 실패했습니다.")
delete B 실패 → _sideEffect = Toast("학기 삭제에 실패했습니다.") // 동일값, StateFlow가 무시
```

UI의 `LaunchedEffect`가 재실행되지 않아 두 번째 실패 알림이 사용자에게 전달되지 않습니다.

#### 수정 방향

IMPL.md에서 이미 이 구조적 한계를 인지하고 이번 PR 범위 밖으로 명시했으므로 즉각 수정 대상은 아닙니다. 향후 `_sideEffect`를 `Channel(BUFFERED)` 또는 `SharedFlow(replay=0)`로 교체하고, UI 소비처를 `LaunchedEffect` 대신 `collectAsStateWithLifecycle`+`collect`로 전환하는 별도 리팩터링 PR에서 해결하는 것이 적합합니다.

---

CRITICAL: 0  
MAJOR: 0  
MINOR: 1