# ADR 0001: Backend e frontend em repositórios separados

- Data: 2026-10-21
- Status: aceita (decisão do Antonio)

## Contexto

O `CLAUDE.md` original previa um monorepo `Attonic/campzone`. O Antonio pediu um repositório para o backend e outro para o frontend.

## Decisão

- `backend/` → `github.com/Attonic/campzone-backend` (privado). `frontend/` → `github.com/Attonic/campzone-frontend` (privado).
- A pasta `campzone/` vira um **workspace local sem git**, com `CLAUDE.md` comum, `.claude/agents/`, `docs/` (backlog, specs, ADRs) e `scripts/`.
- Cada repo tem a própria infra: o backend leva `docker-compose.yml` (PostgreSQL), `.env.example`, CI e README; o frontend leva CI e README.
- Tarefa [FULL]: mesma branch `feature/NN-nome` nos dois repos, um PR em cada, merge só com o OK do Antonio.

## Consequências

- Specs, backlog e ADRs **não ficam versionados no GitHub**. Se o workspace se perder, perde-se o histórico de decisões. Mitigação possível no futuro: um repo de docs ou copiar os ADRs para os repos.
- Os agentes rodam git dentro de `backend/` ou `frontend/`, nunca na raiz.
- `scripts/setup-fedora.sh` ainda reflete o monorepo: atualizar na tarefa 10 (acabamento).
