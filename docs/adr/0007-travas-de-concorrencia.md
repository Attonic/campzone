# ADR 0007: Travas de concorrência na API de campeonatos

- Data: 2026-11-06
- Status: aceita (orquestrador, tarefa 05; Antonio avisado)

## Contexto

Os limites do plano e a geração são "ler e depois escrever": contar quantos existem e só então criar. Com requisições simultâneas, duas podem ler o mesmo número e furar o limite, ou gerar a tabela duas vezes. O lock otimista (`@Version`) não resolve a contagem, porque a linha contada não muda.

No teste sem as travas, 8 requisições simultâneas criaram 8 campeonatos num plano que permite 1, e um participante incluído durante a geração ficou fora da tabela.

## Decisão

Trava pessimista (`PESSIMISTIC_WRITE`) numa linha "dona" do que está sendo contado, sempre antes de ler:

- **Criar campeonato:** trava a linha da `Organizacao`.
- **Criar, alterar ou excluir participante, alterar ou excluir campeonato e gerar:** trava a linha do `Campeonato`. No `PUT` de campeonato, a trava garante que uma alteração concorrente com a geração recebe o 409 de status certo, e não um "tente novamente" enganoso.

A trava fica só nos métodos `buscarParaAtualizar` dos repositórios. Uma operação nunca adquire as duas travas, o que evita deadlock entre elas.

O `@Version` continua valendo como segunda defesa, e a violação vira 409.

## Consequências

- Os limites valem mesmo sob concorrência, com testes em PostgreSQL real.
- Operações de escrita do mesmo campeonato ou da mesma organização ficam em fila. No volume do MVP o impacto é desprezível.
- Só funciona em banco com lock de linha, o que é o caso do PostgreSQL. Os testes de concorrência rodam em Postgres real, nunca em banco em memória.
