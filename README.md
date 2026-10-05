# Claude Code Skills — workflow GitHub Issue → PR

Skills para o [Claude Code](https://claude.com/claude-code) que automatizam o ciclo
**ideia → issue → implementação → commit → PR** usando a CLI `gh`.
Nada é fixo por repositório: owner, Project, colunas de Status e branch base são detectados em runtime.

## Skills

| Skill | Comando | O que faz |
|-------|---------|-----------|
| [`issue-new`](skills/issue-new/SKILL.md) | `/issue-new` | Cria a issue (título Conventional Commits, tarefas, critérios de aceite), adiciona ao Project e define o Status inicial. Pede confirmação antes de criar. |
| [`issue-work`](skills/issue-work/SKILL.md) | `/issue-work <n>` | Move a issue para *In progress*, divide em tarefas, implementa e testa. Para para revisão; **nunca commita**. |
| [`issue-work-multi`](skills/issue-work-multi/SKILL.md) | `/issue-work-multi <n1> <n2> ...` | Trabalha em várias issues em paralelo (subagents + worktrees isoladas) e faz revisão cruzada para achar conflitos. **Nunca commita**. |
| [`issue-ship`](skills/issue-ship/SKILL.md) | `/issue-ship <n>` | Após sua aprovação: commita, fecha a issue, move para *Done* e abre o PR via `create-pr`. |
| [`create-pr`](skills/create-pr/SKILL.md) | `/create-pr` | Abre o PR da branch atual (já commitada) com título Conventional Commits, labels existentes e você como assignee. **Nunca faz merge**. |

Fluxo:

```
/issue-new  →  /issue-work <n>  →  (você revisa)  →  /issue-ship <n>  →  (você faz o merge)
```

## Requisitos

- [Claude Code](https://claude.com/claude-code)
- [GitHub CLI](https://cli.github.com/) autenticado, com escopo de Projects:
  ```bash
  gh auth login
  gh auth refresh -s project
  ```
- Repositório git com remote no GitHub

## Instalação

Uma linha, direto do GitHub (global, em `~/.claude/skills`):

```bash
curl -fsSL https://raw.githubusercontent.com/guilhermetft/issue-flow/main/install.sh | bash
```

Ou clonando:

```bash
git clone https://github.com/guilhermetft/issue-flow.git
cd issue-flow
./install.sh              # global (~/.claude/skills)
./install.sh --project    # só no projeto atual (./.claude/skills)
./install.sh --force      # sobrescreve sem perguntar
```

Reinicie o Claude Code e use `/issue-new`, etc.

> `issue-ship` chama `create-pr`, e `issue-work-multi` segue o `issue-work`: o script instala o conjunto completo.
> No Windows, rode o script no Git Bash ou WSL.

## Desinstalação

```bash
./uninstall.sh              # global
./uninstall.sh --project    # projeto atual
./uninstall.sh --yes        # sem confirmação
```

Remove só as 5 skills deste repo; outras skills suas não são tocadas.

## Garantias de segurança

- Nenhuma skill faz merge. O merge é sempre seu.
- `issue-work` e `issue-work-multi` nunca commitam.
- `issue-new` e `issue-ship` pedem confirmação/aprovação antes de ações visíveis a outros.
- Labels nunca são criadas — só as já existentes no repo.

## Personalização

As skills são Markdown puro (`SKILL.md`). Edite livremente, por exemplo:

- idioma e formato das mensagens de commit;
- nomes de Status (*In progress*, *Done*) — hoje há fallback para equivalentes;
- regra de autoria: `create-pr`/`issue-ship` proíbem Claude como co-author/assignee; remova essas linhas se quiser o contrário.

As skills estão escritas em português (pt-BR).

## Licença

[MIT](LICENSE)
