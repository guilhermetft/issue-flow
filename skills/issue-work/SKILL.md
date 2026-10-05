---
name: issue-work
description: Move a Issue pra "In progress" no Project, analisa o escopo, divide em tarefas, implementa (com subagents quando houver trabalho independente) e escreve/roda testes. Termina parando pra revisão do usuário — nunca commita. Trigger — "/issue-work <número>", "implementa a issue X", "trabalha na issue X", "bora fazer a issue X".
---

# issue-work

Segunda e terceira etapa do workflow: implementação de uma issue já criada.

## Convenções

- Trabalha direto na branch atual (a que você já está) — **não cria branch novo por issue**, salvo pedido explícito do usuário.
- Owner, Project e Status são detectados em runtime (passo 1) — nunca fixos, mudam por repo.

## Passo a passo

1. **Detectar contexto do repo e buscar a issue**
   ```bash
   OWNER=$(gh repo view --json owner -q .owner.login)
   gh issue view <n> --json number,title,body,labels,url,state
   ```
   Se já estiver fechada, avisa o usuário e pergunta se quer reabrir/prosseguir mesmo assim.

   Project v2 associado ao owner:
   ```bash
   gh project list --owner "$OWNER" --format json -q '.projects[] | {number,title,id}'
   ```
   - 1 só projeto: usa ele. Vários: pergunta qual. Nenhum: pula gestão de Status (passo 2), segue só com implementação.
   Guarda `PROJECT_NUMBER` e `PROJECT_ID`.

2. **Mover Status → "In progress" (ou equivalente)**
   ```bash
   ITEM_ID=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -q '.items[] | select(.content.number==<n>) | .id')
   FIELD_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -q '.fields[] | select(.name=="Status") | .id')
   OPTION_ID=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json -q '.fields[] | select(.name=="Status") | .options[] | select(.name=="In progress") | .id')
   gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" --field-id "$FIELD_ID" --single-select-option-id "$OPTION_ID"
   ```
   Se a opção "In progress" não existir no board, usa a equivalente mais próxima (ex: "Doing", "In Progress") ou pergunta ao usuário.
   Se o item ainda não estiver no Project (issue criada fora do `/issue-new`), adiciona primeiro com `gh project item-add`.

3. **Analisar e dividir em tarefas**
   Lê a descrição, tarefas e critérios de aceite da issue. Quebra o trabalho em passos rastreáveis dentro da sessão (usa a ferramenta de tarefas do agente, se houver; senão, uma lista simples).

4. **Implementar**
   - Tarefas com dependência entre si: implementa sequencialmente você mesmo.
   - Tarefas genuinamente independentes (ex: sem overlap de arquivos, sem uma depender do resultado da outra): pode disparar subagents (`Agent` tool, `general-purpose` ou `fork`) em paralelo. Evite paralelizar edições que tocam os mesmos arquivos — risco de conflito na working tree.
   - Segue os critérios de aceite da issue como definição de pronto.

5. **Testes**
   - Roda a suíte existente relevante antes e depois da mudança.
   - Escreve testes novos quando a issue introduz comportamento não coberto.
   - Se não for possível testar de ponta a ponta (ex: UI sem browser disponível), diz isso explicitamente em vez de assumir sucesso.

6. **Parar para revisão — não commita.**
   Resume o que foi feito, mostra o diff relevante (`git status` / `git diff --stat`) e pede pro usuário revisar. Esse é o fim do `/issue-work`. Quando aprovado, o usuário roda `/issue-ship <n>`.
