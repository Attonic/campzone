Você é o orquestrador do projeto CampZone. Leia agora, inteiros: `CLAUDE.md` (raiz), `backend/CLAUDE.md`, `frontend/CLAUDE.md`, e os três agentes em `.claude/agents/` (`dev-back.md`, `dev-front.md`, `reviewer.md`). Siga a seção "Orquestração" do `CLAUDE.md`.

Objetivo: entregar o MVP do CampZone, um SaaS para gerir campeonatos (pontos corridos e mata-mata, ambos configuráveis), com plano grátis de 1 campeonato e até 8 participantes, e página pública com classificação e chaveamento.

## O que fazer agora

1. Crie `docs/BACKLOG.md` com a lista abaixo (status: pendente / em andamento / em revisão / concluída) e comece a mantê-lo.
2. Execute a tarefa 00 pelo ciclo do `CLAUDE.md` (spec → dev da tag → você confere → `reviewer` → ajustes → PR). Ao abrir o PR, **pare e me avise**. Eu autorizo o merge e a próxima tarefa.
3. Se eu disser "pode seguir autônomo", encadeie as tarefas seguintes, mas continue sem fazer merge sem o meu OK, parando se o reviewer reprovar 3 vezes seguidas.

## Backlog do MVP

Tags: **[BACK]** = `dev-back`, **[FRONT]** = `dev-front`, **[FULL]** = `dev-back` primeiro e depois `dev-front`. Toda spec de tarefa que toca a API traz o contrato (endpoint, `Request`, `Response`).

- **00 Scaffold [FULL]**: `backend/` gerado pelo Spring Initializr (Boot 4.0.x estável mais recente, Java 21, Maven, web/jpa/security/validation/postgres, sem Flyway e sem migrations); `frontend/` com Vite + React + TypeScript + React Router + TanStack Query + Tailwind + Vitest; `docker-compose.yml` com PostgreSQL; perfil `local`; GitHub Actions rodando `verify` (back) e `lint/test/build` (front); README mínimo com como rodar no Fedora. Atenção: `backend/` e `frontend/` já contêm um `CLAUDE.md`. Gere os projetos numa pasta temporária e mova os arquivos para dentro sem sobrescrever esses `CLAUDE.md`.
- **01 Domínio e entidades JPA [BACK]**: `Organizacao`, `Plano`, `Campeonato` (com config por formato), `Participante`, `Fase`, `Rodada`, `Partida`, `Resultado`. Schema gerado pelo Hibernate (`ddl-auto=update`), sem migrations. Plano grátis criado por um `ApplicationRunner` idempotente (1 campeonato, 8 participantes).
- **02 Auth e multi-tenant [BACK]**: cadastro de organização + usuário, login com JWT, `organizacaoId` extraído do token, teste de isolamento base. Já no padrão `Request`/`Response` e `Service` + `Impl`.
- **03 Motor: pontos corridos [BACK]**: `FormatoCompeticao`, `ConfigPontosCorridos`, geração round-robin, classificação, desempates. Testes pesados, cobertura ≥ 90%. (ADR curto da interface antes.)
- **04 Motor: mata-mata [BACK]**: `ConfigMataMata`, chave com byes, seeding (aleatório com seed, manual, cabeças de chave), ida e volta/série, desempate, 3º lugar, avanço de fase. Testes pesados.
- **05 API de campeonatos [BACK]**: CRUD de campeonato com configuração do formato, CRUD de participantes, `LimitePlanoService`, geração do calendário/chave via motor.
- **06 API de partidas e resultados [BACK]**: lançar/corrigir resultado, recálculo da classificação, avanço de fase no mata-mata, idempotência e lock otimista.
- **07 Front: auth e campeonato [FRONT]**: login/cadastro, lista de campeonatos, wizard de criação com configuração de pontos corridos e de mata-mata.
- **08 Front: operação [FRONT]**: participantes, geração, tela de lançar resultados (mobile first), classificação e chave dentro do painel.
- **09 Página pública [FULL]**: endpoint `/api/v1/public/**` por `slug` + página `/c/{slug}` com classificação, rodadas e chaveamento visual, link compartilhável, marca do CampZone no plano grátis.
- **10 Acabamento [FULL]**: seeds de demonstração, README completo, checklist de deploy, revisão geral do reviewer sobre o projeto todo.

## Regras que valem sempre

- Uma tarefa por vez. Nunca pule o reviewer.
- Verifique você mesmo (`./mvnw verify` no back; lint/test/build no front) antes de chamar o reviewer; não confie só no relatório do dev.
- Padrões obrigatórios no back: `XxxRequest`/`XxxResponse` e `Service` interface + `Impl`. No front: tipos espelhando o back e acesso à API só pela camada `api/`.
- Banco: PostgreSQL. **Sem migrations e sem Flyway**: o schema vem das entidades JPA via Hibernate. Não crie arquivos `V__*.sql`.
- Pergunte quando a dúvida for de produto. Decida e registre ADR quando a dúvida for técnica com opção óbvia.
- Seja direto nos relatórios: o que foi feito, o que passou, o que precisa de mim.

Comece lendo os arquivos e criando o backlog.
