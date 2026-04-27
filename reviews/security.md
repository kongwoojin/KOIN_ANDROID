# Security 리뷰

## Summary

이번 변경(PLAN.md 범위: `SemesterViewModel.kt`의 `deleteSemesterUseCase` `onFailure` 추가 및 `addSemesterUseCase` 대칭화)에서 새롭게 도입된 보안 취약점은 발견되지 않았습니다.

## 검토 결과

### 변경 범위 내 주요 항목 점검

| 항목 | 결과 |
|---|---|
| 하드코딩 시크릿 / 토큰 | 없음. 추가된 `companion object` 상수는 한국어 UI 메시지 전용 |
| 민감 데이터 로깅 | diff에 새 `Timber.d` 추가 없음 |
| `it.message` Toast 노출 | 기존 `addSemesterUseCase.onFailure` 패턴과 동일. `HttpException.message`는 HTTP 상태 줄(예: `HTTP 404 Not Found`) 수준이며 PII 포함 없음 |
| `CancellationException` 재던짐 | 코루틴 안전 처리로 보안 이점(오탐 Toast로 인한 상태 혼선 방지) 있음 |
| 새로운 네트워크·DB·파일 접근 | 없음 |
| 새로운 Intent / DeepLink 처리 | 없음 |

## 문제점

이번 수정 범위 내에서 exploit 가능하거나 민감 정보가 유출되는 보안 이슈는 없습니다.

---

CRITICAL: 0
MAJOR: 0
MINOR: 0