# Security 리뷰

## Summary

PLAN.md 범위인 `BannerViewModel.kt`의 변경 사항을 보안 관점에서 검토했습니다. 신규 도입된 코드는 `.catch {}` 블록 추가와 `import` 두 줄이며, 이 범위 내에서 실제 exploit 가능하거나 민감 정보가 유출되는 보안 취약점은 발견되지 않았습니다.

## 문제점

해당 없음.

---

**검토 근거**

| 항목 | 결과 |
|------|------|
| 하드코딩 시크릿 | `MAIN_BANNER_CATEGORY = 1` — 공개 카테고리 식별자, 시크릿 아님 |
| `Timber.e(it)` 민감 데이터 로깅 | 배너 조회 엔드포인트는 공개 API이며 응답에 PII·토큰 미포함. Timber는 release 빌드에서 Tree 미식재 시 출력 없음. 기존 line 77 패턴과 동일 |
| `CancellationException` 처리 | 적절히 재던짐 — 코루틴 취소 신호 누수 없음 |
| 인증 토큰 처리 | `.catch` 블록은 상태 초기화만 수행, 토큰 노출 경로 없음 |
| 기타 (Intent hijacking, WebView, SQL 등) | 변경 범위 외 |

CRITICAL: 0  
MAJOR: 0  
MINOR: 0