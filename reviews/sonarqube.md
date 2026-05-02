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
