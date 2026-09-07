# 사전 확인

`work`·`review` 두 스킬이 첫 동작으로 공유하는 절차다. 여기서 확정한 값(`owner/repo`, 설정값, `base`, `branch_prefix`, 검증 명령)을 이후 단계가 입력으로 쓴다. 두 스킬은 이 문서를 참조하고 절차를 복제하지 않는다.

이 문서를 포함해 `references/`·`skills/work/stages/` 안의 문서가 적는 `references/…`·`skills/…` 경로는 모두 **플러그인 루트 기준**이다. 스킬 본문(SKILL.md)이 `${CLAUDE_PLUGIN_ROOT}`로 그 루트의 절대 경로를 알려준다. 사용자 프로젝트(cwd)에서 같은 이름의 파일을 찾지 않는다.

## 1. 환경

```bash
git rev-parse --git-dir                                     # git 레포인가
gh auth status                                              # gh 인증
gh repo view --json nameWithOwner,owner,defaultBranchRef    # GitHub 원격인가
```

- git 레포가 아니면 중단한다.
- `gh auth status`·`gh repo view`가 실패하면 중단한다:

```
이 플러그인은 GitHub 이슈·PR을 전제합니다. 원격이 GitHub가 아니거나 gh 인증이 없습니다.
gh auth login 후 다시 실행하세요.
```

- `nameWithOwner`(이슈 조회용)와 `owner.login`(Project owner 기본값)을 기억한다.

## 2. 설정 파일

`references/settings.md`의 "읽는 법"대로 `.claude/agentic-devflow.md`를 읽는다. 파일이 없으면 모든 키가 기본값이다. frontmatter가 있는데 YAML 파싱에 실패하면 **중단**한다. 체크인된 설정이 조용히 무시되면 팀 전체가 잘못된 base·머지 정책으로 동작한다.

## 3. base 브랜치와 prefix

`references/base-resolution.md`의 판정 순서를 따른다. 3·4·5행으로 판정했으면 결과를 확인받고 설정 파일 기록을 제안한다. 1·2행이면 확인 없이 진행한다.

## 4. 작업 트리

```bash
git status --porcelain
```

미커밋 변경이 있으면 **알리고 확인받는다.** 임의로 stash·커밋하지 않는다. `review` 스킬에서는 "리뷰 대상은 커밋된 변경(`origin/<base>...HEAD`)뿐이라 미커밋 변경은 빠진다"는 점을 함께 알린다.

## 5. 검증 명령

프로젝트의 테스트·빌드 명령을 확정한다. **"적절한 테스트"처럼 모호하게 두지 않는다.**

1. 브랜치가 `work`에서 왔으면(이슈에 `<!-- agentic-devflow:plan -->` 코멘트가 있으면) 그 계획의 검증 명령을 쓴다.
2. 없으면 `build.gradle`·`package.json`·`Makefile`·CI 워크플로우·CLAUDE.md에서 찾는다.
3. 찾지 못하면 사용자에게 묻는다. 검증 수단이 정말 없는 프로젝트면 "자동 검증 수단 없음"으로 확정하고, 이후 단계는 검증을 실행한 것처럼 적지 않는다.

`work`는 plan 단계에서 계획과 함께 확정하므로 여기서는 건너뛴다. `review`는 여기서 확정한다. **검증 명령이 확정되지 않은 채 반영 단계로 들어가지 않는다.**

## 출력

- `owner/repo`, `owner`
- 설정값 (기본값 채운 상태)
- `base`, `branch_prefix`
- 검증 명령 (`review`인 경우)
