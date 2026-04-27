SonarQube MCP 권한이 거부되어 있습니다. 알려진 SonarQube Kotlin 규칙으로 스니펫을 수동 분석합니다.

---

# SonarQube 리뷰

## Summary

SonarQube MCP 서버에 대한 권한이 거부되어 프로젝트/Quality Gate 조회를 수행할 수 없었습니다. 변경 코드 스니펫을 SonarQube 공식 Kotlin 규칙 기준으로 직접 분석하여 대체합니다.

## Quality Gate

- 상태: NOT_CONFIGURED (권한 거부로 조회 불가)

---

## 문제점

### [MINOR] 1. `Flow.catch` 내 `CancellationException` 재던짐 분기 — 도달 불가 코드 (kotlin:S2583)

파일 경로: `feature/banner/src/main/java/in/koreatech/koin/feature/banner/ui/BannerViewModel.kt:58-59`

#### 리뷰 사항

```kotlin
.catch {
    if (it is CancellationException) throw it   // ← 이 분기에 도달하지 않음
    Timber.e(it)
    _bannerState.value = _bannerState.value.copy(isLoading = false)
}
```

`kotlinx.coroutines` **1.5.0** 이상에서 `Flow.catch` 연산자는 `CancellationException`을 투명하게 통과시킵니다(catch 하지 않음). 따라서 `it is CancellationException` 조건은 런타임에서 항상 `false`이며 해당 분기에 도달하지 않습니다. SonarQube는 이를 `kotlin:S2583` ("Conditions should not always evaluate to 'true' or 'false'") 또는 `kotlin:S6619` ("CancellationException caught by Flow's catch should be re-thrown") 규칙으로 데드 코드 경고를 발행할 수 있습니다.

#### 수정 방향

`CancellationException` 투명성이 보장된 coroutines 버전을 사용 중이라면 해당 분기를 제거하여 코드 노이즈를 줄이는 것이 좋습니다. 단, 프로젝트의 coroutines 최소 지원 버전이 1.4.x 이하라면 방어적 코드로 유지하는 것이 타당합니다.

```kotlin
// coroutines 1.5.0+ 환경: 분기 제거
.catch {
    Timber.e(it)
    _bannerState.value = _bannerState.value.copy(isLoading = false)
}
```

---

## 변경 범위 내 추가 검토 결과

| 검토 항목 | 결과 |
|---|---|
| Cognitive Complexity (`fetchBanners`) | 이슈 없음 — 추가된 분기 포함 복잡도 ≤ 3 |
| 코드 중복 | 이슈 없음 — `.copy(isLoading = false)` 2회 반복이지만 중복 임계(10줄 이상) 미달 |
| 보안 핫스팟 | 이슈 없음 — 외부 입력 노출·로그 민감정보 없음 |
| Coverage 하락 | 측정 불가 (SonarQube 미접근) |

---

**CRITICAL: 0**
**MAJOR: 0**
**MINOR: 1**