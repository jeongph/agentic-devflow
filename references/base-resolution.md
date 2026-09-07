# base 브랜치 판정

이슈→PR 경로가 브랜치 모델에서 필요로 하는 값은 둘뿐이다. 어디서 따고 어디로 PR을 낼지(`base`), 작업 브랜치 이름을 무엇으로 시작할지(`branch_prefix`). 이름 있는 브랜치 모델은 이 두 값의 프리셋에 불과하다. 그래서 이 문서는 모델을 판정하지 않고 **두 값을 판정**한다.

## 프리셋

| 프리셋 | `base` | `branch_prefix` | 비고 |
|---|---|---|---|
| `git-flow` | `develop` | `feature/` | release·hotfix 경로는 이 플러그인 범위 밖 |
| `github-flow` | 기본 브랜치 (`main`·`master` 등) | `feature/` | 트렁크 기반 + 짧은 브랜치 + PR 구성도 동작이 같다 |

## 판정 순서

위에서부터 처음 맞는 행에서 멈춘다.

| 순서 | 근거 | 확인 방법 | 결과 |
|---|---|---|---|
| 1 | 설정 파일에 `base` 명시 | `.claude/agentic-devflow.md` frontmatter (읽는 법은 `references/settings.md`) | 그대로. `branch_prefix`도 있으면 그대로, 없으면 `feature/` |
| 2 | 프로젝트 CLAUDE.md의 워크플로우 선언 | CLAUDE.md(및 `@import`된 컨벤션 문서)에 "Git Flow" / "GitHub Flow" / base 브랜치명이 선언돼 있음 | 해당 프리셋 |
| 3 | 원격에 `develop` 존재 | `git ls-remote --heads origin develop` 출력이 비어 있지 않음 | `git-flow` 프리셋 |
| 4 | `develop` 없음 **그리고** 장수 브랜치 후보 없음 | `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`으로 기본 브랜치를 읽고, `git ls-remote --heads origin` 목록에 `dev` `development` `staging` `next` `release*`, 기본 브랜치가 아닌 `master`가 없음 | `github-flow` 프리셋 (base=기본 브랜치) |
| 5 | 그 외 | 장수 브랜치 후보가 하나라도 있거나, 원격을 읽지 못함 | **묻는다.** 후보 브랜치 목록을 보여주고 고르게 한다 |

5행에서 추정하지 않는 이유: `develop`이 없다고 곧바로 기본 브랜치로 떨어지면 `staging`을 base로 쓰는 레포에서 잘못된 base로 PR을 낸다. 그 PR을 되돌리는 비용이 질문 한 번보다 크다.

질문 형식:

```
base 브랜치를 판정하지 못했습니다. 원격 브랜치:
  main (기본)
  staging
  dev
어느 브랜치에서 분기하고 PR을 낼까요?
```

## 첫 실행 확인과 기록

3·4·5행으로 판정했으면 결과를 보여주고 확인받는다.

```
이 레포는 base=develop, branch_prefix=feature/ 로 봤습니다 (원격에 develop 존재). 맞나요?
```

확정되면 `.claude/agentic-devflow.md`에 기록을 **제안**한다. 파일 생성도 레포에 남는 변경이므로 승인 후에 만든다. 기록하면 다음 실행부터 1행에서 끝나 다시 묻지 않는다.

```yaml
---
base: develop
branch_prefix: feature/
---
```

설정 파일이 이미 있고 `base`만 없으면 그 키를 추가하는 방식으로 제안한다. 다른 키는 건드리지 않는다.

## 프리셋에 없는 레포

base가 `staging`처럼 프리셋에 없는 브랜치면 설정 파일의 `base`로 직접 지정한다. 판정표를 고칠 일이 아니다. 같은 구성이 여러 레포에서 반복되면 그때 이 문서의 프리셋 표에 행을 추가한다.

## 금지

- 로컬 브랜치 목록(`git branch`)으로 기본 브랜치나 base를 추측하지 않는다. 로컬은 오래됐거나 일부만 있을 수 있다. 원격(`git ls-remote`, `gh repo view`)이 진실이다.
- `git ls-remote`·`gh repo view`가 실패하면(원격 없음·인증 없음·네트워크) 중단하고 원인을 보고한다. 로컬 정보로 조용히 진행하지 않는다.
- 판정 결과를 사용자 확인 없이 설정 파일에 쓰지 않는다.
