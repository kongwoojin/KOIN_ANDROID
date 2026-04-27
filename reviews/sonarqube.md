SonarQube MCP 도구에 대한 권한이 거부되었습니다. 규칙 5에 따라 결과를 작성합니다.

---

# SonarQube 리뷰

## Summary

SonarQube MCP 도구 권한이 거부되어 프로젝트 조회 및 스니펫 분석 모두 실행 불가 — **SonarQube 미설정 (MCP 도구 접근 불가)**으로 처리합니다. 이슈 0건.

## Quality Gate

- 상태: **NOT_CONFIGURED** (MCP 접근 권한 없음)
- 실패 조건: 조회 불가

## 문제점

해당 없음 — SonarQube 스캔 결과 없음.

---

```
CRITICAL: 0
MAJOR:    0
MINOR:    0
```

> **참고**: SonarQube 분석을 실행하려면 `mcp__sonarqube__search_my_sonarqube_projects` 및 `mcp__sonarqube__analyze_code_snippet` 도구 권한을 허용해 주세요. 권한 부여 후 재실행하면 Quality Gate, 보안 핫스팟, 중복 코드, 인지 복잡도 지표를 실제 스캔 결과 기준으로 보고합니다.