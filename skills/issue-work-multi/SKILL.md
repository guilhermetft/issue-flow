---
name: issue-work-multi
description: Roda o /issue-work em 2+ issues em paralelo na mesma sessão, cada uma num subagent com worktree isolada, e depois compara as issues entre si (arquivos, contratos, schema, build/testes integrados) pra achar conflito lógico antes do commit. Nunca commita. Trigger — "/issue-work-multi <n1> <n2> ...", "trabalha nas issues X e Y em paralelo", "faz as issues X e Y ao mesmo tempo".
---

# issue-work-multi

Variante do `issue-work` pra várias issues ao mesmo tempo, sem uma pisar na outra. Cada issue roda isolada numa worktree; no fim, uma **revisão cruzada** procura interferência entre elas. Termina parando pra revisão do usuário — **nunca commita**. O commit continua sendo do `/issue-ship <n>`, uma issue por vez.

## Convenções

- Owner, Project, project-id, branch base e Status são detectados em runtime (passo 0) — nunca fixos, mudam por repo.
- Trabalha na branch atual do repo (a base das worktrees). Não cria branch por issue.
- Status durante o trabalho: **In progress** (ou o equivalente do board) em cada issue.

## Passo a passo

### 0. Detectar contexto do repo

```bash
OWNER=$(gh repo view --json owner -q .owner.login)
BASE=$(git branch --show-current)
gh project list --owner "$OWNER" --format json -q '.projects[] | {number,title,id}'
```

- 1 só projeto: usa ele. Vários: pergunta qual. Nenhum: pula a gestão de Status (passo 2) e segue só com a implementação.
- Guarda `PROJECT_NUMBER` e `PROJECT_ID`.
- Descobre como o repo builda e testa (scripts do `package.json`, `pytest`, `Makefile`, CI) e se há migrations (pasta `migrations/`, `supabase/`, `prisma/`, `alembic/` etc.). Pergunta ao usuário só o que não der pra inferir (ex: existe staging? o `.env` aponta pra produção?).

### 1. Triagem (antes de disparar qualquer coisa)

Pra cada issue: `gh issue view <n> --json number,title,body,labels,url,state` (se fechada, avisa e pergunta).

Estima, só pela leitura, os arquivos/módulos que cada uma deve tocar e mostra ao usuário uma tabela curta, com a coluna **Schema** (sim/não). Regras:

- Duas issues mexem em **schema/migration** (ou uma depende da outra): **não paraleliza**, propõe sequência e espera a decisão do usuário.
- Sobreposição alta nos mesmos arquivos: avisa, mas deixa o usuário escolher.
- **Tamanho desbalanceado** (uma issue claramente maior que as outras, ex: dezenas de itens vs. 2-3 tarefas): avisa que a menor vai terminar bem antes e sugere dividir a maior em issues menores se ela puder atrasar o resto.

### 2. Mover Status → In progress

Mesmo comando do `issue-work` (passo 2) pra cada issue, com `--limit 200` no `item-list`. Se a opção "In progress" não existir, usa a equivalente mais próxima ou pergunta. Se o item não estiver no Project, `gh project item-add` antes.

### 3. Disparar os subagents em paralelo

Um `Agent` por issue, **todos na mesma mensagem**, com `isolation: "worktree"`. O prompt de cada um deve conter:

- número, título, corpo completo e critérios de aceite da issue;
- o passo a passo do `issue-work` (analisar, implementar, testar), **sem** a parte de mover Status (já feita);
- **não commitar**, deixar tudo como alteração não commitada na worktree;
- a lista de arquivos/áreas que **não** pode tocar (as que pertencem às outras issues, segundo a triagem);
- a worktree é nova: dependências (`node_modules`, venv) e `.env` não vêm junto. Se precisar rodar build/testes, instalar (`npm ci`, etc.) ou copiar o necessário, ou dizer explicitamente que não conseguiu. Não deixar junction/symlink de `node_modules` na worktree (ver passo 7);
- **nunca aplicar migration nem escrever em banco**: isso é só do passo 5.5;
- devolver, nesta ordem:
  1. resumo do que foi feito **e do que ficou de fora**, com o motivo;
  2. arquivos alterados/criados;
  3. **contratos que mudou** (funções/tipos/props/rotas/colunas/enums/variáveis de ambiente renomeados ou removidos), incluindo o número de migration, se houver;
  4. **efeitos em outros fluxos e mudanças de comportamento**: qualquer alteração fora do módulo da issue ou que mude algo que já funcionava (mesmo que pequena ou "melhoria");
  5. testes/build rodados e resultado, e o que **não** foi possível verificar (banco real, browser);
  6. caminho e branch da worktree.

### 3.5. Conferir a base e coletar o diff de cada worktree

Primeiro, confirma que a worktree nasceu do mesmo conteúdo da branch base (o commit base pode ser outro, ex: um merge):

```bash
git diff "$BASE" <commit-base-da-worktree> --stat   # vazio = mesma árvore
```

Se não for vazio, avisa o usuário antes de seguir: os patches podem não aplicar na branch base.

Depois, em cada worktree (inclui arquivos novos):

```bash
git -C <worktree> add -N .
git -C <worktree> diff HEAD --stat
git -C <worktree> diff HEAD > <scratchpad>/issue-<n>.patch
```

### 4. Revisão cruzada (o coração da skill)

Com os diffs de **todas** as issues em mãos, compara cada par e procura:

1. **Mesmo arquivo:** arquivos alterados por mais de uma issue (`comm -12` das listas de `--name-only`). Se for a mesma região, é conflito textual. Se forem regiões diferentes, ler as duas alterações juntas mesmo assim.
2. **Contrato quebrado:** uma issue renomeia/remove/muda assinatura de função, tipo, prop, rota, coluna, enum ou variável de ambiente; a outra usa o nome/forma antigos. Confere com `grep` no código de cada worktree pelos símbolos alterados na outra.
3. **Schema/dados:** migrations, colunas, políticas de acesso, seeds. Numeração ou ordem colidindo, mesma tabela alterada, uma issue lendo coluna que a outra remove.
4. **Config compartilhada:** rotas, menus, i18n, constantes, tipos globais, manifesto de dependências/lockfile, arquivos de barrel (`index.ts`).
5. **Comportamento:** uma issue muda uma regra de negócio que a outra assume (ex: um status novo que a outra não trata).
6. **Efeitos declarados pelos subagents** (item 4 do relatório de cada um): confere se algum atinge a área de outra issue.

**Integração de teste — na working tree principal, sem worktree temporária.** Aplica os patches em sequência na branch base (`git apply --whitespace=nowarn <patch>`, e `--3way` se houver diferença de base) e roda ali build, lint e testes. Assim usa as dependências e o `.env` reais, sem junction.

Usa os comandos descobertos no passo 0. Se um teste já falhava antes das mudanças (ex: erro de coleta), ignora explicitamente e diz quais. Compara com o relatório de cada subagent: falha de aplicação ou de build/teste que não aparecia isolada é conflito semântico.

Se algo não puder ser verificado (sem build, sem browser, banco real, dependência não instalada), diz isso explicitamente em vez de declarar "sem conflito".

### 5. Relatório e resolução

Devolve ao usuário:

- por issue: resumo, arquivos, testes, o que ficou de fora, efeitos em outros fluxos;
- **conflitos encontrados**, cada um com: issues envolvidas, arquivo:linha, o que quebra, **severidade** (bloqueia / atenção / informativo) e **correção proposta**;
- **o que ficou sem verificar** (migration em banco real, browser, etc.);
- **ordem de ship recomendada** (a que menos depende das outras, e de menor risco, primeiro);
- se não achou nada: diz o que foi checado.

Só aplica correção de conflito depois de o usuário aprovar, e refaz a integração de teste depois de corrigir.

### 5.5. Migrations (só se alguma issue trouxe migration)

Se o repo não tiver staging, a migration vai pra produção. Os subagents nunca aplicam nada em banco; quem aplica é esta etapa, **só depois do relatório e com o usuário mandando aplicar** (ou confirmando quando eu perguntar).

1. **Ler o SQL inteiro** e confirmar que é idempotente (`IF NOT EXISTS`, `CREATE OR REPLACE`, `DROP ... IF EXISTS`) e transacional (`BEGIN`/`COMMIT`), sem `DROP`/`DELETE` de dados.
2. **Pré-teste só de leitura** no banco (connection string do `.env`, lendo o arquivo sem imprimir a URL): as tabelas, colunas e funções que a migration usa existem? O objeto novo ainda não existe? Migrations anteriores (as que ela depende) estão aplicadas?
3. **Aplicar** o arquivo inteiro numa transação e **verificar** depois (triggers, colunas, índices criados).
4. **Reportar** o que foi criado e como reverter (aditiva: dropar o que foi criado).

Se o pré-teste achar algo inesperado, para e mostra ao usuário em vez de aplicar.

### 6. Parar para revisão — não commita

Termina aqui. Se a integração de teste já deixou os patches aplicados na working tree, o usuário pode rodar o app local pra testar (atenção: confira pra onde o `.env` aponta). Fluxo até produção, **uma issue por vez, na ordem recomendada**:

1. Os arquivos de cada issue estão na working tree da branch base (ou reaplica o patch: `git apply <scratchpad>/issue-<n>.patch`).
2. `/issue-ship <n>` — o `issue-ship` stageia só os arquivos daquela issue.
3. **O PR agrega commits da branch.** Pra shipar separado, **o PR da primeira issue precisa estar mergeado antes de commitar a segunda** na mesma branch; se não, o mesmo PR leva as duas. Antes de rodar o `/issue-ship` da segunda, confere `gh pr view <pr> --json state`.
4. Depois do merge e do deploy, o usuário confirma e o `issue-ship` move cada issue pra Done.

### 7. Limpeza

Depois que tudo estiver commitado e mergeado (ou quando o usuário mandar), remove as worktrees dos subagents (liste com `git worktree list`):

```bash
git worktree remove --force <caminho-da-worktree>
git branch -D <branch-da-worktree>        # -D: a branch nunca foi mergeada
git worktree prune
```

**Antes do `--force`, confirma que não há junction/symlink de `node_modules` dentro da worktree**: remover uma junction com `--force` pode apagar o conteúdo apontado. Depois, confirma que o `node_modules` do repo principal continua lá. Só remove o que já está commitado; alteração não commitada só existe nessas worktrees se o usuário ainda não passou pelo `/issue-ship`.
