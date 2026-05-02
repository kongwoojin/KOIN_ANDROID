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