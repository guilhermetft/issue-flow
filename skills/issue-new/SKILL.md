---
name: issue-new
description: Cria uma GitHub Issue bem formatada (título, descrição, tarefas, critérios de aceite) a partir de uma feature/ideia, adiciona ao Project do repo (detectado em runtime) e define Status inicial. Trigger — "/issue-new", "cria uma issue", "abre issue pra isso", "registra essa feature".
---

# issue-new

Primeira etapa do workflow: transforma uma feature/ideia em uma Issue rastreável.

## Passo a passo

1. **Detectar contexto do repo (sempre em runtime, nunca fixo)**
   ```bash
   OWNER=$(gh repo view --json owner -q .owner.login)
   REPO=$(gh repo view --json name -q .name)
   ```
   Project v2 associado ao owner:
   ```bash
   gh project list --owner "$OWNER" --format json -q '.projects[] | {number,title,id}'
   ```
   - 1 só projeto: usa ele.
   - Vários: mostra títulos, pergunta qual usar.
   - Nenhum: pergunta se quer criar um Project ou seguir só criando a issue, sem gerenciar Status.
   Guarda `PROJECT_NUMBER` e `PROJECT_ID` (campo `id`) pro resto do fluxo.

   Status inicial (equivalente a "Backlog"/"Todo"):
   ```bash
   gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -q '.fields[] | select(.name=="Status") | .options[].name'
   ```
   Usa a opção que corresponder a "Backlog"/"Todo"/primeira da lista. Se ambíguo, pergunta ao usuário.

   Issue Types do repo (só existem em repos de organização com o recurso habilitado):
   ```bash
   gh api graphql -f query='query($o:String!,$r:String!){repository(owner:$o,name:$r){issueTypes(first:20){nodes{name}}}}' -f o="$OWNER" -f r="$REPO" -q '.data.repository.issueTypes.nodes[].name'
   ```
   Se retornar tipos, mapeamento padrão: `feat`→**Feature**, `fix`→**Bug**, outro→**Task** (usa o nome equivalente que existir). Se vier vazio ou der erro, omite `--type` na criação.

2. **Entender a demanda**
   Usa a descrição que o usuário deu na conversa. Se estiver vaga, pergunta o mínimo necessário (não assume escopo).

3. **Rascunhar a issue**
   - **Título**: prefixo de Conventional Commit + descrição curta (ex: `feat: Filtro de status na listagem de pedidos`). Tipo (`feat`, `fix`, `refactor`, etc.) escolhido pelo conteúdo real da demanda.
   - **Issue Type** (só se o repo tiver Issue Types habilitado — ver passo 1): mapeado a partir do prefixo do título —
     - `feat` → **Feature**
     - `fix` → **Bug**
     - qualquer outro (`refactor`, `chore`, `docs`, etc.) → **Task**
   - **Corpo**, neste formato:
     ```markdown
     ## Contexto
     <1-3 frases explicando a motivação/problema>

     ## Tarefas
     - [ ] ...
     - [ ] ...

     ## Critérios de aceite
     - [ ] ...
     - [ ] ...
     ```
   - **Labels**: só as que já existem no repo (`gh label list`). Nunca cria label nova. Não força label se nenhuma existente fizer sentido.

4. **Mostrar o rascunho pro usuário e confirmar antes de criar.** Criar issue é uma ação visível a outros colaboradores — não cria sem aprovação explícita, mesmo que a demanda pareça clara.

5. **Criar a issue**
   ```bash
   gh issue create --title "<título>" --body "<corpo>" --label "<label1>,<label2>" --assignee "@me" --type "<Task|Bug|Feature>"
   ```
   `--assignee "@me"` é sempre obrigatório — o usuário sempre deve ficar como assignee. `--type` só entra se o repo suportar Issue Types (passo 1); se não suportar, omite a flag.
   Captura a URL/number retornado.

6. **Adicionar ao Project e setar Status** (pula esse passo se não houver Project, conforme decidido no passo 1)
   ```bash
   ITEM_ID=$(gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url <issue-url> --format json -q .id)
   FIELD_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -q '.fields[] | select(.name=="Status") | .id')
   OPTION_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -q '.fields[] | select(.name=="Status") | .options[] | select(.name=="<status inicial>") | .id')
   gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" --field-id "$FIELD_ID" --single-select-option-id "$OPTION_ID"
   ```
   (Busca os IDs dinamicamente em vez de fixar — o board pode mudar.)

7. **Reportar pro usuário**: número da issue, URL, status setado (se houver Project), assignee e type confirmados. Não inicia implementação — isso é o `/issue-work`.
