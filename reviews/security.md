세 파일을 모두 읽었습니다. 보안 분석을 수행하겠습니다.

---

# Security 리뷰

## Summary

이번 PR은 `CancellationException` 전파 누락 버그만 수정하며, 새로 추가된 코드 경로에서 보안적으로 exploit 가능하거나 민감 정보가 유출되는 문제는 발견되지 않았습니다.

## 문제점

검토 결과, PLAN.md에 명시된 수정 범위(`NetworkUtil.kt`, `TimetableRepositoryImpl.kt`, `BusRepositoryImpl.kt`) 내에서 다음 보안 체크 항목에 해당하는 이슈가 없습니다.

| 항목 | 결과 |
|------|------|
| 하드코딩된 API 키·시크릿 | 없음 |
| PII·토큰 로깅 (`Log.d` / `println`) | 없음 |
| DataStore 평문 민감 데이터 저장 | 해당 없음 — DataStore에 저장되는 것은 시간표 수업 데이터(timetable JSON)이며 인증 정보 아님 |
| 인증 우회 (auth bypass) | 없음 — `CancellationException` re-throw는 `mapHttpFailure`의 `HttpException` 분기보다 먼저 실행되므로, 401/403 처리 경로는 변경되지 않음 |
| 네트워크 cleartext / 인증서 검증 우회 | 해당 없음 |
| SQL / 쿼리 삽입 | 해당 없음 |
| Intent hijacking / WebView 취약점 | 해당 없음 |

**추가 확인:** `TimetableRepositoryImpl.getTimetableLectures(semester: String)`에서 `semester` 파라미터가 DataStore 키로 사용되지만, DataStore의 `Preferences.Key` 타입 안전성에 의해 삽입 취약점이 원천 차단됩니다.

## 결론

CRITICAL: 0  
MAJOR: 0  
MINOR: 0