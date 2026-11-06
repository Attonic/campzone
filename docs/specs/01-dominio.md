# 01 Domínio e entidades JPA [BACK]

## Objetivo

Criar o modelo de domínio persistente do CampZone: entidades JPA, repositórios e o seed idempotente do plano grátis. Sem endpoints, sem services de negócio e sem motor. É a base para auth (02), motor (03/04) e APIs (05/06).

## Contexto

- Repo `backend/`, branch `feature/01-dominio`, criada **a partir de `feature/00-scaffold`** (a 00 está aprovada, mas ainda sem merge; branches empilhadas por ordem do Antonio).
- ADRs: `0001` (repos separados) e `0002` (perfis de acesso; o `Usuario` entra na **02**, não aqui).
- Schema pelo Hibernate (`ddl-auto=update`). Sem migrations, sem `.sql`. Constraints e índices nas anotações.

## Decisões de modelagem (do orquestrador)

1. **Config do formato como `@Embeddable`** dentro de `Campeonato`, uma por formato (`ConfigPontosCorridosEmbutida`, `ConfigMataMataEmbutida`), e não JSON. Assim não dependemos do mapeamento JSON do Hibernate com Jackson 3 e ganhamos colunas tipadas. Só a do formato do campeonato é preenchida; a outra fica nula. Invariante no domínio: formato `PONTOS_CORRIDOS` exige a config de pontos corridos, e o mesmo vale para `MATA_MATA`. Listas ordenadas (critérios de desempate) em `@ElementCollection` + `@OrderColumn`.
2. **`Confronto` é entidade própria** (além das 8 do backlog). No mata-mata, um confronto agrupa 1..N partidas (jogo único, ida e volta, série melhor de N), tem posição na chave e pode ser bye. Sem ele, ida e volta e série não têm onde morar.
3. **`Resultado` é entidade 1:1 com `Partida`** (a partida existe antes do resultado). Placar com nome genérico, `placarMandante`/`placarVisitante`, porque vale para gols, pontos ou vitórias de xadrez e esports. Desempate opcional: `placarDesempateMandante`/`placarDesempateVisitante` (pênaltis ou equivalente). Campos de prorrogação ou sorteio podem entrar na 04/06 como colunas novas (adicionar coluna não quebra dados).
4. **`@Version`** (lock otimista) em `Campeonato`, `Partida` e `Resultado` desde já, para a 06 não precisar alterar a tabela depois.
5. **Campeonato "ativo"** (para o limite do plano na 05) = status `RASCUNHO` ou `EM_ANDAMENTO`. `FINALIZADO` não conta.
6. **Seed de sorteio** persistida em `Campeonato.seedSorteio` (`Long`, nulo até a geração).
7. **Slug** do campeonato é **único global** (URL pública `/c/{slug}`). A geração do slug fica na 05; aqui é só a coluna com unique.

## Entidades (pacote `br.com.codeacle.campzone.<modulo>.domain`)

Use os módulos do `backend/CLAUDE.md`. Tipos e nomes podem ser refinados, desde que o significado se mantenha. Toda entidade de negócio tem `organizacao_id` (FK) e índice nele.

| Módulo | Entidade | Campos principais |
|---|---|---|
| `plano` | `Plano` (global, sem org) | `id`, `codigo` (único, ex. `GRATIS`), `nome`, `maxCampeonatosAtivos`, `maxParticipantes` |
| `organizacao` | `Organizacao` (o tenant) | `id`, `nome`, `plano` (ManyToOne, obrigatório), `criadoEm` |
| `campeonato` | `Campeonato` | `id`, `organizacao`, `nome`, `modalidade` (texto livre, ex. "Futebol society"), `slug` (único), `formato` (`PONTOS_CORRIDOS`/`MATA_MATA`), `status` (`RASCUNHO`/`EM_ANDAMENTO`/`FINALIZADO`), `publico` (boolean, default false), `configPontosCorridos`, `configMataMata`, `seedSorteio`, `criadoEm`, `version` |
| `campeonato` | `ConfigPontosCorridosEmbutida` | `turnos` (int ≥ 1), `pontosVitoria`/`pontosEmpate`/`pontosDerrota` (default 3/1/0), `permiteEmpate`, `criteriosDesempate` (lista ordenada de enum `CriterioDesempate`: `PONTOS`, `VITORIAS`, `SALDO`, `PRO`, `CONFRONTO_DIRETO`, `SORTEIO`) |
| `campeonato` | `ConfigMataMataEmbutida` | `tipoConfronto` (`JOGO_UNICO`/`IDA_E_VOLTA`/`SERIE`), `melhorDe` (ímpar ≥ 3, só para `SERIE`), `desempates` (lista ordenada de enum `DesempateMataMata`: `GOLS_FORA`, `PRORROGACAO`, `PENALTIS`, `SORTEIO`), `seeding` (`ALEATORIO`/`MANUAL`/`CABECAS_DE_CHAVE`), `disputaTerceiroLugar` |
| `participante` | `Participante` | `id`, `organizacao`, `campeonato`, `nome`, `seed` (Integer, opcional: posição manual ou cabeça de chave). Unique (`campeonato_id`, `nome`) |
| `partida` | `Fase` | `id`, `organizacao`, `campeonato`, `nome` (ex. "Fase única", "Semifinal"), `ordem`, `status`. Unique (`campeonato_id`, `ordem`) |
| `partida` | `Rodada` | `id`, `organizacao`, `fase`, `numero`. Unique (`fase_id`, `numero`) |
| `partida` | `Confronto` | `id`, `organizacao`, `fase`, `posicao` (na chave), `participanteA`, `participanteB` (nulo se bye), `vencedor` (nulo até decidir), `bye` (boolean). Unique (`fase_id`, `posicao`) |
| `partida` | `Partida` | `id`, `organizacao`, `fase`, `rodada` (nulo no mata-mata), `confronto` (nulo nos pontos corridos), `numeroJogo` (1..N dentro do confronto), `mandante`, `visitante`, `status` (`AGENDADA`/`ENCERRADA`), `dataHora` (opcional), `version` |
| `partida` | `Resultado` | `id`, `organizacao`, `partida` (OneToOne, único), `placarMandante`, `placarVisitante` (≥ 0), `placarDesempateMandante`/`placarDesempateVisitante` (opcionais, ≥ 0), `registradoEm`, `version` |

Regras gerais:
- Associações `@ManyToOne(fetch = LAZY)`. Nada de `EAGER`.
- Datas em `Instant` (ou `OffsetDateTime`) e enums com `@Enumerated(STRING)`.
- Construtores/fábricas que garantem invariantes (nome não vazio, `turnos ≥ 1`, placar ≥ 0, `melhorDe` ímpar, config compatível com o formato, mandante ≠ visitante). Setter público só onde fizer sentido. Construtor protegido sem argumentos para o JPA.
- `equals`/`hashCode` seguros para entidade JPA (por id, com cuidado com id nulo) ou não sobrescritos. Nada de Lombok.

## Repositórios

Spring Data, um por agregado principal (`PlanoRepository`, `OrganizacaoRepository`, `CampeonatoRepository`, `ParticipanteRepository`, `FaseRepository`, `RodadaRepository`, `ConfrontoRepository`, `PartidaRepository`, `ResultadoRepository`). Só os métodos que os testes desta tarefa exercitam, mais os óbvios de tenant:
- Para entidades de negócio: `findByIdAndOrganizacaoId`, e listagens filtradas por `organizacaoId` (ex. `findAllByOrganizacaoId`, `findAllByCampeonatoIdAndOrganizacaoId`).
- `PlanoRepository.findByCodigo`, `CampeonatoRepository.findBySlug` (só para a futura página pública; documente isso no Javadoc) e `countByOrganizacaoIdAndStatusIn`.
- Nenhum `findAll()` sem filtro de org exposto para entidade de negócio.

## Seed do plano grátis

`ApplicationRunner` idempotente no módulo `plano` (ex. `PlanoSeeder`): garante que existe o plano `GRATIS` ("Grátis", 1 campeonato ativo, 8 participantes). Rodar duas vezes não duplica e não sobrescreve valores alterados no banco (só cria se não existir). Roda em todos os perfis. Os valores 1 e 8 aparecem **só** aqui.

## Testes

- **Repositórios com Testcontainers** (`@DataJpaTest` com o Postgres do `TestcontainersConfiguration`, ou equivalente no Boot 4): persistir e ler um campeonato de cada formato com sua config (inclusive a ordem dos critérios), participante, fase, rodada, confronto, partida e resultado.
- **Constraints**: slug duplicado e participante com nome duplicado no mesmo campeonato falham. O mesmo nome em campeonatos diferentes pode.
- **Isolamento multi-tenant**: com as orgs A e B, `findByIdAndOrganizacaoId(idDeA, orgB)` vazio, e listagens por org B não trazem nada de A (campeonato, participante, partida).
- **Seed**: rodar o runner duas vezes resulta em um único `GRATIS` com 1/8.
- **Invariantes de domínio**: teste unitário (sem Spring) dos construtores e fábricas: formato sem a config certa, `turnos` 0, placar negativo, mandante = visitante, `melhorDe` par.
- `@ActiveProfiles("dev")` no `contextLoads` (sugestão herdada da 00). Confira que ele vence `SPRING_PROFILES_ACTIVE=prod` exportado; se não vencer, reporte.

## Critérios de aceite

- [ ] Entidades, embeddables, enums e repositórios acima, nos módulos certos.
- [ ] `ddl-auto=update` gera o schema no Postgres 18 sem erro (contextLoads + testes de repositório).
- [ ] Toda entidade de negócio com `organizacao_id` indexado; uniques de slug, participante por campeonato, fase por ordem, rodada por número e confronto por posição.
- [ ] Seed `GRATIS` idempotente; 1 e 8 só no seeder.
- [ ] Testes de isolamento entre duas organizações nos repositórios.
- [ ] `./mvnw verify` verde.
- [ ] Teste manual: subir em `dev` contra o `campzone-postgres` (5433), conferir as tabelas criadas e o plano `GRATIS` (via `docker exec campzone-postgres psql -U campzone -d campzone -c '\dt'`). **Não apague o volume.**

## Contrato da API

Nenhum endpoint nesta tarefa.

## Fora de escopo

`Usuario` e auth (02), services e controllers (05/06), motor (03/04), slug automático (05), `LimitePlanoService` (05), admin (11).
