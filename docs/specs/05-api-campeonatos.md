# 05 API de campeonatos [BACK]

## Objetivo

Permitir que o organizador crie e configure campeonatos, cadastre participantes dentro dos limites do plano e gere o calendário (pontos corridos) ou a chave (mata-mata) pelo motor.

## Contexto

- Repo `backend/`, branch `feature/05-api-campeonatos`, criada **a partir da `main`** (já tem as tarefas 00 a 04 e 11).
- Leia: `backend/CLAUDE.md`, ADR 0002, 0003 e 0005 (com o Adendo A), `docs/specs/03-motor-pontos-corridos.md` e `docs/specs/04-motor-mata-mata.md`.
- Todas as rotas exigem `ORGANIZADOR`. O `organizacaoId` vem só do JWT (`@OrganizacaoAtual`). Sem token dá 401; admin dá 403.
- **Recurso de outra organização responde 404**, igual a um que não existe. Nunca 403, para não revelar que existe.

## Contrato da API

Datas em ISO-8601. Erros em ProblemDetail; validação com `erros[{campo, mensagem}]`.

### Campeonatos

| Método e rota | Entrada | Sucesso | Erros |
|---|---|---|---|
| `POST /api/v1/campeonatos` | `CriarCampeonatoRequest` | 201 `CampeonatoResponse` | 400, 409 limite do plano |
| `GET /api/v1/campeonatos?pagina=0&tamanho=20` | query | 200 `PaginaResponse<CampeonatoResumoResponse>` | 400 |
| `GET /api/v1/campeonatos/{id}` | | 200 `CampeonatoResponse` | 404 |
| `PUT /api/v1/campeonatos/{id}` | `AtualizarCampeonatoRequest` | 200 `CampeonatoResponse` | 400, 404, 409 |
| `DELETE /api/v1/campeonatos/{id}` | | 204 | 404, 409 se não estiver em `RASCUNHO` |
| `POST /api/v1/campeonatos/{id}/gerar` | sem corpo | 201 `GeracaoResponse` | 404, 409, 422 |

Listagem: `pagina` ≥ 0 (padrão 0), `tamanho` de 1 a 100 (padrão 20), ordenada por `criadoEm` e depois `id`, ambos decrescentes.

`CriarCampeonatoRequest`:

| campo | tipo | regra |
|---|---|---|
| `nome` | string | obrigatório, 2..120 |
| `modalidade` | string | obrigatório, 2..60 |
| `formato` | `"PONTOS_CORRIDOS"` \| `"MATA_MATA"` | obrigatório |
| `configPontosCorridos` | `ConfigPontosCorridosRequest` \| null | obrigatória só no formato `PONTOS_CORRIDOS`; proibida no outro |
| `configMataMata` | `ConfigMataMataRequest` \| null | obrigatória só no formato `MATA_MATA`; proibida no outro |

`AtualizarCampeonatoRequest`:

| campo | tipo | regra |
|---|---|---|
| `nome` | string | obrigatório, 2..120 |
| `modalidade` | string | obrigatório, 2..60 |
| `publico` | boolean | obrigatório |
| `configPontosCorridos` | `ConfigPontosCorridosRequest` \| null | nulo = não altera; do formato errado = 400 |
| `configMataMata` | `ConfigMataMataRequest` \| null | nulo = não altera; do formato errado = 400 |

`nome`, `modalidade` e `publico` podem mudar em qualquer status. Alterar a config fora de `RASCUNHO` dá 409. O `formato` e o `slug` nunca mudam.

`ConfigPontosCorridosRequest`:

| campo | tipo | regra |
|---|---|---|
| `turnos` | number | 1..10 |
| `pontosVitoria`, `pontosEmpate`, `pontosDerrota` | number | 0..100; as regras entre eles vêm do motor |
| `permiteEmpate` | boolean | obrigatório |
| `criteriosDesempate` | `("PONTOS"\|"VITORIAS"\|"SALDO"\|"PRO"\|"CONFRONTO_DIRETO"\|"SORTEIO")[]` | obrigatório; a ordem importa; as regras vêm do motor |

`ConfigMataMataRequest`:

| campo | tipo | regra |
|---|---|---|
| `tipoConfronto` | `"JOGO_UNICO"\|"IDA_E_VOLTA"\|"SERIE"` | obrigatório |
| `melhorDe` | number \| null | só em `SERIE`; ímpar de 3 a 15 |
| `desempates` | `("GOLS_FORA"\|"PRORROGACAO"\|"PENALTIS"\|"SORTEIO")[]` | obrigatório; a ordem importa; as regras vêm do motor |
| `seeding` | `"ALEATORIO"\|"MANUAL"\|"CABECAS_DE_CHAVE"` | obrigatório |
| `disputaTerceiroLugar` | boolean | obrigatório |

`CampeonatoResponse`:

| campo | tipo |
|---|---|
| `id` | number |
| `nome`, `modalidade`, `slug` | string |
| `formato` | `"PONTOS_CORRIDOS"` \| `"MATA_MATA"` |
| `status` | `"RASCUNHO"` \| `"EM_ANDAMENTO"` \| `"FINALIZADO"` |
| `publico` | boolean |
| `configPontosCorridos` | `ConfigPontosCorridosResponse` \| null |
| `configMataMata` | `ConfigMataMataResponse` \| null |
| `totalParticipantes` | number |
| `criadoEm` | string |

`ConfigPontosCorridosResponse` e `ConfigMataMataResponse` têm os mesmos campos dos respectivos `Request`.

`CampeonatoResumoResponse`: `id`, `nome`, `modalidade`, `slug`, `formato`, `status`, `publico`, `totalParticipantes`, `criadoEm`.

`GeracaoResponse`:

| campo | tipo |
|---|---|
| `campeonatoId` | number |
| `status` | sempre `"EM_ANDAMENTO"` |
| `totalFases` | number (fases persistidas) |
| `totalRodadas` | number (0 no mata-mata) |
| `totalConfrontos` | number (0 nos pontos corridos) |
| `totalPartidas` | number |

**A seed do sorteio nunca sai na API nem no log.** Com ela daria para prever os sorteios de desempate.

### Participantes

| Método e rota | Entrada | Sucesso | Erros |
|---|---|---|---|
| `GET /api/v1/campeonatos/{id}/participantes` | | 200 `ParticipanteResponse[]` | 404 |
| `POST /api/v1/campeonatos/{id}/participantes` | `CriarParticipanteRequest` | 201 `ParticipanteResponse` | 400, 404, 409 |
| `PUT /api/v1/campeonatos/{id}/participantes/{participanteId}` | `AtualizarParticipanteRequest` | 200 `ParticipanteResponse` | 400, 404, 409 |
| `DELETE /api/v1/campeonatos/{id}/participantes/{participanteId}` | | 204 | 404, 409 |

- `CriarParticipanteRequest` e `AtualizarParticipanteRequest`: `nome` (obrigatório, 2..120) e `seed` (number \| null, ≥ 1).
- `ParticipanteResponse`: `id`, `nome`, `seed` (number \| null).
- Listagem ordenada por `seed` (nulos por último), depois `nome`, depois `id`.
- Criar, excluir ou mudar a `seed` fora de `RASCUNHO` dá 409. Corrigir o `nome` é permitido em qualquer status.
- Nome repetido no mesmo campeonato dá 409, inclusive em corrida (violação da `uk` vira 409, não 500).
- `participanteId` de outro campeonato, mesmo da mesma organização, dá 404.

## Regras

### Limites do plano

- `LimitePlanoService` (interface + `Impl`) é o **único** lugar que lê `maxCampeonatosAtivos` e `maxParticipantes`.
- Violação lança `LimitePlanoExcedidoException`: HTTP 409 com `detail` claro e as propriedades `limite` e `atual` no ProblemDetail.
- **Sem furar o limite em corrida:**
  - criar campeonato trava a linha da organização (`PESSIMISTIC_WRITE`) antes de contar;
  - criar participante e gerar travam a linha do campeonato.

  Prove com teste de concorrência em Postgres real: N requisições simultâneas e no máximo o limite criado.

### Criação

- **Slug:** gerado do nome (sem acento, minúsculas, não alfanumérico vira `-`, até 100 caracteres; nome sem nada aproveitável vira `campeonato`). Se já existir, recebe um sufixo aleatório de 6 caracteres. O slug é único global e nasce uma vez só. Violação da `uk` em corrida vira 409.
- **Config:** o `Request` é traduzido para os embeddables e **também** para a config do motor, que valida as regras (ex.: `PONTOS` primeiro, terminal por último). `ConfigInvalidaException` vira 400 com a mensagem do motor. Assim, uma config inválida nunca chega à geração.
- A tradução fica num mapper do módulo `campeonato`. Teste de paridade garante que os enums JPA e do motor têm os mesmos valores (`CriterioDesempate`, `TipoConfronto`, `DesempateMataMata`, `Seeding`).

### Geração (`POST /gerar`)

Na mesma transação:

1. Trava o campeonato. Se não estiver em `RASCUNHO`: 409.
2. Sorteia a seed (`GeradorSeedSorteio`, interface + implementação com `SecureRandom`, mockável nos testes) e a registra em `Campeonato.seedSorteio`.
3. Chama o motor com os participantes. `ParticipantesInvalidosException` (menos de 2, seeds inválidas do `MANUAL`/`CABECAS_DE_CHAVE`) vira 422 com a mensagem do motor e **nada é persistido**, nem a seed.
4. Persiste a estrutura:
   - **Pontos corridos:** 1 `Fase` ("Fase única"), todas as `Rodada`s e todas as `Partida`s `AGENDADA`. A folga não é persistida: quem não joga na rodada, folga.
   - **Mata-mata:** só a **1ª fase**: a `Fase`, todos os `Confronto`s (bye já com vencedor e sem partida) e as `Partida`s dos jogos. As fases seguintes são criadas na tarefa 06, ao abrirem, porque ainda não têm participantes.
5. Muda o status para `EM_ANDAMENTO`.

Se o domínio não permitir algum desses passos (ex.: fábrica de `Confronto`), ajuste seguindo a ADR 0003 e relate. Mudança que possa quebrar dados existentes: avise antes.

### Erros

Novos handlers no `GlobalExceptionHandler`:

- `RecursoNaoEncontradoException`: 404.
- Conflito de estado (`ConflitoException` ou equivalente): 409.
- `OptimisticLockingFailureException`: 409 com "o recurso foi alterado, tente novamente".
- `ConfigInvalidaException`: 400. `ParticipantesInvalidosException`: 422. `ResultadoInvalidoException`: 422 (será usada na 06).
- Corpo ilegível, inclusive enum inválido: 400 em português, sem vazar nome de classe.

## Herdado de tarefas anteriores (fazer junto, em commits próprios)

1. **Da 11:**
   - centralizar os status ativos em `StatusCampeonato` e usar em `Campeonato.isAtivo()`, no admin e no limite do plano;
   - handler de `ConstraintViolationException` só para violações vindas de controllers (`getRootBeanClass()`); violação em service continua 500;
   - `handleTypeMismatch` com mensagem em português e `erros[{campo, mensagem}]`.
2. **Da 04:** remover os imports sem uso em `TorneioCompletoTest` (`idDaSeed` e `Test`).
3. **Da 02:**
   - `PerfilObrigatorio` com `@Order(HIGHEST_PRECEDENCE)` ou `PriorityOrdered`;
   - validar na subida as assinaturas de `@OrganizacaoAtual` (varrer os `HandlerMethod`s), falhando se o parâmetro não for `Long`;
   - `TestCampzoneApplicationTest` sem `assumeTrue` do ambiente.
4. **Da 01:** sem N+1 nas listagens. A lista de campeonatos traz `totalParticipantes` de uma única consulta agregada, com teste de quantidade de consultas (mesmo padrão do `AdminIntegracaoTest`).

## Testes obrigatórios

- **Isolamento multi-tenant (todas as rotas):** org B recebe 404 ao ler, alterar, excluir e gerar campeonato da org A, e ao mexer nos participantes dele. Listagens de B não trazem nada de A.
- **Papéis:** sem token 401; admin 403, em todas as rotas.
- **Limites:**
  - valores vêm do `Plano`, não hardcoded: teste com um plano de limites diferentes;
  - plano grátis: o 2º campeonato ativo dá 409; depois de excluir o rascunho, volta a criar; `FINALIZADO` não conta;
  - o 9º participante dá 409;
  - concorrência nos dois casos.
- **Validação:** cada regra do `Request`; config do formato errado; config recusada pelo motor; enum inválido; `turnos` 11; `melhorDe` 17.
- **Geração:**
  - pontos corridos com 4 e 5 participantes, turno único e ida e volta (contagens e conteúdo batendo com o motor);
  - mata-mata com 4, 5 e 8 participantes, cada tipo de confronto (byes, série com N partidas);
  - gerar duas vezes dá 409; concorrência gera uma só;
  - menos de 2 participantes e seeds inválidas dão 422 sem persistir nada (status continua `RASCUNHO`, seed nula);
  - a seed não aparece em nenhuma resposta.
- **Regras de status:** cada operação bloqueada depois da geração dá 409; renomear campeonato e participante continua funcionando.
- **Slug:** acentos, símbolos, nome só com símbolos, colisão.
- `Impl` com Mockito, controller com web test mockando a interface, repositórios com Testcontainers.

## Critérios de aceite

- [ ] Contrato acima exatamente.
- [ ] Isolamento multi-tenant testado em todas as rotas.
- [ ] Limites só no `LimitePlanoService`, sem furar em corrida.
- [ ] `./mvnw verify` verde.
- [ ] Teste manual com `curl`, contra Postgres descartável (porta 55440): cadastrar organização, criar campeonato de cada formato, adicionar participantes, gerar, e conferir no `/api/v1/admin/resumo` os números do campeonato. Inclua os JSONs reais no relatório.

## Fora de escopo

Listar partidas, lançar resultados, classificação, avanço de fase e finalizar campeonato (06); página pública (09); telas (07b, 08).
