# 03 Motor: pontos corridos [BACK]

## Objetivo

Implementar o formato pontos corridos no motor: geração da tabela round-robin e cálculo da classificação com desempates configuráveis. Java puro, sem persistência e sem endpoints.

## Contexto

- Repo `backend/`, branch `feature/03-motor-pontos-corridos`, criada **a partir de `feature/11-admin`** (branches empilhadas).
- Leia o **ADR 0005** (interface, pacotes, tipos comuns, exceções e determinismo). Leia também a seção "Motor de competição" do `backend/CLAUDE.md`.
- Persistência (Fase/Rodada/Partida), API e tradução dos embeddables do JPA ficam na 05/06. Aqui o motor é testado isolado.

## Tipos (em `motor` e `motor.pontoscorridos`)

- `ConfigPontosCorridos(int turnos, int pontosVitoria, int pontosEmpate, int pontosDerrota, boolean permiteEmpate, List<CriterioDesempate> criterios)`, com `ConfigInvalidaException` quando:
  - `turnos < 1`;
  - os pontos não respeitam `vitoria > derrota` e `vitoria ≥ empate ≥ derrota`;
  - os critérios vêm vazios ou repetidos;
  - **`PONTOS` não é o primeiro** critério (decisão do orquestrador: pontos corridos sempre ordena por pontos primeiro);
  - `SORTEIO` aparece em posição que não é a última.

  Ofereça também uma fábrica `padrao(turnos)`: 3/1/0, empate permitido, critérios `PONTOS, VITORIAS, SALDO, PRO, CONFRONTO_DIRETO, SORTEIO`.
- `CriterioDesempate` (enum do motor): `PONTOS`, `VITORIAS`, `SALDO`, `PRO`, `CONFRONTO_DIRETO`, `SORTEIO`.
- `TabelaPontosCorridos(List<RodadaGerada> rodadas)`:
  - `RodadaGerada(int numero, int turno, List<JogoGerado> jogos, Long folgaId)`, com `folgaId` nulo quando ninguém folga;
  - `JogoGerado(long mandanteId, long visitanteId)`.
- `Classificacao(List<LinhaClassificacao> linhas)`, com `LinhaClassificacao(int posicao, long participanteId, int pontos, int jogos, int vitorias, int empates, int derrotas, int golsPro, int golsContra, int saldo)`. "Gols" é o nome genérico do placar (ponto ou partida em outras modalidades).
- `PontosCorridosFormato implements FormatoCompeticao<ConfigPontosCorridos, TabelaPontosCorridos, Classificacao>`.

## Regras

### Participantes (`gerar` e `calcular`)

Pelo menos 2, ids únicos e nome não vazio. Caso contrário, `ParticipantesInvalidosException`. O limite máximo é do plano (05), não do motor.

### Geração (`gerar`)

- **Método do círculo:**
  - ordene os participantes por `id` e embaralhe com `Random(seedSorteio)` para sortear a ordem da tabela, que fica reprodutível;
  - com n ímpar, inclua uma folga (bye), que vira `folgaId` na rodada e **nunca** um jogo fantasma;
  - um turno tem `n−1` rodadas (n par) ou `n` rodadas (n ímpar), e cada participante enfrenta cada outro exatamente uma vez por turno.
- **Mando:**
  - em cada turno, o número de jogos como mandante de cada participante difere em no máximo 1 do número como visitante;
  - minimize sequências do mesmo mando: para n par, as quebras (mesmo mando em duas rodadas seguidas dentro do turno) somam no máximo `n−2` por turno, que é o mínimo teórico;
  - para n ímpar, meça o total de quebras (ignorando a rodada de folga), registre o valor no relatório e trave-o no teste de propriedade.
- **Turnos:** o turno 2 repete a ordem das rodadas do turno 1 com o mando invertido. O turno 3 repete o 1, o 4 repete o 2, e assim por diante. Com 2 turnos, cada par se enfrenta uma vez em cada mando.
- **Numeração:** as rodadas são numeradas de 1 até o total, contínuas entre os turnos.
- **Determinismo:** a mesma lista de participantes, em qualquer ordem de entrada, com a mesma seed e a mesma config, gera a mesma tabela.

### Validação de resultado (`validarResultado`)

- Placar negativo e mandante igual ao visitante dão `ResultadoInvalidoException`.
- Com `permiteEmpate = false`, um empate também dá `ResultadoInvalidoException`, com mensagem clara.

### Classificação (`calcular`)

- `resultados` traz só os jogos já disputados, que são validados um a um (como em `validarResultado`). Participante desconhecido no jogo dá `ResultadoInvalidoException`.
- Todo participante aparece, inclusive quem tem 0 jogos.
- Pontos pela config, mais as contagens (jogos, V/E/D, pró, contra, saldo).
- **Ordenação pelos critérios, na ordem configurada:**
  - `PONTOS`, `VITORIAS`, `SALDO` e `PRO` são decrescentes.
  - `CONFRONTO_DIRETO`: pontos obtidos **só nos jogos entre os participantes do grupo empatado naquele momento** (mini-tabela), com a pontuação da config. Se separar o grupo parcialmente, cada subgrupo que continuar empatado segue para o próximo critério, e o confronto direto não é reaplicado.
  - `SORTEIO`: posição na ordem do `Random(seedSorteio)`, a mesma ordem embaralhada da geração. É estável e auditável.
- **Empate que sobrevive a todos os critérios** (sem `SORTEIO`): os participantes empatados dividem a mesma `posicao` (ex.: 1, 2, 2, 4) e aparecem em ordem de `id`.

## Qualidade

- Pacote `motor` sem dependência fora de `java.*`/`motor`, garantido por teste (varredura dos imports das fontes ou equivalente, sem dependência nova de produção).
- **JaCoCo** no `pom.xml`, com regra de cobertura de linhas e ramos **≥ 90% no pacote `motor`** que faz o `verify` falhar abaixo disso. O relatório não deve cobrir os outros pacotes nessa regra.
- Javadoc curto em português nas classes públicas do motor.

## Testes obrigatórios (JUnit 5 + AssertJ, sem Spring)

- **Geração** com 2, 3, 4, 5, 8 e 9 participantes, em turno único e ida e volta (e um caso de 3 turnos):
  - quantidade de rodadas e jogos;
  - todos enfrentam todos exatamente uma vez por turno, sem confronto repetido no turno;
  - folga única por rodada quando n é ímpar e cada um folga uma vez por turno;
  - nenhum participante em dois jogos na mesma rodada;
  - mando equilibrado e limite de quebras;
  - ida e volta inverte o mando;
  - mesma seed dá mesma tabela, e a ordem de entrada não importa;
  - seeds diferentes podem dar tabelas diferentes.
- **Classificação:**
  - cada critério isolado decide um empate;
  - combinações (ex.: `PONTOS, CONFRONTO_DIRETO, SALDO` contra `PONTOS, SALDO, CONFRONTO_DIRETO`, dando resultados diferentes);
  - confronto direto com 3 empatados que separa parcialmente;
  - `SORTEIO` reprodutível;
  - empate total com posição dividida;
  - pontuação customizada (ex.: 2/1/0 e derrota −1);
  - 0 jogos.
- **Validação:**
  - config inválida (cada regra);
  - participantes inválidos;
  - resultado inválido (placar negativo, empate proibido, participante desconhecido).
- **Arquitetura:** o teste de dependências do pacote `motor`.

## Critérios de aceite

- [ ] Tipos e regras acima, conforme o ADR 0005.
- [ ] `./mvnw verify` verde, com a regra do JaCoCo ativa (≥ 90% no `motor`).
- [ ] Relatório com a cobertura atingida e o número de quebras de mando para n ímpar.

## Contrato da API

Nenhum endpoint nesta tarefa.

## Fora de escopo

Mata-mata (04), persistência, tradução do JPA para o motor e endpoints (05/06), confronto direto recursivo, critérios além dos 6 listados.
