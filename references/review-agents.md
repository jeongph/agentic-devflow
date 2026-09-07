# 리뷰 에이전트

리뷰는 pr-review-toolkit(필수 의존성)의 에이전트와 프로젝트가 지정한 도메인 리뷰어를 **Agent 도구로 직접** 호출한다. `/pr-review-toolkit:review-pr` 커맨드를 거치지 않는다.

이유: pr-review-toolkit 에이전트 6종 중 4종이 `model: inherit`라 세션 모델을 따라간다. 커맨드로 호출하면 그 4종의 모델을 밖에서 강제할 수 없다. Agent 도구의 `model` 파라미터는 에이전트 프론트매터보다 우선하므로, 직접 호출해야 모든 리뷰어를 같은 모델(`review_model`, 기본 opus)로 통일할 수 있다.

이 문서는 세 절차를 정의한다. **선택**(diff → 에이전트 목록), **호출**(Agent 도구 파라미터), **집계**(보고서 형식). 그리고 리뷰어가 아닌 **정리 에이전트**(code-simplifier)를 따로 다룬다. 5-review·6-apply 단계와 `review` 스킬은 이 절차를 참조하고 복제하지 않는다.

## 선택표

리뷰어는 **코드를 고치지 않고 지적만 돌려주는** 에이전트다. 아래 표가 리뷰 팬아웃의 전부다.

| 에이전트 | 실행 조건 | 판정 방법 | 프론트매터 model |
|---|---|---|---|
| `pr-review-toolkit:code-reviewer` | 항상 | — | opus |
| `pr-review-toolkit:pr-test-analyzer` | 테스트 변경, 또는 테스트 없는 신규 로직 | 변경 파일 경로에 `test`·`spec`·`__tests__`가 있음, **또는** 프로덕션 파일에 함수·클래스가 새로 생겼는데 대응하는 테스트 파일 변경이 없음 | inherit |
| `pr-review-toolkit:silent-failure-hunter` | 에러 처리 변경 | diff에 `try`·`catch`·`except`·`rescue`·`.catch(`·`fallback`·`default:`·로깅 호출이 추가·변경됨 | inherit |
| `pr-review-toolkit:type-design-analyzer` | 타입 신설·변경 | diff에 `class`·`record`·`interface`·`enum`·`type`·`struct`·`data class` 선언이 추가·변경됨 | inherit |
| `pr-review-toolkit:comment-analyzer` | 주석·문서 변경 | diff에 주석·docstring·`.md` 파일 변경이 있음 | inherit |
| 설정 `reviewers`의 각 에이전트 | 지정된 경우 항상 | — | 각자 |

판정은 `git diff --name-only origin/<base>...HEAD`(파일 목록)와 `git diff origin/<base>...HEAD`(내용)로 한다. 애매하면 **돌리는 쪽**을 택한다. 리뷰를 빠뜨리는 비용이 한 번 더 돌리는 비용보다 크다.

`pr-review-toolkit:code-simplifier`는 이 표에 없다. 코드를 **수정하는** 에이전트라 리뷰 팬아웃에 섞이면 게이트·검증 없이 코드가 바뀐다. 아래 "정리" 절이 따로 다룬다.

## 관점 인자 매핑

`review` 스킬의 인자는 pr-review-toolkit의 어휘를 그대로 쓴다. 새 이름을 만들지 않는다.

| 인자 | 동작 |
|---|---|
| `code` | code-reviewer |
| `tests` | pr-test-analyzer |
| `errors` | silent-failure-hunter |
| `comments` | comment-analyzer |
| `types` | type-design-analyzer |
| `simplify` | **리뷰 없이** 정리만. 5-review를 건너뛰고 6-apply의 정리 절차(아래 "정리")만 수행한다. 명시 인자는 설정 `simplify: false`보다 우선한다 |
| `all` 또는 인자 없음 | 선택표대로 + 설정 `reviewers` |

- 인자가 있으면 선택표 대신 인자를 따른다. 도메인 리뷰어는 `all`·인자 없음일 때만 포함한다.
- 여러 인자는 공백으로 구분한다 (`tests errors`). `simplify`는 다른 인자와 섞이면 리뷰·반영 뒤에 정리를 한 번 붙인다. 이때도 치명·중요가 남아 있으면 정리는 건너뛴다 (6-apply 5항).
- 표에 없는 인자는 무시하지 말고 알린다: "`foo`는 인식하지 않는 관점입니다. 사용 가능: code tests errors comments types simplify all". 인식하는 인자가 하나도 없으면 중단한다.

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

이슈 맥락이 없으면(`review` 스킬을 `work` 없이 쓴 경우) 이슈·범위 블록을 빼고 diff만 준다.

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
- 보고서 끝에 **돌린 에이전트와 모델**을 한 줄 적는다. `model` 명시가 실제로 적용됐는지 사용자가 확인할 유일한 창구다.

## 정리 (code-simplifier)

`pr-review-toolkit:code-simplifier`는 리뷰어가 아니라 코드를 고치는 에이전트다. 6-apply의 마지막 절차에서만, 아래 조건으로 **1회** 호출한다.

| 파라미터 | 값 |
|---|---|
| `subagent_type` | `pr-review-toolkit:code-simplifier` |
| `model` | 설정 `review_model` |
| `description` | `simplify` |
| `prompt` | "`git diff origin/<base>...HEAD` 범위의 변경만 정리하라. 동작을 바꾸지 마라. 범위 밖 파일을 건드리지 마라." |

- 전제: **워킹 트리가 깨끗해야 한다** (`git status --porcelain` 비어 있음). 아니면 정리를 건너뛰고 알린다. 되돌리기가 정리 결과만 정확히 지우려면 그 전이 깨끗해야 한다.
- 정리와 되돌리기는 **레포 루트**(`git rev-parse --show-toplevel`)에서 실행한다. `git restore`·`git clean`은 현재 디렉토리 이하만 대상으로 하므로, 하위 디렉토리에서 실행하면 전제 검사(레포 전체)와 범위가 어긋난다.
- 정리 후 검증 명령을 실행한다. 통과하면 `refactor: 리뷰 후 코드 정리`로 커밋한다.
- 실패하면 정리 결과만 되돌린다. 정리 전이 깨끗했으므로 아래 두 명령이 지우는 것은 정리 에이전트의 산출물뿐이다.
  ```bash
  git restore --source=HEAD --staged --worktree -- .
  git clean -fd
  ```
  되돌린 뒤 "정리가 검증을 깨뜨려 되돌렸다"고 알린다. 정리가 동작을 바꿨다면 정리를 버리는 게 맞다.

## 도메인 리뷰어 계약

설정 `reviewers`에 넣을 수 있는 에이전트의 조건:

1. Agent 도구의 `subagent_type`으로 호출 가능한 이름이다 (`플러그인:에이전트`). 해당 플러그인이 설치·활성화돼 있어야 한다.
2. 프롬프트로 diff 범위·파일 목록·이슈 맥락을 받아 스스로 코드를 읽는다 (Read·Grep·Glob 권한).
3. 심각도별로 나뉜 지적을 `파일:라인`과 함께 한글로 돌려준다.

이 계약을 만족하면 어떤 플러그인의 에이전트든 리뷰 팬아웃에 끼울 수 있다. 워크플로우 본문은 바뀌지 않는다.

**해소되지 않는 리뷰어**(에이전트 목록에 없는 이름, 플러그인 미설치)는 호출을 시도하지 않고 경고 한 줄을 남긴 뒤 나머지로 진행한다. 집계 보고서 끝의 "돌린 에이전트" 줄에 "제외: `spring-backend:kent-beck` (에이전트 없음)"으로 남겨 사용자가 알 수 있게 한다. Project Status 갱신 실패와 같은 정책이다.
