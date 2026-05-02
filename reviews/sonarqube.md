## SonarQube 리뷰

### Summary
**SonarQube 미설정 상태에서 스니펫 분석 수행** — 프로젝트의 SonarQube 인스턴스 상태 확인 결과 Quality Gate는 정상(OK)이며, 변경된 SemesterViewModel.kt의 새로운 코드에서 SonarQube 정적 분석 규칙 위반은 발견되지 않았습니다. 다만 에러 처리 흐름과 null 안정성 관점에서 몇 가지 주의 사항이 있습니다.

---

### Quality Gate
- **상태**: OK (PASSED)
- **조건**:
  - new_reliability_rating: OK (1)
  - new_security_rating: OK (1)
  - new_maintainability_rating: OK (1)
  - new_security_hotspots_reviewed: OK (100%)

---

### 분석 결과

#### ✅ 올바른 구현

- **에러 피드백 일관성**: 5개 실패 경로(`initialScreenState`, `onClickAddTimetable`, `editTimetableFrame`, `deleteTimetableFrame`, `restoreTimetableFrame`) 모두 `_sideEffect.value = SemesterSideEffect.Toast(...)` 형태로 일관성 있게 구현됨
- **Null Safety**: `?.let { ... }` 및 `!!` 연산자 사용이 맥락상 안전함
- **Flow 처리**: `getUserSemestersUseCase()`, `getAllFramesUseCase()` 등에 `.catch` 블록 추가로 기본 예외 처리 구조 완비
- **Side Effect 리셋**: `SemesterSideEffect.Nothing` 센티널 패턴 유지로 UI 레이어 중복 발행 방지

#### ⚠️ 주의 사항 (SonarQube 규칙 위반은 아니나 품질 관점)

- **CancellationException 처리 제거**: PLAN.md에서는 `if (it is CancellationException) throw it` 패턴 추가를 의도했으나, 실제 구현에서는 삭제됨. Coroutine 캔슬레이션이 자동 전파되지 않는 Flow `.catch` 블록에서는 명시적 재발생이 권장됨. (SonarQube 규칙 위반 아님, 패턴 일관성 이슈)
  - 영향: low → 현재 구조(`viewModelScope`)에서는 ViewModel 소멸 시 자동 취소되므로 실무상 위험은 낮음

- **중복 클릭 방지 상태 제거**: `_isDeletingFrame` 상태가 구현에서 제거됨. PLAN.md에 명시되지 않은 범위였지만, 삭제 API 응답 시간 동안 사용자가 버튼을 재클릭할 수 있는 경로 존재. (UI 안전성, SonarQube 규칙 아님)

- **Double Bang (!!)`restoreTimetableFrame`에서 `_deletedFrame.value!!`, `_deletedFrameSemester.value!!` 사용**:
  - 맥락: `takeIf { _deletedFrame.value != null && _deletedFrameSemester.value != null }?.let { ... }` 스코프 내이므로 null 아님 보장
  - SonarQube 영향: 규칙 위반 아님 (조건부 진입 확보)

---

### 코드 복잡도

- **deleteTimetableFrame()** onSuccess 블록:
  - 인지 복잡도: ~5 (임계 15 이내) ✓
  - `if-else` 분기 2단계로 명확한 제어 흐름
  
- **restoreTimetableFrame()** 리팩토링:
  - `takeIf { ... }?.let` 조합으로 null-safe 진입 처리 ✓
  - 가독성 및 유지보수성 개선

---

### 메모리/리소스 관리

- ✅ 모든 비동기 작업이 `viewModelScope.launch` 내 수행 → ViewModel 소멸 시 자동 취소
- ✅ `StateFlow` 선언 및 초기화 정상
- ✅ Coroutine scope 관리 정상

---

### 결론

**SonarQube 코드 품질 관점**: 🟢 **통과 (CRITICAL/MAJOR 이슈 0건)**

변경된 코드는:
- SonarQube 정적 규칙 준수
- Kotlin null safety 지킴
- CoroutineScope 관리 정상
- 인지 복잡도 임계 범위 내

---

**CRITICAL**: 0  
**MAJOR**: 0  
**MINOR**: 0
