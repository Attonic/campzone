# 04 Motor: mata-mata [BACK]

## Objetivo

Implementar o formato mata-mata (eliminatória simples) no motor:
- chave com byes e seeding;
- confrontos em jogo único, ida e volta ou série melhor de N;
- desempates configuráveis;
- disputa de 3º lugar;
- avanço de fase.

Tudo em Java puro, sem persistência e sem endpoints.

## Contexto

- Repo `backend/`, branch `feature/04-motor-mata-mata`, criada **a partir de `feature/03-motor-pontos-corridos`** (branches empilhadas).
- Leia o **ADR 0005 com o Adendo A**: o tipo do resultado vira parâmetro, `gerar` equivale a `calcular` sem resultados e o sorteio é feito por confronto. Leia também a seção "Motor de competição" do `backend/CLAUDE.md`.
- Ajuste o `PontosCorridosFormato` à nova assinatura (`R = ResultadoJogo`) sem mudar o comportamento. Os testes da 03 continuam passando sem alteração de asserções.

## Tipos (em `motor.matamata`)

### Config

`ConfigMataMata(TipoConfronto tipoConfronto, Integer melhorDe, List<DesempateMataMata> desempates, Seeding seeding, boolean disputaTerceiroLugar)`. Lança `ConfigInvalidaException` quando:
- `melhorDe` é informado fora de `SERIE`, ou com `SERIE` não é ímpar ≥ 3;
- `desempates` vem vazio ou com repetição;
- `GOLS_FORA` aparece sem `IDA_E_VOLTA`;
- a lista não termina num critério terminal (`PENALTIS` ou `SORTEIO`), ou tem algum critério depois do primeiro terminal. Sem terminal, um empate seria impossível de lançar; um critério depois dele nunca seria usado;
- `SORTEIO` aparece com `SERIE`. Sorteio por jogo de série não faz sentido em campeonato.

### Enums do motor

- `TipoConfronto`: `JOGO_UNICO`, `IDA_E_VOLTA`, `SERIE`.
- `DesempateMataMata`: `GOLS_FORA`, `PRORROGACAO`, `PENALTIS`, `SORTEIO`.
- `Seeding`: `ALEATORIO`, `MANUAL`, `CABECAS_DE_CHAVE`.
- `TipoFase`: `ELIMINATORIA`, `TERCEIRO_LUGAR`, `FINAL`.
- `SituacaoJogo`: `AGUARDANDO_PARTICIPANTES`, `PENDENTE`, `DISPUTADO`, `DESNECESSARIO`.

### Resultado

`ResultadoMataMata(int ordemFase, int posicao, int numeroJogo, int placarMandante, int placarVisitante, Integer prorrogacaoMandante, Integer prorrogacaoVisitante, Integer penaltisMandante, Integer penaltisVisitante)`:
- Chave: `(ordemFase, posicao, numeroJogo)`.
- O placar segue o mandante e o visitante **daquele jogo**.
- Os pares de prorrogação e de pênaltis vêm os dois ou nenhum.
- Nenhum valor pode ser negativo.

### Estado

O estado é o mesmo tipo para `E` e `S`:
- `EstadoMataMata(List<FaseEstado> fases, Long campeaoId, Long viceId, Long terceiroId)`
- `FaseEstado(int ordem, String nome, TipoFase tipo, List<ConfrontoEstado> confrontos)`
- `ConfrontoEstado(int posicao, Long participanteAId, Long participanteBId, boolean bye, Long vencedorId, List<JogoEstado> jogos)`
- `JogoEstado(int numeroJogo, Long mandanteId, Long visitanteId, SituacaoJogo situacao)`

O formato é `MataMataFormato implements FormatoCompeticao<ConfigMataMata, EstadoMataMata, ResultadoMataMata, EstadoMataMata>`.

## Regras

### Chave e seeding

- O tamanho da chave `P` é a menor potência de 2 ≥ n, com n ≥ 2. Há `P − n` byes.
- Os participantes recebem seeds de 1 a n:
  - `ALEATORIO`: ignora `ParticipanteMotor.seed`. A ordem é dada pelos ids ordenados, embaralhados com `Random(seedSorteio)`, e o 1º da ordem recebe a seed 1.
  - `MANUAL`: todos os participantes trazem `seed` única, de 1 a n. Senão, `ParticipantesInvalidosException`.
  - `CABECAS_DE_CHAVE`: os que trazem `seed` formam o conjunto contíguo 1..k (k ≥ 0, únicas). Os demais recebem k+1..n na ordem do `Random(seedSorteio)`, aplicado aos ids sem seed, ordenados.
- Posições da 1ª fase pela **ordem clássica**, gerada recursivamente: para P=8, os confrontos são `1×8, 4×5, 2×7, 3×6`.
  - A seed 1 e a seed 2 só podem se encontrar na final. Em geral, as `P/2^j` melhores seeds ficam em blocos diferentes da chave.
  - Seed > n é bye. Assim, os byes caem para as melhores seeds.
- No `ConfrontoEstado`, `participanteA` é sempre a melhor seed (menor número).
  - No bye, `participanteB` é nulo e não há jogos.
  - Um confronto de bye já nasce com `vencedorId = A`.

### Fases

- Fases eliminatórias com ordem de 1 a k, onde k = log2(P). A última é a `FINAL` ("Final").
- Nomes pela quantidade de confrontos:
  - 2: "Semifinal";
  - 4: "Quartas de final";
  - 8: "Oitavas de final";
  - outros: "Fase de {2×confrontos}" (ex.: "Fase de 32").
- Com `disputaTerceiroLugar` e **dois** perdedores reais de semifinal:
  - há uma fase `TERCEIRO_LUGAR` ("Disputa de 3º lugar") com ordem k;
  - a Final passa a ter ordem k+1;
  - o confronto da disputa tem posição 1: o perdedor da semifinal 1 contra o da semifinal 2.
- Se a semifinal tem um bye (ex.: n = 3), a disputa não é gerada e `terceiroId` fica nulo.
- Vencedor do confronto de posição p da fase f vai para a posição `ceil(p/2)` da próxima fase eliminatória. O de posição ímpar ocupa a vaga A e o de posição par a vaga B. Depois, A e B são reordenados pela seed para que A seja sempre a melhor seed.
- **Avanço de fase:** os confrontos de uma fase só recebem participantes quando **todos** os confrontos da fase anterior têm vencedor. Antes disso, seus jogos ficam como `AGUARDANDO_PARTICIPANTES`. A disputa de 3º e a Final abrem juntas, quando as semifinais fecham.
- O pódio é preenchido ao decidir a Final (`campeaoId` e `viceId`) e a disputa de 3º (`terceiroId`).

### Jogos do confronto e mando

- `JOGO_UNICO`: 1 jogo, com A como mandante.
- `IDA_E_VOLTA`: jogo 1 com B como mandante e jogo 2 com A como mandante. A melhor seed decide em casa.
- `SERIE`: `melhorDe` jogos, alternando o mando a partir de A.
  - Quem chega a `(melhorDe+1)/2` vitórias vence.
  - Os jogos restantes ficam `DESNECESSARIO`.

### Decisão e desempates

Os critérios de desempate valem na ordem configurada, **só quando necessário**. Para cada tipo de confronto:

- **`JOGO_UNICO`:** o placar decide. Se empatar, aplica os desempates.
- **`IDA_E_VOLTA`:** decide o agregado dos dois jogos. Se o agregado empatar, aplica os desempates, nesta ordem:
  - `GOLS_FORA`: gols marcados como visitante, no tempo normal;
  - `PRORROGACAO` e `PENALTIS`: informados no jogo 2.
- **`SERIE`:** cada jogo precisa ter vencedor. Um jogo empatado aplica `PRORROGACAO`/`PENALTIS` daquele jogo, na ordem configurada. Se o próximo critério configurado for `GOLS_FORA`, ele é pulado, porque não se aplica.

O que cada critério faz:

- **`PRORROGACAO`:** vence quem marcou mais na prorrogação. Se ela empatar, passa ao próximo critério.
- **`PENALTIS`:** vence quem fez mais pênaltis. Pênaltis empatados tornam o resultado inválido.
- **`SORTEIO`:** usa a fórmula do Adendo A. Não precisa de dados no resultado.

### Validação de resultado (no contexto do `calcular`)

O `calcular` lança `ResultadoInvalidoException`, com uma mensagem clara, nestes casos:

- **Jogo que não aceita resultado:**
  - o jogo não existe;
  - o jogo está `AGUARDANDO_PARTICIPANTES` ou `DESNECESSARIO`;
  - o jogo recebeu um resultado duplicado.
- **Dados de desempate errados:**
  - vieram prorrogação ou pênaltis num jogo que não precisa deles, ou cujo critério não está na config;
  - num jogo decisivo empatado, faltam os dados do próximo critério que exige dados, e esse critério não é `SORTEIO`.

  Exemplo: config `PRORROGACAO, PENALTIS`, jogo único 1×1 sem prorrogação. O resultado é inválido, com a mensagem "informe a prorrogação".

- **Ordem de lançamento:** os jogos de um confronto são lançados em ordem. A volta só aceita resultado depois da ida, e o jogo N da série só depois dos jogos 1..N−1. Enquanto isso, o jogo fica `PENDENTE` e o resultado antecipado é inválido. A ordem da lista de resultados continua não importando.

O `validarResultado(config, r)`, sem contexto, checa só:
- prorrogação ou pênaltis informados quando o critério correspondente não está na config;
- pênaltis empatados.

## Qualidade

- Os mesmos padrões da 03:
  - records imutáveis;
  - Javadoc em português;
  - determinismo;
  - JaCoCo ≥ 90% no `motor`, mantendo a regra atual.

**Herdado da revisão da 03 (fazer junto):**
1. Mover os `@throws` do Javadoc de classe para o construtor compacto, em `ParticipanteMotor`, `ResultadoJogo` e `ConfigPontosCorridos`.
2. `ArquiteturaMotorTest`:
   - pegar `new Random()` sem seed e `shuffle(lista)` sem `Random`;
   - recusar `java.io.`, `java.nio.file.`, `java.net.` e `java.sql.`;
   - incluir a raiz `tools` nos nomes qualificados.
3. `ValidacaoFormatoTest.recusaPlacarNegativoEMandanteIgualAoVisitante`: o teste passa pelo construtor e não pelo `validarResultado`. Renomeie-o ou remova-o, deixando uma referência ao `ResultadoJogoTest`.
4. Teste paramétrico que trava `n−2` quebras de mando na virada entre turnos.

## Testes obrigatórios (JUnit 5 + AssertJ, sem Spring)

- **Chave** com 2, 3, 4, 5, 8, 11 e 16 participantes:
  - P, byes e fases (quantidade, nomes, ordem);
  - byes para as melhores seeds;
  - ordem clássica: 1 e 2 em metades opostas, só se cruzam na final;
  - A é sempre a melhor seed;
  - mesma seed dá o mesmo sorteio, e a ordem de entrada não importa.
- **Seeding:**
  - `ALEATORIO` ignora a seed informada;
  - `MANUAL` válido e inválido (faltando, repetida, fora de 1..n);
  - `CABECAS_DE_CHAVE` com k = 0, 2 e n, e com k não contíguo (inválido).
- **Confronto:**
  - jogo único, ida e volta e série (melhor de 3 e de 5, com jogos `DESNECESSARIO`);
  - mando de cada tipo.
- **Desempates:**
  - cada critério isolado: gols fora, prorrogação, pênaltis e sorteio reprodutível;
  - combinações: gols fora empatado indo para prorrogação e depois pênaltis; prorrogação empatada indo para sorteio;
  - todos os casos de resultado inválido da lista acima.
- **Avanço:**
  - a fase seguinte só abre com a anterior completa;
  - os vencedores caem nas posições certas;
  - disputa de 3º com e sem config, e com n = 3 (não gerada);
  - pódio completo.
- **Torneios completos** (8 e 11 participantes, com e sem 3º lugar) lançando todos os resultados até o campeão.
- **Propriedades:**
  - `gerar` é igual a `calcular` sem resultados;
  - a ordem da lista de resultados não muda o estado;
  - ninguém aparece duas vezes na mesma fase.
- **Pontos corridos:** a suíte da 03 continua verde, mais os 4 itens herdados.

## Critérios de aceite

- [ ] Tipos e regras acima, conforme o ADR 0005 e o Adendo A.
- [ ] `./mvnw verify` verde, com JaCoCo ≥ 90% no `motor`.
- [ ] Relatório com:
  - a cobertura;
  - o estado gerado para 5 participantes (`CABECAS_DE_CHAVE` com k = 2);
  - um torneio de 4 participantes, ida e volta, resolvido até o pódio;
  - as decisões tomadas onde a spec foi ambígua.

## Revisão 1 do orquestrador (2026-11-03)

- Sorteio com SplitMix64 (ADR 0005 Adendo A, item 3 corrigido).
- `SORTEIO` proibido em `SERIE`.
- O critério terminal tem de ser o último.
- Lançamento em ordem dentro do confronto.
- Mantida a barreira de fase total, que é a regra do `backend/CLAUDE.md` ("avanço de fase automático ao fechar todos os confrontos da fase"). Avançar confronto a confronto fica como pergunta ao Antonio.

## Contrato da API

Nenhum endpoint nesta tarefa.

## Fora de escopo

Persistência, tradução do JPA para o motor e endpoints (05/06); eliminatória dupla, grupos, repescagem; gols fora na prorrogação; critérios além dos 4 listados.
