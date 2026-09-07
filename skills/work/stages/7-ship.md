# 7. ship — PR

## 입력

- `base`, 현재 브랜치, 이슈 번호 `n`, `이슈 요약`
- 6-apply 출력 (반영 내역·검증 결과)
- 설정 `merge`, `merge_method`
- 범위 밖 발견 메모 (4-implement)

## 절차

순서를 지킨다. 히스토리가 PR보다 먼저다.

1. **전체 검증** — 프로젝트의 전체 테스트·빌드 명령을 한 번 더 실행한다 (단계별 검증과 별개). 실패하면 PR을 만들지 않고 6-apply로 돌아간다.

2. **히스토리 문서** — 레포에 `docs/history/`가 있으면 프로젝트 CLAUDE.md의 히스토리 규칙(파일명 형식·frontmatter·본문 구성)대로 작성해 커밋한다. 규칙을 CLAUDE.md나 컨벤션 문서에서 찾지 못하면 건너뛰고 알린다. 형식을 추측해 쓰지 않는다.

3. **push**
   ```bash
   git push -u origin <branch>
   ```

4. **PR draft**
   ```
   제목: <이슈 제목 기반. 프로젝트 커밋 컨벤션의 제목 규칙(타입·한글·50자)을 따른다>

   ## 요약
   <무엇을 왜, 2~3문장>

   ## 변경 내역
   - <커밋 단위로>

   ## 검증
   - <실행한 명령과 결과>
   - <리뷰: 돌린 에이전트, 반영/미반영 요약>

   ## 이슈
   Closes #<n>
   ```
   - 이슈 본문에 **머지 밖의 완료 조건**(스토어 심사·운영 반영 확인 등)이 명시돼 있으면 `Closes` 대신 `Refs #<n>`을 쓴다. 머지로 이슈가 닫히면 조기 종료다.
   - 승인 후 생성:
     ```bash
     gh pr create --base <base> --title "<제목>" --body-file <임시파일> --assignee @me
     ```
   - 범위 밖 발견 메모가 있으면 PR 생성 후 별도 이슈 등록을 제안한다 (draft 승인 후 `gh issue create --assignee @me`).

5. **머지 정책**

   | 설정 `merge` | 동작 |
   |---|---|
   | `manual` (기본) | PR URL을 보고하고 멈춘다 |
   | `auto` | `gh pr checks <num> --watch`로 CI 통과를 기다린 뒤 `gh pr merge <num> --<merge_method> --delete-branch` |
   | 설정 없음 + CLAUDE.md에 머지 정책 있음 | 그 정책을 따른다 |

   - `--squash`는 `merge_method: squash`일 때만. 기본은 `--merge` (머지 커밋 보존).
   - CI가 실패하면 머지하지 않고 실패한 체크를 보고한다.

6. **정리** (머지된 경우)
   ```bash
   git checkout <base> && git pull origin <base>
   git branch -d <branch>
   ```
   Project Status의 Done 전이는 `Closes`에 의한 GitHub 자동화에 맡긴다. 직접 바꾸지 않는다.

## 게이트

- PR draft 승인 (4).
- `merge: auto`여도 머지 직전 한 줄 확인: "CI 통과. develop에 머지합니다." 머지는 되돌리기 어렵다.
- 별도 이슈 등록 draft 승인 (4, 해당 시).

## 출력

- PR URL, base, 이슈 연결 방식 (`Closes`/`Refs`)
- 머지 여부, 머지 커밋 (머지 시)
- 정리 결과 (로컬 브랜치 삭제 여부)
- 등록한 별도 이슈 (있으면)
