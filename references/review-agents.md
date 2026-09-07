# 리뷰 에이전트

리뷰는 pr-review-toolkit(필수 의존성)의 에이전트와 프로젝트가 지정한 도메인 리뷰어를 **Agent 도구로 직접** 호출한다. `/pr-review-toolkit:review-pr` 커맨드를 거치지 않는다.

이유: pr-review-toolkit 에이전트 6종 중 4종이 `model: inherit`라 세션 모델을 따라간다. 커맨드로 호출하면 그 4종의 모델을 밖에서 강제할 수 없다. Agent 도구의 `model` 파라미터는 에이전트 프론트매터보다 우선하므로, 직접 호출해야 모든 리뷰어를 같은 모델(`review_model`, 기본 opus)로 통일할 수 있다.

이 문서는 세 절차를 정의한다. **선택**(diff → 에이전트 목록), **호출**(Agent 도구 파라미터), **집계**(보고서 형식). 5-review 단계와 `review` 스킬은 이 절차를 참조하고 복제하지 않는다.

## 선택표

| 에이전트 | 실행 조건 | 판정 방법 | 프론트매터 model |
|---|---|---|---|
| `pr-review-toolkit:code-reviewer` | 항상 | — | opus |
| `pr-review-toolkit:pr-test-analyzer` | 테스트 변경, 또는 테스트 없는 신규 로직 | 변경 파일 경로에 `test`·`spec`·`__tests__`가 있음, **또는** 프로덕션 파일에 함수·클래스가 새로 생겼는데 대응하는 테스트 파일 변경이 없음 | inherit |
| `pr-review-toolkit:silent-failure-hunter` | 에러 처리 변경 | diff에 `try`·`catch`·`except`·`rescue`·`.catch(`·`fallback`·`default:`·로깅 호출이 추가·변경됨 | inherit |
| `pr-review-toolkit:type-design-analyzer` | 타입 신설·변경 | diff에 `class`·`record`·`interface`·`enum`·`type`·`struct`·`data class` 선언이 추가·변경됨 | inherit |
| `pr-review-toolkit:comment-analyzer` | 주석·문서 변경 | diff에 주석·docstring·`.md` 파일 변경이 있음 | inherit |
| `pr-review-toolkit:code-simplifier` | 6-apply 통과 후, 설정 `simplify`가 true | 리뷰 루프가 끝난 뒤 **1회** | opus |
| 설정 `reviewers`의 각 에이전트 | 지정된 경우 항상 | — | 각자 |

판정은 `git diff --name-only origin/<base>...HEAD`(파일 목록)와 `git diff origin/<base>...HEAD`(내용)로 한다. 애매하면 **돌리는 쪽**을 택한다. 리뷰를 빠뜨리는 비용이 한 번 더 돌리는 비용보다 크다.

## 관점 인자 매핑

`review` 스킬의 인자는 pr-review-toolkit의 어휘를 그대로 쓴다. 새 이름을 만들지 않는다.

| 인자 | 에이전트 |
|---|---|
| `code` | code-reviewer |
| `tests` | pr-test-analyzer |
| `errors` | silent-failure-hunter |
| `comments` | comment-analyzer |
| `types` | type-design-analyzer |
| `simplify` | code-simplifier (리뷰 없이 정리만) |
| `all` 또는 인자 없음 | 선택표대로 + 설정 `reviewers` |

인자가 있으면 선택표 대신 인자를 따른다. 도메인 리뷰어는 `all`·인자 없음일 때만 포함한다. 여러 인자는 공백으로 구분한다 (`tests errors`).

## 호출 규약

Agent 도구 파라미터:

| 파라미터 | 값 |
|---|---|
| `subagent_type` | 위 표의 에이전트명 그대로 (`pr-review-toolkit:code-reviewer`, `spring-backend:kent-beck` 등) |
| `model` | **항상 명시.** 설정 `review_model` (기본 `opus`). 프론트매터 값과 무관하게 통일한다 |
| `description` | `review:<에이전트 단축명>` (예: `review:code-reviewer`) |
| `prompt` | 아래 골격 |

선택된 에이전트는 서로 독립적이다. **한 메시지에서 병렬로 호출**한다. 순차 호출은 시간만 늘린다.

프롬프트 골격:

```
리뷰 대상: `git diff origin/<base>...HEAD` 범위의 변경 (base=<base>, HEAD=<branch>).
변경 파일:
<파일 목록, 한 줄에 하나>

이슈 #<n>: <제목>
<이슈 요약 한 줄>

확정된 범위:
- 포함: <…>
- 제외: <…>

지시:
- 변경된 파일을 전부 읽고, 필요하면 의존 코드도 추적하라.
- 결과는 심각도별(치명 / 중요 / 제안)로 나누고, 항목마다 `파일:라인`과 근거(위반 원칙 또는 실패 시나리오)를 적어라.
- 잘한 점은 진짜일 때만 짧게.
- 한글로 보고하라.
```

에이전트가 자체 출력 형식을 가지면(예: 페르소나 리뷰어의 "치명적 / 개선 필요 / 사소함") 그 형식을 존중하고 집계 시 심각도로 매핑한다: 치명적→치명, 개선 필요→중요, 사소함→제안.

## 집계

모든 에이전트가 돌아온 뒤 하나의 보고서로 합친다.

```
## 리뷰 결과

### 치명 (N)
- [code-reviewer] <설명> — `파일:라인`
- [kent-beck, code-reviewer] <설명> — `파일:라인`   ← 같은 지적은 하나로 합치고 에이전트명을 나열

### 중요 (N)
- [silent-failure-hunter] <설명> — `파일:라인`

### 제안 (N)
- [comment-analyzer] <설명> — `파일:라인`

### 잘한 점
- <있을 때만>
```

- 항목 형식은 `- [에이전트명] 설명 — \`파일:라인\``로 고정한다. 라인 없는 지적은 에이전트에게 다시 묻지 않고 파일명만 남긴다.
- 같은 파일·같은 라인·같은 취지의 지적은 하나로 합친다. 심각도가 다르면 높은 쪽을 택한다.
- 섹션이 비면 `(0)`으로 남기지 말고 섹션 자체를 생략한다. 단 `치명`·`중요`가 모두 없으면 "치명·중요 없음"을 첫 줄에 명시한다.

## 도메인 리뷰어 계약

설정 `reviewers`에 넣을 수 있는 에이전트의 조건:

1. Agent 도구의 `subagent_type`으로 호출 가능한 이름이다 (`플러그인:에이전트`).
2. 프롬프트로 diff 범위·파일 목록·이슈 맥락을 받아 스스로 코드를 읽는다 (Read·Grep·Glob 권한).
3. 심각도별로 나뉜 지적을 `파일:라인`과 함께 한글로 돌려준다.

이 계약을 만족하면 어떤 플러그인의 에이전트든 리뷰 팬아웃에 끼울 수 있다. 워크플로우 본문은 바뀌지 않는다.
