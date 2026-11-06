# ADR 0003: Regras de schema para evoluir com `ddl-auto=update` (sem migrations)

- Data: 2026-10-21
- Status: aceita (orquestrador; consequência da decisão do Antonio de não usar migrations)

## Contexto

O projeto não usa Flyway nem migrations: o schema vem das entidades via `ddl-auto=update`. O `update` só **adiciona** tabelas, colunas, FKs e índices. Ele não altera nem remove constraints, não muda o tipo de uma coluna e não tira `NOT NULL`. A revisão da tarefa 01 achou dois riscos:

- O Hibernate 7 gera `CHECK (coluna IN (...))` para todo enum mapeado. Um valor novo de enum quebraria os bancos já criados.
- Um campo primitivo novo vira `NOT NULL` sem default, e o `ALTER TABLE ADD COLUMN` falha em tabela com linhas.

## Decisão

1. **Enum persistido como texto, sem CHECK.** Na entidade, o campo é uma `String` privada (varchar folgado). Getters e fábricas expõem o enum. Há um teste com Testcontainers que falha se aparecer alguma CHECK de enum no schema. CHECKs escritas à mão (`@Check`) são permitidas, desde que sejam regras estáveis (ex.: placar ≥ 0).
2. **Coluna nova sempre anulável**: tipo wrapper (`Integer`, `Long`, `Boolean`), sem `nullable = false`. A obrigatoriedade fica no domínio e na validação.
3. **Uniques não são recriadas a cada boot** (`hibernate.schema_update.unique_constraint_strategy = RECREATE_QUIETLY`).
4. **Concorrência**: `@Version` (wrapper `Long`) desde a criação em `Campeonato`, `Fase`, `Confronto`, `Partida` e `Resultado`.
5. Renomear ou remover coluna, trocar tipo ou mudar constraint continua exigindo aviso ao orquestrador e um passo manual documentado.

## Consequências

- Domínio um pouco mais verboso (conversão String ↔ enum dentro da entidade), em troca de enums que evoluem sem SQL manual.
- O banco dev do Antonio, criado antes desta regra, tem CHECKs antigas: precisa ser recriado (só tem dados de seed) ou ter as CHECKs removidas à mão.
