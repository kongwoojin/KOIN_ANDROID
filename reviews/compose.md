# Compose 리뷰

## Summary

PLAN.md 범위(`BannerViewModel.kt`)의 변경 사항에서 Compose UI 관점의 문제는 발견되지 않았습니다. `.catch { }` 핸들러 추가는 `BannerState.isLoading = false` 전이를 보장하여 무한 로딩 상태를 올바르게 해소합니다.

## 문제점

해당 없음.

변경된 코드(`BannerViewModel.kt:56-69`)를 기준으로 검토한 결과:

- **State 전이 정확성**: `.catch` 블록에서 `_bannerState.value = _bannerState.value.copy(isLoading = false)` 호출이 올바르게 배치되어, 예외 발생 시 `BannerActivity`의 `if (!uiState.isLoading)` 분기가 정상 진입됩니다.
- **컴포지션 중 부수효과**: 변경된 코드 자체는 Compose 컴포지션 밖(ViewModel `launch` 블록)에서만 실행되므로 composition-time side effect 문제 없음.
- **StateFlow 수집 방식**: 수집부(`BannerActivity.kt:39` — `collectAsState()`)는 변경 범위 밖이며, IMPL.md에서 이미 `finishActivity()` composition-time 호출 문제와 함께 별도 이슈로 추적 권장으로 명시되어 있어 이번 리뷰 대상 외.

---

CRITICAL: 0
MAJOR: 0
MINOR: 0