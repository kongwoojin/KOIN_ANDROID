# Kotlin 리뷰

## Summary

PLAN.md 수정 범위(NetworkUtil.kt, TimetableRepositoryImpl.kt, BusRepositoryImpl.kt) 전체를 실제 파일로 확인했습니다. `CancellationException` 재던짐 누락 버그가 올바르게 수정되었으며, 아키텍처 경계 위반이나 런타임 예외 가능성 있는 회귀는 발견되지 않았습니다.

## 문제점

검토 결과 CRITICAL / MAJOR / MINOR 이슈 없음.

아래는 코드가 올바르게 구현되었음을 검증한 항목입니다.

**NetworkUtil.kt**
- Deprecated 버전(line 32)과 DSL 버전(line 72) 모두 `exceptionOrNull() ?: return this` 직후에 `if (exception is CancellationException) throw exception` 삽입 ✓
- `kotlinx.coroutines.CancellationException` import 추가 ✓

**BusRepositoryImpl.kt**
- 8개 `runCatching` 블록 전체에 `.onFailure { if (it is CancellationException) throw it }` 체인 적용 ✓
- 로컬 데이터소스(`getLastShownNoticeId`, `saveLastShownNoticeId`)도 누락 없이 포함 ✓

**TimetableRepositoryImpl.kt**
- 15개 `runCatching` 블록 전체 적용 ✓
- `postTimetableFrame`: `recoverCatching` 내부에서 `throw it`이 다시 `runCatching`에 잡혀 `Result.failure(CancellationException)`로 변환되는 점을 `.onFailure`가 후속 처리 — PLAN.md 분석과 일치하며 동작 정확 ✓
- `deleteTimetableFrame`, `deleteTimetableLecture`, `deleteTimetableFrameLecture`, `deleteAllTimetableFrame`: 명시적 `Unit` 추가로 `.onFailure` 체인 추가 후 타입 추론 단절 방지 ✓
- `deleteTimetableLectures`: `if (!response.isSuccessful)` 블록이 암시적으로 `Unit`을 반환하므로 명시적 `Unit` 불필요 — 현재 코드 정확 ✓
- `putTimetableLectures(key, value)`: `return getTimetableLectures(...)` 비로컬 반환으로 성공 경로에서 외부 `.onFailure`가 dead code가 되지만, `getTimetableLectures`가 이미 자체적으로 `CancellationException`을 재던짐하여 커버리지 완전 ✓

---

CRITICAL: 0
MAJOR: 0
MINOR: 0