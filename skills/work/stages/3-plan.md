# 3. plan — 구현 계획과 브랜치

## 입력

- `확정된 범위` (2-scope 출력)
- `base`, `branch_prefix` (사전 확인)
- 설정 `project` (있으면)

## 절차

1. 범위를 **순서 있는 단계**로 쪼갠다. 단계마다 네 가지를 적는다.
   ```
   1. <할 일 한 문장>
      파일    src/…/CancelService.java (수정), src/…/StockRestorer.java (신규)
      검증    ./gradlew :order:test --tests "*CancelServiceTest*"
      커밋    feat(order): 주문 취소 시 재고 복원 호출
   2. …
   ```
   - 검증 명령은 프로젝트의 **실제 명령**을 찾아 적는다 (`build.gradle`·`package.json`·`Makefile`·CI 워크플로우·CLAUDE.md). 못 찾으면 사용자에게 묻는다. "적절한 테스트"라고 쓰지 않는다.
   - 테스트가 필요한 단계는 테스트 작성을 먼저 두고 구현을 뒤에 둔다.
   - 한 단계는 커밋 하나. 3~7단계가 보통이다. 10을 넘으면 범위가 크다.

2. 계획 코멘트 draft를 만든다.
   ```
   <!-- agentic-devflow:plan -->
   ## 구현 계획
   (위 형식 그대로)
   ```

3. 승인 후 순서대로 실행한다.
   1. 코멘트 게시: `gh issue comment <n> --body-file <임시파일>`
   2. assignee가 없으면: `gh issue edit <n> --add-assignee @me`
   3. 브랜치 생성:
      ```bash
      git fetch origin <base>
      git checkout -b <branch_prefix><n>-<slug> origin/<base>
      ```
      slug는 이슈 제목을 영문 kebab-case로 옮긴 것. 소문자, 5단어 내외, 관사·조사 생략. 예: "주문 취소 시 재고 복원" → `restore-stock-on-cancel`.
      같은 이름이 이미 있으면(`git branch -a --format='%(refname:short)' | grep -x …`) 알리고 다시 묻는다. 덮어쓰지 않는다.
      `git fetch`가 실패하면 중단하고 원인을 보고한다.
   4. 설정 `project`가 있으면 Status를 **In progress**로 바꾼다. 실패하면 경고 한 줄만 남기고 계속한다.
      ```bash
      gh project item-list <project> --owner <org> --format json          # 이슈의 item id
      gh project field-list <project> --owner <org> --format json         # Status field id, In progress option id
      gh project item-edit --project-id <PVT_…> --id <PVTI_…> --field-id <PVTSSF_…> --single-select-option-id <id>
      ```
      이슈가 Project에 없으면 먼저 넣는다: `gh project item-add <project> --owner <org> --url <이슈 URL>`.

## 게이트

1. **계획 승인** — 계획을 보여주고 묻는다: "이 계획으로 구현할까요?" 순서·검증 명령·커밋 단위에 대한 이견을 반영한다.
2. **코멘트 게시** — draft 승인 후 게시.

브랜치 생성과 Status 변경은 계획 승인에 포함된 것으로 본다 (별도 질문 없음).

## 출력

- `계획` (승인된 최종본)
- 브랜치명, 분기점 SHA (`git rev-parse --short origin/<base>`)
- 계획 코멘트 URL
