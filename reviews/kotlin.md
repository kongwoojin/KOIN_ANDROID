관련 파일 확인이 완료되었습니다. 검토를 작성합니다.

---

# Kotlin 리뷰

## Summary

PLAN.md 범위 내 변경 코드(`fetchBanners()` `.catch {}` 추가 및 import 2건)를 Kotlin·아키텍처 관점에서 검토한 결과, 실제 버그·아키텍처 위반·런타임 예외 가능성에 해당하는 CRITICAL 또는 MAJOR 이슈는 발견되지 않았습니다.

## 적합성 검증

### `.catch {}` 배치 위치

```kotlin
getBannersByCategoryUseCase(MAIN_BANNER_CATEGORY)
    .catch { ... }       // upstream 예외 포착 ← 올바른 위치
    .collectLatest { ... }
```

`.catch`는 upstream(소스 Flow)에서 발생한 예외만 포착합니다. `collectLatest` 앞에 배치되어 있으므로 소스 Flow의 예외를 올바르게 처리합니다.

### `CancellationException` 재던짐

```kotlin
.catch {
    if (it is CancellationException) throw it
    ...
}
```

`kotlinx.coroutines.flow.catch`는 `CancellationException`을 포함한 모든 `Throwable`을 포착합니다. 재던짐을 생략하면 `viewModelScope` 취소 신호가 소비되어 코루틴이 정상 종료되지 않을 수 있습니다. 명시적 재던짐은 구조적 동시성을 보장하는 올바른 패턴이며, 프로젝트 전반(`runCatching` 사용처)에서 동일하게 요구하는 규칙과 일치합니다.

### Import 추가

| import | 평가 |
|--------|------|
| `kotlinx.coroutines.CancellationException` | ✅ `kotlin.coroutines.cancellation.CancellationException`의 typealias, Android 표준 사용 |
| `kotlinx.coroutines.flow.catch` | ✅ Flow 확장 함수 올바른 임포트 |

### 상태 업데이트 패턴

`.catch {}` 내 `_bannerState.value = _bannerState.value.copy(isLoading = false)`는 파일 전체(line 64–67, 73–75)에서 이미 사용 중인 기존 패턴입니다. 이번 변경이 새로 도입한 패턴이 아니므로 PLAN.md 범위에서 별도 이슈로 올리지 않습니다.

## 문제점

없음.

---

```
CRITICAL: 0
MAJOR: 0
MINOR: 0
```