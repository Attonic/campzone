# Backlog do MVP: CampZone

Fonte da verdade do progresso. Mantido pelo orquestrador.

Repos (ADR 0001 e 0006): `Attonic/campzone-backend` (`backend/`), `Attonic/campzone-frontend` (`frontend/`) e `Attonic/campzone` (raiz, só documentação).

Status: `pendente` · `em andamento` · `em revisão` · `concluída`
Tags: **[BACK]** = `dev-back` · **[FRONT]** = `dev-front` · **[FULL]** = `dev-back` primeiro, depois `dev-front`.

| # | Tarefa | Tag | Status | Branch / PR | Notas |
|---|---|---|---|---|---|
| 00 | Scaffold | FULL | concluída | `feature/00-scaffold` (back e front) | spec: `docs/specs/00-scaffold.md` + Adendo A; **reviewer APROVADO** (scaffold: 3 rodadas; adendo: 2); back 21 testes, front 9 |
| 01 | Domínio e entidades JPA | BACK | concluída | `feature/01-dominio` (sobre a 00) | spec: `docs/specs/01-dominio.md`; **APROVADO** (3 rodadas), 93 testes; ADR 0003; entrou com `--no-ff` (o commit 073af88 não compila isolado; ADR 0006); herdar da 00: `@ActiveProfiles("dev")` no `contextLoads` (testar com `SPRING_PROFILES_ACTIVE=prod` exportado) |
| 02 | Auth e multi-tenant | BACK | concluída | `feature/02-auth` (sobre a 01) | spec: `docs/specs/02-auth.md`; **APROVADO** (revisão 2 + checagem final), 207 testes; ADR 0004; papéis `ADMIN_PLATAFORMA`/`ORGANIZADOR` (ADR 0002), admin seed (dev fixo, prod por env), usuário organizador de teste em dev; `JWT_SECRET` obrigatório no perfil prod; herdar da 00: erros fora do DispatcherServlet (firewall, filtro JWT) em ProblemDetail via `RequestRejectedHandler`/`ErrorController`; isolar `ApiTesteController` do scan |
| 03 | Motor: pontos corridos | BACK | concluída | `feature/03-motor-pontos-corridos` (sobre a 11) | spec: `docs/specs/03-motor-pontos-corridos.md`; ADR 0005 (interface `FormatoCompeticao`); **APROVADO** (revisão 1), 1542 testes, motor 100% linhas/ramos; 4 sugestões levadas para a 04 |
| 04 | Motor: mata-mata | BACK | concluída | `feature/04-motor-mata-mata` (sobre a 03) | spec: `docs/specs/04-motor-mata-mata.md`; ADR 0005 Adendo A (resultado como parâmetro de tipo, estado como função pura, sorteio por confronto, corrigido para SplitMix64); dev entregue + correções do orquestrador (2487 testes, motor 100%, conferido); **APROVADO** (rodada 2), 3385 testes, motor 100%, 9 mutantes mortos; barreira de fase total mantida (Antonio) |
| 05 | API de campeonatos | BACK | em revisão (aprovada, aguarda OK para merge) | `feature/05-api-campeonatos` (sobre a `main`) | spec: `docs/specs/05-api-campeonatos.md`; ADR 0007; **APROVADO** (rodada 3), 4044 testes; sugestões: guarda de texto em `@PathVariable` (09), ler o nome da restrição pelo `PSQLException` e teste real dos seeders (10) |
| 06 | API de partidas e resultados | BACK | em revisão | `feature/06-api-partidas-resultados` (sobre a 05) | spec: `docs/specs/06-api-partidas-resultados.md`; ADR 0008; entregue e conferido (`clean verify`, 4230 testes); reviewer rodada 1 |
| 07 | Front: auth e campeonato | FRONT | 07a **concluída** (3 rodadas, 58 testes); 07b pendente | | dividida: **07a** (login, cadastro, painel vazio; logo após a 02; spec `docs/specs/07a-front-auth.md` pronta) e **07b** (lista e wizard de campeonatos; após a 05). 07b herda: comentário em `App.test.tsx` (um teste por arquivo com o App real); fixar `TZ=UTC` nos testes (hoje 3 testes de data falham em UTC+9+); unificar `semearSessao` (`test/fixtures.ts` e `guardas.test.tsx`). Login único que redireciona por papel (admin → `/admin`, organizador → `/app`); herdar da 00: `httpClient` retornar `T \| undefined` (ou `void`) para corpo vazio; 07b herda da 05: enviar `null`, nunca `""`, em `seed` e `turnos` (o Jackson agora recusa) |
| 08 | Front: operação | FRONT | pendente | | depois da geração, renomear participante com seed exige reenviar a seed (sem ela, 409); confirmação forte no botão de gerar (irreversível) |
| 09 | Página pública | FULL | pendente | | herdar da 05: `@TextoValido` no `slug` do path e guarda `TextoValidoEmTodaEntradaTest` cobrindo `@PathVariable String` e tipos como `Optional<String>`/arrays |
| 10 | Acabamento | FULL | pendente | | herdar da 05: `RestricoesDeUnicidade` ler `PSQLException.getServerErrorMessage().getConstraint()` antes da mensagem; levar para a suíte o teste de seeders contra a unique real |
| 11 | Admin da plataforma | FULL | concluída | `feature/11-admin` (back sobre 02, front sobre 07a) | spec: `docs/specs/11-admin-plataforma.md`; **APROVADO** (revisão 1), back 293 testes, front 80; ADR 0002; precisa de método explícito de listagem no `OrganizacaoRepository`; executar logo após a 07; `/api/v1/admin/**` só leitura (orgs, plano, contagens) + tela |

## Escopo das tarefas

- **00 Scaffold [FULL]**: `backend/` pelo Spring Initializr (Boot 4.x estável mais recente, hoje 4.1.1, Java 21, Maven, web/jpa/security/validation/postgres, sem Flyway e sem migrations); `frontend/` com Vite + React + TypeScript + React Router + TanStack Query + Tailwind + Vitest; `docker-compose.yml` com PostgreSQL; perfis `dev` (padrão) e `prod` (Adendo A, substituiu o perfil `local`); GitHub Actions rodando `verify` (back) e `lint/test/build` (front); README mínimo com como rodar no Fedora.
- **01 Domínio e entidades JPA [BACK]**: `Organizacao`, `Plano`, `Campeonato` (com config por formato), `Participante`, `Fase`, `Rodada`, `Partida`, `Resultado`. Schema pelo Hibernate (`ddl-auto=update`). Plano grátis por `ApplicationRunner` idempotente (1 campeonato, 8 participantes).
- **02 Auth e multi-tenant [BACK]**: cadastro de organização + usuário, login com JWT, `organizacaoId` extraído do token, teste de isolamento base.
- **03 Motor: pontos corridos [BACK]**: `FormatoCompeticao`, `ConfigPontosCorridos`, round-robin, classificação, desempates. Cobertura ≥ 90%.
- **04 Motor: mata-mata [BACK]**: `ConfigMataMata`, chave com byes, seeding, ida e volta/série, desempate, 3º lugar, avanço de fase.
- **05 API de campeonatos [BACK]**: CRUD de campeonato com config do formato, CRUD de participantes, `LimitePlanoService`, geração do calendário/chave via motor.
- **06 API de partidas e resultados [BACK]**: lançar/corrigir resultado, recálculo da classificação, avanço de fase, idempotência e lock otimista.
- **07 Front: auth e campeonato [FRONT]**: login/cadastro, lista de campeonatos, wizard de criação com config de pontos corridos e mata-mata.
- **08 Front: operação [FRONT]**: participantes, geração, lançar resultados (mobile first), classificação e chave no painel.
- **09 Página pública [FULL]**: `/api/v1/public/**` por `slug` + página `/c/{slug}` com classificação, rodadas e chaveamento, link compartilhável, marca do CampZone no plano grátis.
- **11 Admin da plataforma [FULL]** (ADR 0002, ordem: depois da 07): endpoints `/api/v1/admin/**` restritos a `ADMIN_PLATAFORMA` (listar organizações com plano e contagens) e tela `/admin`.
- **10 Acabamento [FULL]**: seeds de demonstração, README completo, checklist de deploy, revisão geral do projeto.

## Histórico

- 2026-10-21: estrutura local organizada (arquivos movidos para `backend/CLAUDE.md`, `docs/`, `scripts/`), `git init`, commit inicial na `main`. Backlog criado. Tarefa 00 iniciada.
- 2026-10-21: Spring Boot 4.1.1 (4.x estável mais recente), a pedido do Antonio.
- 2026-10-21: ADR 0001, back e front em repos separados; raiz sem git (o `.git` antigo da raiz foi guardado fora do projeto). `frontend/CLAUDE.md` escrito como rascunho pelo orquestrador (revisar com o Antonio).
- Pendente na 10: atualizar `scripts/setup-fedora.sh` para os dois repos (inclui remover `application-local.*` do `.gitignore` que ele gera).
- 2026-10-21: tarefa 00, revisão 1 aprovada com ressalvas. Orquestrador decidiu aplicar junto: PostgreSQL 18 (sem dados ainda), porta do compose só em 127.0.0.1, `application-local` fora do classpath (`backend/config/`), `permissions` no CI.
- 2026-10-21: tarefa 00 aprovada pelo reviewer na revisão 3. Push/PR bloqueados: `gh` não instalado.
- 2026-10-21: Antonio pediu perfis `dev` e `prod` e banco funcionando: incluído como Adendo A na spec 00 (mesma branch, PR ainda não aberto). Porta 5433 vira padrão do projeto.
- 2026-10-21: Adendo A (perfis dev/prod) aprovado pelo reviewer. Tarefa 00 completa aguardando `gh`.
- 2026-10-21: Antonio pediu login de admin da plataforma + organizador (ADR 0002) e mandou seguir empilhando branches enquanto o `gh` não está pronto. Nova tarefa 11. 
- Ordem de execução (para o Antonio ver o login cedo): 01 → 02 → 07a (login/cadastro/painel vazio) → 11 (admin) → 03 → 04 → 05 → 06 → 07b (campeonatos/wizard) → 08 → 09 → 10.
- 2026-10-21: tarefa 01 revisão 1. ADR 0003 (enum como texto, colunas novas anuláveis, uniques sem recriar, @Version). Banco dev do Antonio tem CHECKs antigas: precisa recriar (só seed) com o OK dele.
- Regras da ADR 0003 registradas no `backend/CLAUDE.md` (commit c70592b na 01).
- 2026-10-21: tarefa 02 reprovada na revisão 1. ADR 0004: perfil explícito obrigatório (remove `profiles.default: dev`; IntelliJ via `backend/.run/`, `spring-boot:run` com dev no pom).
- 2026-10-21: 07a aprovada. Prontas para PR: 00, 01, 02 (back) e 00, 07a (front). Próxima pela ordem: 11 (admin), após o Antonio testar o login localmente.
- 2026-11-03: retomada. `gh` ainda ausente; banco dev ainda com schema antigo (sem OK para recriar). Tarefa 11 iniciada com bancos descartáveis.
- 2026-11-03: tarefa 11 aprovada pelo reviewer na revisão 1 (só sugestões, distribuídas para 05 e 07b). Prontas para PR: back 00, 01, 02, 11; front 00, 07a, 11. Próxima: 03 (motor de pontos corridos), empilhada sobre a 11.
- 2026-11-03: ADR 0005 (interface `FormatoCompeticao`: genérica por formato, motor só com `java.*`, enums próprios, `java.util.Random(seed)`). Tarefa 03 iniciada.
- 2026-11-03: tarefa 03 aprovada (revisão 1). ADR 0005 Adendo A. Tarefa 04 iniciada; decisões de produto do orquestrador a confirmar com o Antonio: MANUAL = seeds 1..n de todos (chave clássica), CABECAS_DE_CHAVE = seeds 1..k + sorteio do resto, n=3 sem disputa de 3º, config exige PENALTIS ou SORTEIO.
- 2026-11-03: dev da 04 achou viés na fórmula de sorteio do Adendo A (99,9% de coincidência entre confrontos vizinhos); corrigida com SplitMix64. SORTEIO proibido em SERIE; terminal por último. Pergunta ao Antonio: barreira de fase total (regra atual) ou avanço por confronto.
- 2026-11-06: Antonio decidiu publicar os repos como públicos, para o currículo (ADR 0006). Varredura do histórico sem segredos reais. Datas reais dos commits mantidas (21/10, 03/11 e 06/11). 
- 2026-11-06: publicação sem `gh` (ADR 0006). Antonio criou os 3 repos públicos e autorizou os merges. `main` publicada: back 00, 01, 02, 11, 03; front 00, 07a, 11. Raiz virou o repo `campzone`. 
- 2026-11-06: tarefa 04 aprovada na rodada 2 e publicada na `main`. Sugestão pendente para a 05: remover imports sem uso em `TorneioCompletoTest` (`idDaSeed`, `Test`). Banco dev: recriação autorizada pelo Antonio, aguardando ele rodar o comando (bloqueado pelo controle de permissões do Claude Code).
- 2026-11-06: tarefa 04 com CI verde. Antonio mandou seguir. Tarefa 05 iniciada; decisões do orquestrador: `turnos` até 10, `melhorDe` até 15, seed nunca sai na API, recurso de outra org responde 404, nome de participante pode ser corrigido depois da geração.
- 2026-11-06: Antonio testa tudo localmente ao chegar na tarefa 10. Até lá, as tarefas aprovadas ficam empilhadas em branches, sem merge na `main`, e o orquestrador não para entre elas. Ordem: 05 → 06 → 07b → 08 → 09 → 10. Parar só em dúvida de produto ou reprovação sem convergir.
- 2026-11-06: tarefa 05 aprovada na rodada 3 (4044 testes; os 4089 anteriores incluíam relatórios antigos do `target`, usar `clean`). ADR 0008. Tarefa 06 iniciada; decisões do orquestrador: finalizar manual e permitido com jogos em aberto, sem reabertura; correção que troca participantes de jogo já lançado é recusada (409); correção exige `versao`.
