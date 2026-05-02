저는 10년 차 안드로이드 시니어 개발자로서, 주니어 개발자가 진행한 [#50] 비밀번호 정규식 불일치 수정 건을 **Compose UI 관점**에서 검토했습니다.

본 수정 사항은 주로 `domain` 레이어의 로직 수정(`PasswordUtil`, `UseCase`)에 집중되어 있으나, 이 로직이 UI 레이어(특히 비밀번호 입력 화면의 실시간 피드백)에서 어떻게 소비되는지, 그리고 Compose의 상태 관리 및 성능에 미치는 영향을 중심으로 분석했습니다.

## Compose 리뷰 요약
이번 수정은 도메인 로직의 일관성을 확보하여 UI 피드백과 실제 검증 로직 간의 "상태 불일치" 버그를 근본적으로 해결했습니다. `PasswordUtil`을 `object`로 전환하고 유효성 검사 결과인 `PasswordFormat`을 반환하는 방식은 Compose의 단방향 데이터 흐름(UDF)에서 UI 상태를 안정적으로 업데이트하기에 적합한 구조입니다. 다만, Compose 환경에서 이 UseCase를 호출할 때 발생할 수 있는 잠재적인 성능 이슈와 관찰 가능한 상태 구조에 대해 몇 가지 제언을 드립니다.

---

## 문제점

### [MAJOR] 1. 비밀번호 입력 시 과도한 Recomposition 및 불필요한 객체 생성 방지
파일 경로: `feature/user` 내 비밀번호 입력 관련 Composable (예: `PasswordTextField`, `SignupScreen` 등)
#### 리뷰 사항
`VerifyPasswordFormatUseCase`는 비밀번호가 한 글자 바뀔 때마다 호출됩니다. 현재 `PasswordFormat`은 일반 데이터 클래스이며, 이를 UI에서 관찰할 때 매번 새로운 인스턴스가 생성됩니다. Compose는 `PasswordFormat`의 내부 필드(`isIncludeEnglish`, `isIncludeNumber` 등)가 이전과 동일하더라도 객체 참조가 달라지면 이를 사용하는 UI 컴포넌트들을 Recomposition 시킬 수 있습니다.

#### 수정 방향
- **Stable 어노테이션 고려**: `PasswordFormat` 클래스에 ` @Stable` 또는 ` @Immutable` 어노테이션을 추가하여, 값이 변하지 않았을 때 Compose가 Recomposition을 건너뛸 수 있도록 돕습니다.
- **derivedStateOf 활용**: UI 레이어에서 이 UseCase의 결과를 구독할 때, 특정 조건(예: "모든 조건 충족 여부")만 필요하다면 `derivedStateOf`를 사용하여 불필요한 UI 업데이트를 최소화해야 합니다.

### [MINOR] 2. PasswordUtil의 object 전환에 따른 UI 레이어 영향
파일 경로: `domain/src/main/java/in/koreatech/koin/domain/util/regex/PasswordUtil.kt`
#### 리뷰 사항
`PasswordUtil`을 `class`에서 `object`로 변경한 것은 메모리 효율성 측면에서 긍정적입니다. Compose UI 로직(예: `VisualTransformation`이나 커스텀 `TextFieldValue` 필터링)에서 이 유틸을 직접 참조할 때 별도의 인스턴스 생성 없이 접근 가능해졌습니다. 하지만, 하드코딩된 정규식 연산은 매 호출마다 CPU를 점유하므로, UI 스레드(Main Thread)에서 대량의 텍스트 처리 시 성능 저하가 없는지 확인이 필요합니다.

#### 수정 방향
- (권장) UI 레이어에서는 ViewModel을 통해 `PasswordFormat` 상태를 전달받는 기존 패턴을 유지하되, 만약 Composable 내에서 `PasswordUtil`을 직접 써야 한다면 `remember(password) { PasswordUtil.isContainSymbol(password) }`와 같이 `remember` 키를 활용해 연산 결과를 캐싱하세요.

### [MINOR] 3. UI 피드백 애니메이션 및 State Loss 방지
파일 경로: `feature/user` 관련 화면
#### 리뷰 사항
특수문자 포함 여부(`isIncludeSymbol`)가 `false`에서 `true`로 바뀔 때, UI에서 체크 표시나 텍스트 색상이 변경됩니다. 정규식이 "화이트리스트" 방식으로 좁혀짐에 따라, 사용자가 허용되지 않는 특수문자(예: 공백)를 입력했을 때 즉각적으로 UI 상태가 `false`로 유지되는 것이 중요합니다. 

#### 수정 방향
- `VerifyPasswordFormatUseCase`가 반환하는 `PasswordFormat`이 ViewModel의 StateFlow에 담길 때, `distinctUntilChanged()`를 적용하여 실제로 값이 변했을 때만 UI에 알림을 보내도록 구성하세요. 이는 Compose의 `collectAsStateWithLifecycle`과 결합될 때 최적의 성능을 냅니다.

---

## 검토 결과
**CRITICAL: 0**
**MAJOR: 1**
**MINOR: 2**

**총평**: 도메인 로직의 수정이 깔끔하게 이루어져 UI 버그가 해결되었습니다. 위에서 언급한 MAJOR 이슈는 Compose의 Recomposition 최적화에 관한 내용으로, 실제 UI 구현부에서 `derivedStateOf`나 `Stable` 처리를 통해 보완한다면 더욱 견고한 UI가 될 것입니다. 추가적인 Compose 코드 수정이 이번 PR에 포함되지 않았으므로, 기존 UI 레이어의 UseCase 소비 로직이 위 가이드를 따르고 있는지 한 번 더 점검해 보시기 바랍니다.
