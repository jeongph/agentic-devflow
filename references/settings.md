# 프로젝트 설정 파일

경로는 `.claude/agentic-devflow.md`다. 레포에 체크인해 팀원과 에이전트가 같은 값을 공유한다. YAML frontmatter만 해석하고, 그 아래 본문은 자유 메모라 읽지 않는다.

**모든 키가 선택이다.** 파일이 없거나 키가 없으면 자동 판정 또는 기본값으로 동작한다.

## 스키마

| 키 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `base` | string | 자동 판정 (`references/base-resolution.md`) | 분기·PR 대상 브랜치 |
| `branch_prefix` | string | `feature/` | 작업 브랜치 접두사. 브랜치명은 `<branch_prefix><이슈번호>-<slug>` |
| `project` | number | 없음 → Project Status 갱신을 건너뛴다 | GitHub Project 번호 |
| `project_owner` | string | 레포 owner (`gh repo view --json owner -q .owner.login`) | Project를 소유한 org 또는 사용자. 개인 Project면 `"@me"` |
| `reviewers` | string[] | `[]` | 도메인 리뷰어 에이전트명. `플러그인:에이전트` 형식. 해당 플러그인이 설치돼 있어야 한다 |
| `review_model` | `opus` \| `sonnet` \| `haiku` | `opus` | 모든 리뷰 에이전트 호출에 명시할 모델. Agent 도구의 `model` 파라미터가 받는 별칭만 허용 |
| `simplify` | boolean | `true` | 리뷰 통과 후 `pr-review-toolkit:code-simplifier`를 1회 돌린다 |
| `merge` | `manual` \| `auto` | `manual` | PR 생성 후 머지 여부. `auto`는 CI 통과를 기다린 뒤 **확인 한 번을 거쳐** 머지한다 (무인 머지가 아니다) |
| `merge_method` | `merge` \| `rebase` \| `squash` | `merge` | `gh pr merge` 방식. `squash`는 여기 명시할 때만 쓴다 |

## 예시

```yaml
---
base: develop                  # 생략 시 자동 판정
branch_prefix: feature/        # 기본 feature/
project: 4                     # Project 번호. 생략 시 Status 갱신 건너뜀
project_owner: my-org          # 생략 시 레포 owner
reviewers:                     # 도메인 리뷰어. 해당 플러그인 설치 시에만 (예시)
  - spring-backend:kent-beck
  - spring-backend:vladimir-khorikov
review_model: opus             # 기본 opus
simplify: true                 # 기본 true
merge: manual                  # manual(기본) | auto
merge_method: merge            # merge(기본) | rebase | squash
---

이 아래는 자유 메모. 플러그인은 읽지 않는다.
```

## 우선순위

```
설정 파일  >  프로젝트 CLAUDE.md 선언  >  자동 판정 / 기본값
```

- 워크스페이스·프로젝트 CLAUDE.md는 세션에 항상 로드된다. 커밋 컨벤션, 히스토리 문서 규칙, 머지 정책처럼 CLAUDE.md가 이미 담는 것은 이 파일에 중복해 적지 않는다.
- 이 파일은 CLAUDE.md가 담기 어려운 **구조화된 값**(브랜치·번호·에이전트명·불리언)만 담는다.

## 읽는 법

1. Read 도구로 `.claude/agentic-devflow.md`를 읽는다. 없으면 모든 키가 기본값이다.
2. 첫 줄이 `---`이면 다음 `---`까지를 YAML로 해석한다. frontmatter가 없으면 파일이 없는 것과 같다.
3. frontmatter가 있는데 **YAML 파싱에 실패하면 중단**한다. 설정 없음으로 간주하지 않는다. 어느 줄이 문제인지 보고한다.
4. 표에 없는 키는 무시하되 한 줄 알린다: "설정 파일의 `reviewer` 키는 인식하지 않습니다. `reviewers`를 뜻했나요?" 단, **안전 임계 키**(`base` `branch_prefix` `merge` `merge_method`)와 철자가 비슷한 모르는 키(예: `base_branch`, `merge_mode`)는 알리는 데 그치지 않고 **진행 전에 확인받는다.** 오타 하나로 엉뚱한 base에 PR을 내는 경로를 막기 위해서다.
5. 타입이 맞지 않는 값은 방향을 본다.
   - 기본값이 **자동화를 줄이는 방향**(`merge`→`manual`, `merge_method`→`merge`)이면 기본값으로 대체하고 알린다.
   - 기본값이 **자동화를 늘리는 방향**(`simplify`→`true`, `merge`가 `auto`로 읽힐 여지)이면 대체하지 않고 묻는다. 예: `simplify: "false"`(문자열)는 끄려는 의도일 가능성이 크다.
6. `branch_prefix`를 정규식·`sed`에 넣을 때는 메타문자(`.` `+` `*` `#` 등)를 이스케이프한다. 기본값 `feature/`는 안전하지만 임의 문자열이 올 수 있다.
