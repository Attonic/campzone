# 06 API de partidas e resultados [BACK]

## Objetivo

Permitir que o organizador conduza o campeonato até o fim: ver a tabela ou a chave, lançar, corrigir e remover resultados, acompanhar a classificação, avançar as fases do mata-mata e finalizar.

## Contexto

- Repo `backend/`, branch `feature/06-api-partidas-resultados`, criada **a partir de `feature/05-api-campeonatos`** (branches empilhadas, sem merge até o Antonio testar na tarefa 10).
- Leia: `backend/CLAUDE.md`, ADR 0003, 0005 (Adendo A), 0007 e **0008**, `docs/specs/04-motor-mata-mata.md` e `docs/specs/05-api-campeonatos.md`.
- Todas as rotas exigem `ORGANIZADOR`, com `organizacaoId` só do JWT. Recurso de outra organização responde 404, igual a um inexistente. Partida de outro campeonato também dá 404.
- A página pública (09) vai ler os mesmos dados. Mantenha a montagem de tabela, classificação e chave em service reutilizável, sem depender do JWT dentro da montagem.

## Contrato da API

Base: `/api/v1/campeonatos/{id}`. Erros em ProblemDetail.

| Método e rota | Entrada | Sucesso | Erros |
|---|---|---|---|
| `GET /tabela` | | 200 `TabelaResponse` | 404, 409 |
| `GET /classificacao` | | 200 `ClassificacaoResponse` | 404, 409 |
| `GET /chave` | | 200 `ChaveResponse` | 404, 409 |
| `PUT /partidas/{partidaId}/resultado` | `LancarResultadoRequest` | 200 `PartidaResponse` | 400, 404, 409, 422 |
| `DELETE /partidas/{partidaId}/resultado` | | 200 `PartidaResponse` | 404, 409 |
| `POST /finalizar` | sem corpo | 200 `CampeonatoResponse` | 404, 409 |

Regras de 409 das leituras:
- `/tabela` e `/classificacao` só valem para `PONTOS_CORRIDOS`, e `/chave` só para `MATA_MATA`. Formato errado dá 409.
- Campeonato em `RASCUNHO` dá 409 ("ainda não foi gerado").
- `FINALIZADO` continua legível.

`ParticipanteResumoResponse`: `id` (number), `nome` (string).

`LancarResultadoRequest`:

| campo | tipo | regra |
|---|---|---|
| `placarMandante`, `placarVisitante` | number | obrigatórios, 0..9999 |
| `prorrogacaoMandante`, `prorrogacaoVisitante` | number \| null | 0..9999, os dois ou nenhum |
| `penaltisMandante`, `penaltisVisitante` | number \| null | 0..9999, os dois ou nenhum |
| `versao` | number \| null | versão do resultado sendo corrigido (veja "Lançar e corrigir") |

`ResultadoResponse`: `placarMandante`, `placarVisitante`, `prorrogacaoMandante`, `prorrogacaoVisitante`, `penaltisMandante`, `penaltisVisitante` (os quatro últimos number \| null), `registradoEm` (string), `versao` (number).

`PartidaResponse`:

| campo | tipo |
|---|---|
| `id` | number |
| `numeroJogo` | number |
| `mandante`, `visitante` | `ParticipanteResumoResponse` |
| `status` | `"AGENDADA"` \| `"ENCERRADA"` \| `"DESNECESSARIA"` |
| `aceitaResultado` | boolean: o jogo pode receber resultado agora |
| `resultado` | `ResultadoResponse` \| null |

`TabelaResponse`: `rodadas: RodadaResponse[]`, ordenadas por `numero`.

`RodadaResponse`: `numero` (number), `turno` (number), `folga` (`ParticipanteResumoResponse` \| null), `partidas: PartidaResponse[]`.

`ClassificacaoResponse`: `linhas: LinhaClassificacaoResponse[]`, com `posicao`, `participante` (`ParticipanteResumoResponse`), `pontos`, `jogos`, `vitorias`, `empates`, `derrotas`, `golsPro`, `golsContra`, `saldo` (todos number, exceto `participante`).

`ChaveResponse`:

| campo | tipo |
|---|---|
| `fases` | `FaseChaveResponse[]`, por `ordem` |
| `campeao`, `vice`, `terceiro` | `ParticipanteResumoResponse` \| null |

`FaseChaveResponse`: `ordem` (number), `nome` (string), `tipo` (`"ELIMINATORIA"`\|`"TERCEIRO_LUGAR"`\|`"FINAL"`), `confrontos: ConfrontoChaveResponse[]`, por `posicao`. Inclui as fases que ainda não abriram.

`ConfrontoChaveResponse`: `posicao` (number), `participanteA`, `participanteB`, `vencedor` (`ParticipanteResumoResponse` \| null), `bye` (boolean), `jogos: JogoChaveResponse[]`.

`JogoChaveResponse`:

| campo | tipo |
|---|---|
| `numeroJogo` | number |
| `situacao` | `"AGUARDANDO_PARTICIPANTES"`\|`"PENDENTE"`\|`"DISPUTADO"`\|`"DESNECESSARIO"` |
| `partida` | `PartidaResponse` \| null (nula enquanto `AGUARDANDO_PARTICIPANTES`) |

A seed do sorteio continua fora de toda resposta e de todo log.

## Regras

### Persistência

- `Resultado` ganha `prorrogacao_mandante` e `prorrogacao_visitante`, anuláveis (ADR 0003). Os pênaltis usam as colunas existentes `placar_desempate_*`. No domínio, ofereça nomes claros.
- `StatusPartida` ganha `DESNECESSARIA` (coluna é texto, sem CHECK). A partida ganha as transições necessárias de ida e volta.
- `Fase` e `Confronto` ganham o caminho de volta (`reabrir`, limpar vencedor) porque correções podem desfazer uma decisão.
- A chave persistida é projeção do estado do motor (ADR 0008).

### Lançar e corrigir (`PUT /resultado`)

Numa transação, travando a linha do campeonato (ADR 0007):

1. Campeonato fora de `EM_ANDAMENTO`: 409. Partida `DESNECESSARIA`: 409.
2. **Idempotência:** se já há resultado com os mesmos valores, responde 200 sem alterar nada, qualquer que seja a `versao`.
3. **Correção segura:** se já há resultado com valores diferentes, a `versao` é obrigatória e precisa bater com a atual. Faltando ou divergindo: 409 ("resultado alterado por outra pessoa, recarregue"). Sem resultado anterior, a `versao` é ignorada.
4. **Validação pelo motor**, com o resultado novo incluído na lista:
   - Pontos corridos: dados de prorrogação ou pênaltis são 422 (o formato não os usa). Empate proibido é 422.
   - Mata-mata: `calcular` valida no contexto. `ResultadoInvalidoException` é 422 com a mensagem do motor, e nada é gravado.
5. **Reconciliação** (ADR 0008) e resposta com a `PartidaResponse` atualizada.

### Remover (`DELETE /resultado`)

Mesma trava e mesmas regras de status. Sem resultado: 409. A partida volta a `AGENDADA` e a chave é reconciliada. No mata-mata, remover um jogo com jogo posterior do mesmo confronto já lançado dá 422, pela ordem de lançamento do motor.

### Dependência entre fases (mata-mata)

Corrigir ou remover um resultado é **recusado com 409** ("remova antes os resultados da fase seguinte") se a alteração mudaria quem disputa um jogo de fase posterior que já tem resultado. A correção que mantém o vencedor (ex.: 2x0 vira 3x0) é permitida mesmo com a fase seguinte em andamento.

**Atenção:** o motor identifica o resultado pela posição, então aceitaria o resultado antigo com os participantes novos. O service precisa comparar mandante e visitante persistidos com os do estado novo. Teste esse caso especificamente.

### Reconciliação da chave (mata-mata)

Depois de cada alteração, o estado persistido fica igual ao do motor:

- **Vencedor:** define ou limpa `Confronto.vencedor`.
- **Série:** os jogos que o motor marca `DESNECESSARIO` viram `DESNECESSARIA`, e voltam a `AGENDADA` se a correção reabrir a série. Seus resultados não existem, porque o motor recusa.
- **Fase que abre:** cria `Fase`, `Confronto`s e `Partida`s quando o motor dá participantes a ela. A disputa de 3º e a Final abrem juntas.
- **Fase que deixa de valer:** sem resultados, é apagada e recriada quando abrir de novo. Os participantes mudam de verdade.
- **Status da `Fase`:** `ENCERRADA` com todos os confrontos decididos; volta a `EM_ANDAMENTO` se uma correção reabrir.

`aceitaResultado` é `true` quando o campeonato está `EM_ANDAMENTO`, a partida não é `DESNECESSARIA` e, no mata-mata, todos os jogos anteriores do confronto têm resultado. Vale também para partida já com resultado, porque corrigir é lançar de novo.

### Tabela e classificação (pontos corridos)

- `turno` calculado de `numero` e da config. `folga` é quem do campeonato não joga na rodada (só com n ímpar).
- Classificação sempre recalculada pelo motor, com a `seedSorteio` e os resultados persistidos. Não há cache.

### Finalizar (`POST /finalizar`)

- Só em `EM_ANDAMENTO`, com trava. Senão, 409.
- **Permitido com jogos em aberto**, de propósito: no plano grátis, gerar é irreversível e finalizar é o único jeito de liberar a vaga depois de um engano. A confirmação fica na tela (tarefa 08).
- Encerra as fases em aberto. Campeonato `FINALIZADO` não aceita mais nenhuma alteração de resultado, e isso libera a vaga do plano.
- Não existe finalização automática nem reabertura, para o organizador poder corrigir até decidir encerrar.

### Sem N+1

Tabela e chave carregam tudo com número fixo de consultas (`fetch join` ou `@EntityGraph`), com teste de quantidade de consultas variando o número de participantes, no padrão do `AdminIntegracaoTest`.

## Testes obrigatórios

- **Isolamento e papéis (todas as rotas):** org B recebe 404; partida de outro campeonato da mesma org, 404; sem token, 401; admin, 403.
- **Pontos corridos:**
  - lançar, corrigir e remover refletem na classificação;
  - idempotência (mesmo PUT duas vezes não muda `versao` nem `registradoEm`);
  - `versao` faltando e divergente dão 409;
  - empate proibido e dados de desempate dão 422;
  - turno e folga com n ímpar;
  - campeonato completo com critério `SORTEIO`: classificação igual à do motor.
- **Mata-mata, com a API real do início ao fim:**
  - torneios completos (4 com 3º lugar, 5 com byes, 8) nos três tipos de confronto, até `campeao`, `vice` e `terceiro`;
  - resultado antecipado (volta antes da ida), jogo sem participantes e dados de desempate faltando ou sobrando dão 422 sem gravar;
  - fase seguinte só abre com a anterior completa;
  - série: jogos `DESNECESSARIA`, e reabertura ao corrigir;
  - **correções:** que mantêm o vencedor; que trocam o vencedor com a fase seguinte sem resultados (fase refeita com os participantes novos); que trocam o vencedor com a fase seguinte já com resultado (409, nada muda); nas semifinais, com reflexo na disputa de 3º e na Final;
  - remover e relançar.
- **Concorrência (Postgres real):**
  - lançamentos simultâneos na mesma partida: um grava e os outros são idempotentes ou 409;
  - os dois últimos jogos de uma fase ao mesmo tempo: a fase seguinte é criada uma única vez;
  - lançar contra finalizar.
- **Finalizar:** libera a vaga do plano (criar outro campeonato passa); bloqueia alterações de resultado; leituras continuam.
- **Seed:** ausente de todas as respostas novas e do log.
- `Impl` com Mockito, controller com web test mockando a interface, repositórios com Testcontainers. Texto novo em `Request`: nenhum, mas a guarda `TextoValidoEmTodaEntradaTest` precisa continuar verde.

## Critérios de aceite

- [ ] Contrato acima exatamente.
- [ ] Isolamento multi-tenant testado em todas as rotas.
- [ ] Estado persistido sempre igual ao do motor depois de qualquer lançamento, correção ou remoção. Prove com uma checagem de invariante reutilizada nos testes de torneio.
- [ ] `./mvnw clean verify` verde.
- [ ] Teste manual com `curl`, contra Postgres descartável (porta 55442): um campeonato de cada formato até o fim, com uma correção no meio. Inclua os JSONs reais no relatório.

## Fora de escopo

Agendar data e hora das partidas, reabrir campeonato finalizado, desfazer a geração, histórico de correções, página pública (09), telas (07b, 08).
