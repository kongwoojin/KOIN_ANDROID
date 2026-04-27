이제 항목별로 교차 검증을 진행합니다.

**변경 파일 목록 확인 (3개):**
- `data/.../repository/BusRepositoryImpl.kt`
- `data/.../repository/TimetableRepositoryImpl.kt`
- `data/.../util/NetworkUtil.kt`

---

# Completeness 리뷰

## Summary

PLAN.md가 요구한 3개 파일 모두 수정됐으며, IMPL.md의 기재 내용과 실제 git diff가 완전히 일치합니다. 범위 외 파일 변경은 없습니다.

## 문제점

없음.

---

## 세부 검증 결과

### Step 1: `NetworkUtil.kt`

| 항목 | PLAN.md 요구 | 실제 코드 | 판정 |
|------|------------|---------|------|
| `import kotlinx.coroutines.CancellationException` 추가 | ✅ | line 7 확인 | ✅ |
| Deprecated 버전 `CancellationException` re-throw | ✅ | line 32 확인 | ✅ |
| DSL 버전 `CancellationException` re-throw | ✅ | line 72 확인 | ✅ |

### Step 2: `TimetableRepositoryImpl.kt` — 15개 함수 전수 검증

| 함수 | `.onFailure` 추가 | `Unit` 보완 |
|------|----------------|-----------|
| `getTimetableLectures(Int)` | line 67 ✅ | — |
| `getTimetableLectures(String)` | line 78 ✅ | — |
| `putTimetableLectures(TimetableLecturesQuery)` | line 83 ✅ | — |
| `putTimetableLectures(String, TimetableLectures)` | line 97 ✅ | — |
| `putTimetableFrame` | line 112 ✅ | — |
| `postTimetableLectures` | line 126 ✅ | — |
| `postTimetableCustomLectures` | line 155 ✅ | — |
| `postTimetableBasicLectures` | line 178 ✅ | — |
| `postTimetableFrame` (이전 계획에서 누락 → 재포함) | line 195 ✅ | — |
| `postRollbackFrame` | line 200 ✅ | — |
| `deleteTimetableFrame` | line 206 ✅ | line 205 ✅ |
| `deleteTimetableLecture` | line 212 ✅ | line 211 ✅ |
| `deleteTimetableFrameLecture` | line 221 ✅ | line 220 ✅ |
| `deleteTimetableLectures` | line 229 ✅ | 불필요 (이미 `if/throw`로 Unit) |
| `deleteAllTimetableFrame` | line 235 ✅ | line 234 ✅ |
| `import kotlinx.coroutines.CancellationException` | line 27 ✅ | — |

### Step 3: `BusRepositoryImpl.kt` — 8개 함수 전수 검증

| 함수 | `.onFailure` 추가 |
|------|----------------|
| `fetchBusNotice` | line 25 ✅ |
| `fetchShuttleTimetable` | line 31 ✅ |
| `fetchShuttleCourses` | line 37 ✅ |
| `fetchExpressTimetable` | line 43 ✅ |
| `fetchCityTimetable` | line 52 ✅ |
| `fetchBusSearchResult` | line 70 ✅ |
| `getLastShownNoticeId` | line 76 ✅ |
| `saveLastShownNoticeId` | line 82 ✅ |
| `import kotlinx.coroutines.CancellationException` | line 16 ✅ |

### 범위 외 파일 수정 여부

git diff에 변경된 파일은 위 3개뿐이며, IMPL.md에 미기재 파일이나 PLAN.md 범위 외 파일 수정은 없습니다.

---

```
CRITICAL: 0
MAJOR:    0
MINOR:    0
```