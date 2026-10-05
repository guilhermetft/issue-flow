---
name: issue-ship
version: 1.0.0
author: guilhermetft
description: Depois que o usuário aprovou as mudanças de um /issue-work — commita (Conventional Commits), fecha a issue, move Status pra Done no Project (se houver), e abre/atualiza o PR pra branch padrão do repo via skill create-pr. Trigger — "/issue-ship <número>", "pode commitar e fechar a issue X", "manda a issue X".
---

# issue-ship

Etapas finais do workflow: commit, fechamento da issue e abertura do PR.

**Pré-condição: só roda depois que o usuário já revisou e aprovou as mudanças** (fim do `/issue-work`). Se não houve aprovação explícita na conversa, pergunta antes de prosseguir.

## Convenções

- Não cria branch por issue — commita direto na branch atual; PR é branch atual → branch padrão do repo (detectado pelo `create-pr`, passo 4).
- Owner, Project, project-id e Status final são detectados em runtime — nunca fixos, mudam por repo.

## Passo a passo

1. **Detectar contexto do repo**
   ```bash
   OWNER=$(gh repo view --json owner -q .owner.login)
   gh project list --owner "$OWNER" --format json -q '.projects[] | {number,title,id}'
   ```
   1 só projeto: usa ele. Vários: pergunta qual (ou reusa o mesmo do `/issue-work`, se souber). Nenhum: pula passo 4 (mover Status).
   Guarda `PROJECT_NUMBER` e `PROJECT_ID`.

2. **Conferir estado**
   ```bash
   git status
   git diff --stat
   ```
   Se não houver nada pra commitar, avisa e para.

3. **Commit — Conventional Commits**
   - Mensagem no padrão já usado no repo: `tipo: Descrição curta` (tipo pelo conteúdo real do diff), terminando com `Closes #<n>`.
     Exemplo: `feat: Adiciona filtro de status na listagem. Closes #58`
   - Stage só os arquivos relevantes (não `git add -A` cego — revisa o que entra).
   - Nunca adiciona Claude como co-author.

4. **Fechar a issue**
   ```bash
   gh issue close <n> --comment "Implementado em <hash do commit>."
   ```

5. **Mover Status → "Done" (ou equivalente)** — pula se não houver Project (passo 1)
   ```bash
   ITEM_ID=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -q '.items[] | select(.content.number==<n>) | .id')
   FIELD_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -q '.fields[] | select(.name=="Status") | .id')
   OPTION_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -q '.fields[] | select(.name=="Status") | .options[] | select(.name=="Done") | .id')
   gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" --field-id "$FIELD_ID" --single-select-option-id "$OPTION_ID"
   ```
   Se "Done" não existir no board, usa equivalente ("Completed", "Closed") ou pergunta.

6. **Abrir/atualizar o PR**
   Invoca a skill `create-pr` (via Skill tool) pra abrir ou atualizar o PR da branch atual pra branch padrão do repo. Ela já cuida de: detectar branch base, checar se já existe PR aberto (agrega commits em vez de duplicar), título Conventional Commits, corpo só com resumo, labels existentes, assignee = usuário autenticado, **nunca merge**, **Claude nunca aparece no PR**.

7. **Reportar**: hash do commit, issue fechada, Status atualizado (se houver Project), URL do PR. Fim do workflow — merge é decisão do usuário.
