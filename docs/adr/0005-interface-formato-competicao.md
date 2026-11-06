# ADR 0005: Interface `FormatoCompeticao` do motor

- Data: 2026-11-03
- Status: aceita (orquestrador, antes da tarefa 03; Antonio avisado)

## Contexto

O `backend/CLAUDE.md` define o motor como Java puro, determinístico, com a Strategy `FormatoCompeticao` e duas implementações. Ele pede um ADR para refinar a assinatura antes de implementar. Os dois formatos geram e calculam coisas diferentes:
- **pontos corridos:** todas as rodadas de uma vez, e uma classificação;
- **mata-mata:** chave por fases, e avanço de fase.

## Decisão

1. **Pacotes:** `motor` (interface, tipos comuns e exceções), `motor.pontoscorridos` e `motor.matamata`. O motor importa só `java.*` e o próprio `motor`. Nada de Spring, JPA, `campeonato.domain` ou outro módulo, e um teste garante isso. Por isso o motor tem enums próprios, por exemplo `CriterioDesempate`, e o mapper da camada de aplicação (tarefa 05) traduz os embeddables do JPA para as configs do motor.
2. **Interface genérica por formato:**
   ```java
   public interface FormatoCompeticao<C, E, S> {
       E gerar(C config, List<ParticipanteMotor> participantes, long seedSorteio);
       void validarResultado(C config, ResultadoJogo resultado);
       S calcular(C config, List<ParticipanteMotor> participantes, List<ResultadoJogo> resultados, long seedSorteio);
   }
   ```
   - `C` é a config tipada: `ConfigPontosCorridos` ou `ConfigMataMata`.
   - `E` é a estrutura gerada: `TabelaPontosCorridos` na 03, e o tipo da 04.
   - `S` é o estado calculado: `Classificacao` na 03, e o estado da chave na 04.
   - A camada de aplicação escolhe a implementação pelo formato do campeonato. Não existe "estrutura genérica" para os dois formatos. A 04 pode ajustar a assinatura de `gerar`/`calcular` para o mata-mata, que gera fase a fase, com um adendo a esta ADR. O contrato da 03 não muda por isso.
3. **Tipos comuns em `record`s imutáveis**, com validação no construtor compacto e listas copiadas com `List.copyOf`:
   - `ParticipanteMotor(long id, String nome, Integer seed)`: o `id` é o do banco, e o motor não inventa ids.
   - `ResultadoJogo(long mandanteId, long visitanteId, int placarMandante, int placarVisitante)`.
4. **Erros:** `MotorException` (unchecked, em `motor`), com as subclasses `ConfigInvalidaException`, `ParticipantesInvalidosException` e `ResultadoInvalidoException`. A camada de aplicação as converte em ProblemDetail (400/422) na 05/06.
5. **Determinismo:** mesmas entradas e mesma `seedSorteio` dão a mesma saída, byte a byte.
   - Todo sorteio usa `java.util.Random(seedSorteio)`, cujo algoritmo é fixado pelo Javadoc do JDK e é estável entre versões.
   - Nada de `SecureRandom`, `Math.random`, `HashMap` em ordem de saída ou relógio.
   - A seed é gerada e persistida pela camada de aplicação (`Campeonato.seedSorteio`), não pelo motor.

## Consequências

- O motor é testável em milissegundos, sem contexto Spring.
- Existem dois conjuntos de enums de config (JPA e motor), com tradução explícita no mapper. Um teste na 05 garante que cobrem os mesmos valores.
- Uma regra de competição muda em um só lugar, no motor.

## Adendo A (2026-11-03, antes da tarefa 04)

O mata-mata precisa identificar cada jogo por posição na chave. O mesmo par pode se enfrentar várias vezes com o mesmo mando, numa série. Além disso, a validade de um resultado depende dos outros: um empate no jogo de ida vale, mas no jogo decisivo não.

1. **Tipo do resultado vira parâmetro:** `FormatoCompeticao<C, E, R, S>`.
   - `void validarResultado(C config, R resultado)` faz só as checagens que não dependem de outros resultados.
   - `S calcular(C config, List<ParticipanteMotor> participantes, List<R> resultados, long seedSorteio)` valida cada resultado no contexto e lança `ResultadoInvalidoException`.
   - No pontos corridos, `R` = `ResultadoJogo` e nada muda no comportamento.
   - Para validar um resultado novo do mata-mata, a camada de aplicação chama `calcular` com ele incluído.
2. **Mata-mata como função pura do estado:** `gerar(config, participantes, seed)` equivale a `calcular(config, participantes, [], seed)`. O motor não guarda nem "avança" nada. Quem está em cada vaga, o vencedor de cada confronto e quais jogos estão abertos são sempre recalculados a partir dos resultados. A camada de aplicação (05/06) persiste as partidas que ficam pendentes.
3. **Sorteio por confronto:** `new Random(splitMix64(seedSorteio + 1_000_003L * ordemFase + posicao)).nextBoolean()`, onde `true` significa vitória do participante A. É reprodutível e independente da ordem dos resultados.
   - `splitMix64` é o finalizador de 64 bits padrão do SplitMix64:
     ```
     z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9L
     z = (z ^ (z >>> 27)) * 0x94D049BB133111EBL
     z ^ (z >>> 31)
     ```
   - *Correção da revisão da 04:* sem esse finalizador, sementes vizinhas dão quase sempre o mesmo primeiro `nextBoolean` do LCG. Confrontos da mesma fase coincidiam em 99,9% dos casos, contra 50% esperado.
