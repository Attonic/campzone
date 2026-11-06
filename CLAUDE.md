# CampZone

SaaS para organizar campeonatos de qualquer modalidade (futebol society, futebol, xadrez, esports). A modalidade é só rótulo/configuração: o motor de competição é genérico.

**MVP**
- Plano grátis: 1 campeonato ativo, até 8 participantes (valores vêm da entidade `Plano`, nunca hardcoded).
- Formatos: **pontos corridos** e **mata-mata (eliminatória simples)**, ambos configuráveis.
- Página pública com classificação e chaveamento, link compartilhável.

**Fora do MVP (não implementar, não "preparar demais")**: grupos+mata-mata, suíço, eliminatória dupla, pagamentos, planos pagos, app mobile, microsserviços.

Dono: Antonio (@Attonic). Repos (públicos, ADR 0006): `github.com/Attonic/campzone-backend` e `github.com/Attonic/campzone-frontend`.
Idioma: domínio em português (`Campeonato`, `Partida`), termos técnicos em inglês (`Service`, `Repository`). Comentários e mensagens de commit em português.

Este arquivo tem só o que é **comum** ao projeto. Regras técnicas ficam em:
- `backend/CLAUDE.md` (Java, Spring Boot, motor de competição)
- `frontend/CLAUDE.md` (React)

Ao trabalhar numa pasta, siga este arquivo + o da pasta. Em conflito, o arquivo mais específico vence.

## Stack (resumo)

| | |
|---|---|
| Backend | Java 21, Spring Boot 4.x (estável mais recente; hoje 4.1.1), Maven (`./mvnw`), PostgreSQL, JPA/Hibernate (sem Flyway, sem migrations), Spring Security + JWT |
| Frontend | React (versão estável mais recente), TypeScript, Vite |
| Infra local | docker-compose (PostgreSQL), Fedora |

Versões: nunca fixe de memória. Backend pelo Spring Initializr (4.x estável mais recente); front com `npm create vite@latest`.

## Estrutura do repositório

Três repositórios git independentes (ADR 0001 e 0006): `backend/` e `frontend/` têm o código, e a pasta raiz é o repo `github.com/Attonic/campzone`, só de documentação e agentes. A raiz ignora `backend/` e `frontend/`.

```
campzone/                # repo github.com/Attonic/campzone (público, só documentação)
  README.md              # apresentação e fluxo dos agentes
  CLAUDE.md              # este arquivo
  .claude/agents/        # dev-back.md, dev-front.md, reviewer.md
  scripts/               # setup-fedora.sh e utilitários
  docs/
    BACKLOG.md           # fonte da verdade do progresso (orquestrador mantém)
    specs/NN-nome.md     # spec curta por tarefa (inclui o contrato da API)
    adr/                 # decisões de arquitetura (curtas)
  backend/               # repo github.com/Attonic/campzone-backend (público)
    CLAUDE.md, pom.xml, docker-compose.yml, .github/workflows/ci.yml, README.md
  frontend/              # repo github.com/Attonic/campzone-frontend (público)
    CLAUDE.md, package.json, .github/workflows/ci.yml, README.md
```

## Contrato front ↔ back

- API REST JSON em `/api/v1`. Rotas públicas somente em `/api/v1/public/**`. Erros em `ProblemDetail` (RFC 9457). Datas em ISO-8601.
- Nomes de payload seguem o mesmo padrão nos dois lados: `XxxRequest` (entrada) e `XxxResponse` (saída). Ex.: `CriarCampeonatoRequest`, `CampeonatoResponse`.
- A **spec da tarefa é a fonte do contrato**: toda tarefa que toca os dois lados lista endpoints, método, `Request` e `Response` (campos e tipos).
- Quem muda o contrato é o backend, primeiro; a spec é atualizada e só então o front acompanha. O front nunca inventa campo nem endpoint.
- Regra de negócio (classificação, chaveamento, limites do plano) vive só no backend. O front exibe o que a API devolve.

## Definition of Done (toda tarefa)

1. Spec atendida (critérios de aceite e contrato).
2. Testes escritos e passando. Backend: `cd backend && ./mvnw verify`. Front: `cd frontend && npm run lint && npm test && npm run build`.
3. Regras do `backend/CLAUDE.md` e/ou `frontend/CLAUDE.md` respeitadas (inclusive Request/Response e Service+Impl).
4. Teste de isolamento multi-tenant quando expõe dados.
5. Sem segredos no código: credenciais de prod só por variável de ambiente; `.env` fora do git. As credenciais do `application-dev.yml` são só do PostgreSQL Docker local.
6. Revisão do agente `reviewer` com veredito **APROVADO** (ou ressalvas aceitas pelo Antonio).
7. Commits no padrão Conventional Commits em português (`feat(motor): gera tabela round-robin`, `feat(front/campeonato): wizard de criação`).

## Git

- Git de código roda **dentro** de `backend/` ou `frontend/`. A raiz (`campzone`) só recebe documentação, com commit do orquestrador direto na `main`. Email dos commits: `a.cleisonn@gmail.com` (configurado em cada repo).
- Sem o `gh` instalado, o passo do PR vira merge local com `--no-ff` e push da `main`, sempre com o OK do Antonio (ADR 0006).
- `main` protegida. Trabalho em `feature/NN-nome` no repo da área, um PR por tarefa do backlog **por repo** ([FULL] = um PR no back e um no front, com o mesmo nome de branch).
- Commits pequenos e coesos. Nada de `git push --force`, nada de commit direto na `main`.
- **Merge na `main` só com o OK explícito do Antonio.**

## Orquestração (agentes)

A sessão principal do Claude Code é o **orquestrador**. Ele não escreve código de feature: coordena, mantém o backlog e decide.

Agentes (em `.claude/agents/`):
- `dev-back`: implementa tarefas do backend (só mexe em `backend/`).
- `dev-front`: implementa tarefas do frontend (só mexe em `frontend/`).
- `reviewer`: revisa o diff em contexto limpo, somente leitura, contra estes arquivos.

Cada tarefa do `docs/BACKLOG.md` tem uma tag: **[BACK]**, **[FRONT]** ou **[FULL]** (os dois).

Ciclo por tarefa:
1. Orquestrador escreve a spec curta em `docs/specs/NN-nome.md` (objetivo, critérios de aceite, **contrato da API**, fora de escopo) e cria a branch `feature/NN-nome` no(s) repo(s) da tag.
2. Chama o dev da tag: [BACK] → `dev-back`; [FRONT] → `dev-front`; [FULL] → `dev-back` primeiro, confere, e só então `dev-front`.
3. Orquestrador confere sozinho se os checks passaram (`./mvnw verify` e/ou lint+test+build), sem confiar só no relatório.
4. Chama `reviewer` com a spec e a branch (em [FULL], uma revisão do conjunto).
5. Achados `BLOQUEANTE` e `IMPORTANTE` voltam ao dev da área do achado. Máximo de 3 ciclos dev↔reviewer; se não convergir, o orquestrador para e pergunta ao Antonio.
6. Aprovado: push da branch e PR via `gh pr create` em cada repo tocado, atualiza o `BACKLOG.md` e **para** esperando o OK do Antonio para o merge.

Regras do orquestrador:
- Uma tarefa por vez. Não iniciar a seguinte sem o merge (ou ordem explícita do Antonio).
- Nunca pular o reviewer.
- Se uma decisão muda a arquitetura, registrar ADR curto em `docs/adr/` e avisar o Antonio.
- Em dúvida de produto, perguntar. Em dúvida técnica com opção óbvia, decidir e registrar.
