# ADR 0002: Perfis de acesso: admin da plataforma e organizador

- Data: 2026-10-21
- Status: aceita (decisão do Antonio)

## Contexto

O backlog previa um único tipo de login: o organizador, dono de uma organização (tenant). O Antonio quer também um **admin da plataforma**, que enxerga o CampZone inteiro.

## Decisão

- `Usuario` tem um `papel`: `ADMIN_PLATAFORMA` ou `ORGANIZADOR`.
- **Organizador**: pertence a exatamente uma `Organizacao`. O JWT carrega `organizacaoId` e o papel. Todas as regras multi-tenant continuam valendo sem exceção.
- **Admin da plataforma**: não pertence a nenhuma organização (sem `organizacaoId` no JWT). Só acessa rotas em `/api/v1/admin/**`, que exigem o papel `ADMIN_PLATAFORMA`. É o **único** lugar do sistema onde consultas cruzam organizações, e ele fica explícito, separado e testado. O admin **não** acessa as rotas de organizador, e o organizador não acessa `/api/v1/admin/**`.
- O admin não se cadastra pela tela: é criado por um `ApplicationRunner` idempotente.
  - Em `dev`, com credenciais fixas de desenvolvimento (documentadas no README).
  - Em `prod`, por variáveis de ambiente obrigatórias (`ADMIN_EMAIL`, `ADMIN_SENHA`).
- MVP do painel admin: leitura (listar organizações com plano e contagens). Ações (trocar plano, bloquear) ficam fora até haver planos pagos.

## Consequências

- O isolamento multi-tenant ganha uma exceção controlada. O reviewer deve checar que a consulta cruzada só existe em `/api/v1/admin/**`, e há testes provando que o organizador recebe 403 lá e que o admin não lê dados de org pelas rotas normais.
- Nova tarefa no backlog: **11 Admin da plataforma [FULL]**, executada logo depois da 07.
