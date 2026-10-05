---
name: create-pr
version: 1.0.0
author: guilhermetft
description: Abre PR no GitHub via gh CLI a partir da branch atual já commitada. Usa Conventional Commits no título, corpo curto, labels existentes, assignee = usuário autenticado. Nunca commita código, nunca faz merge, nunca adiciona Claude como co-author/assignee. Trigger — "cria PR", "abre PR", "create PR", "open pull request", "fazer PR dessa branch".
---

# create-pr

Empacota o que já está commitado na branch atual em um PR bem formatado.
**Não escreve código, não faz commit, não faz merge.** Se houver mudanças não commitadas, avisa e para (não commita por conta própria).

> **O merge é SEMPRE do usuário.** A skill termina quando o PR é aberto e a URL é mostrada. Ver "Nunca fazer merge" abaixo.

## Pré-requisitos

```bash
gh auth status
```

Se não autenticado: avisa o usuário e para. Não tenta `gh auth login` sozinho.

Repo precisa ter remote GitHub configurado (`git remote -v`).

## Passo a passo

1. **Estado atual**
   ```bash
   git branch --show-current
   git status
   ```
   Se `git status` mostrar mudanças não commitadas (staged ou não), avisa o usuário explicitamente e pergunta se quer continuar mesmo assim ou commitar primeiro. Não commita nada.

2. **Branch no remote**
   ```bash
   git push -u origin <branch>
   ```
   Só roda se a branch ainda não estiver no remote (checa antes com `git ls-remote --heads origin <branch>` ou `git status -sb`). Isso é pré-requisito técnico do `gh pr create`, não uma ação extra — não pede confirmação pra isso especificamente, mas é bom sinalizar que vai fazer push.

3. **PR já existe?**
   ```bash
   gh pr view --json url,state
   ```
   Se já existir PR aberto pra essa branch, mostra a URL e para — não duplica.

4. **Branch base**
   ```bash
   gh repo view --json defaultBranchRef -q .defaultBranchRef.name
   ```
   Usa o default do repo, a menos que o usuário especifique outra base explicitamente.

5. **Entender a mudança**
   ```bash
   git log <base>..<branch> --oneline
   git diff <base>..<branch> --stat
   ```
   Base pra decidir tipo do Conventional Commit e escrever o resumo.

6. **Título — Conventional Commits**
   Formato: `tipo(escopo opcional): descrição curta no imperativo`
   Tipos válidos: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`, `build`, `ci`.
   Tipo escolhido pelo conteúdo real do diff, não pelo nome da branch.

7. **Corpo — só resumo**
   Segue o modelo em `templates/pr-body.md` (na pasta desta skill): 2-4 linhas ou bullets curtos descrevendo o que mudou. Se o arquivo não existir, usa esse mesmo formato. **Sem** "Test plan", **sem** checklist, **sem** seções extras, **sem** "Generated with Claude Code", **sem** "Co-Authored-By: Claude" — Claude nunca aparece no PR de forma alguma (nem assignee, nem contribuidor, nem menção).

8. **Labels**
   ```bash
   gh label list
   ```
   Usa só labels que já existem no repo e que fazem sentido pro PR. Nunca cria label nova.

9. **Assignee**
   ```bash
   gh api user -q .login
   ```
   Assignee é sempre o usuário autenticado no `gh` — nunca Claude, nunca vazio.

10. **Criar o PR**
    ```bash
    gh pr create \
      --base <base> \
      --title "<tipo(escopo): descrição>" \
      --body "<resumo>" \
      --label "<label1>,<label2>" \
      --assignee "<login>"
    ```
    Mostra a URL final retornada.

11. **Parar aqui.** A skill acabou. Não mergeia, não faz push pra base, não fecha o PR.

## Nunca fazer merge

**O merge é decisão e ação do usuário, sempre. Sem exceção.**

Proibido, mesmo que pareça implícito no pedido:

- `gh pr merge` em qualquer variação (`--merge`, `--squash`, `--rebase`, `--auto`, `--admin`)
- `git merge <branch>` seguido de `git push` na branch base
- `git push origin <branch>:<base>`
- Habilitar auto-merge

Isso vale **inclusive** quando o usuário escreve coisas como:

- "abre PR e joga pra main"
- "manda pra main"
- "sobe isso pra produção"
- "PR e merge"
- "pode integrar"

Nenhuma dessas frases autoriza o merge. Elas descrevem o objetivo final, não delegam a execução. Abre o PR, mostra a URL e diz que o merge está com ele.

Só existe uma exceção: o usuário pedir merge **explicitamente e em separado**, depois de o PR já estar aberto — por exemplo "pode mergear o PR #3 agora". Aí sim, confirmando antes qual método (merge commit, squash ou rebase).

Motivo: merge é irreversível na prática, dispara deploy e é o momento de revisão do usuário. Abrir PR é reversível; mergear não.

## Resumo das regras

1. Título sempre em Conventional Commits.
2. Corpo é só o resumo — nada de seções extras.
3. Labels só as existentes no repo, nunca inventa.
4. Assignee sempre o usuário autenticado (`gh api user -q .login`).
5. Claude nunca aparece no PR — sem assignee, sem co-author, sem menção, sem rodapé "Generated with Claude Code".
6. **Nunca mergeia.** A skill entrega a URL do PR e para. Ver "Nunca fazer merge" acima.
