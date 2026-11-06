# ADR 0008: Chave persistida como projeção do motor

- Data: 2026-11-06
- Status: aceita (orquestrador, antes da tarefa 06; Antonio avisado)

## Contexto

O motor calcula a chave inteira a partir dos resultados (ADR 0005, Adendo A) e não guarda nada. O banco, porém, precisa ter `Fase`, `Confronto` e `Partida`, porque os resultados se ligam a uma partida e a API precisa de ids.

Com correções de resultado, há duas fontes do mesmo fato: o que o motor calcula e o que está gravado. Avançar a fase com código próprio no service duplicaria as regras do motor e deixaria as duas fontes divergirem.

## Decisão

- **Os resultados são a fonte da verdade, e o motor é o único que decide.** Vencedor, quem disputa cada vaga e quais jogos estão abertos nunca são calculados fora dele.
- **Fase, confronto e partida persistidos são uma projeção.** Depois de cada lançamento, correção ou remoção, um passo único de reconciliação compara o estado do motor com o banco e aplica a diferença.
- **A leitura da chave também vem do motor**, juntando os ids das partidas persistidas.
- **O motor identifica o resultado pela posição.** Por isso, antes de aceitar uma correção, o service compara os participantes persistidos dos jogos com resultado com os do estado novo. Se uma correção trocaria quem disputou um jogo já lançado, ela é recusada com 409, e o organizador remove antes os resultados da fase seguinte.
- A operação inteira roda sob a trava do campeonato (ADR 0007).

## Consequências

- Uma regra de competição muda só no motor, e corrigir resultado não precisa de caminho próprio.
- Cada alteração recalcula a chave inteira. No limite de tamanho do MVP, o custo é desprezível.
- Uma fase que deixa de valer é apagada e recriada, então seus ids mudam. Só acontece com fase sem resultados, e a API não promete id estável nesse caso.
- Remover resultados de uma fase para corrigir a anterior dá trabalho ao organizador, de propósito: resultado lançado nunca muda de participantes em silêncio.
