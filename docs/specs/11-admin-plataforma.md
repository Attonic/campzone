# 11 Admin da plataforma [FULL]

## Objetivo

Dar conteúdo à área `/admin`: o admin da plataforma vê um resumo do CampZone e a lista de organizações com plano e contagens. Só leitura (ADR 0002).

## Contexto

- Branches `feature/11-admin` nos dois repos:
  - backend: a partir de `feature/02-auth`;
  - frontend: a partir de `feature/07a-front-auth`.
- ADR 0002: este é o **único** lugar onde consultas cruzam organizações. Tudo fica sob `/api/v1/admin/**` (a `SecurityConfig` já exige `ADMIN_PLATAFORMA`), num módulo próprio `admin`. As regras multi-tenant das outras rotas não mudam.
- Campeonato "ativo" = status `RASCUNHO` ou `EM_ANDAMENTO` (spec 01).

## Contrato da API

Datas em ISO-8601. Erros em ProblemDetail. Sem token → 401; organizador → 403.

### `GET /api/v1/admin/resumo`

Resposta 200, `ResumoPlataformaResponse`:

| campo | tipo |
|---|---|
| `totalOrganizacoes` | number |
| `totalUsuarios` | number (organizadores + admins) |
| `totalCampeonatos` | number |
| `campeonatosAtivos` | number |

### `GET /api/v1/admin/organizacoes?pagina=0&tamanho=20&busca=texto`

Query:
- `pagina`: inteiro ≥ 0, padrão 0.
- `tamanho`: inteiro de 1 a 100, padrão 20.
- `busca`: opcional, até 100 caracteres. Filtra por nome contendo o texto, sem diferenciar maiúsculas.

Fora desses limites → 400. Ordenação fixa: `criadoEm` decrescente, depois `id` decrescente.

Resposta 200, `PaginaResponse<OrganizacaoAdminResponse>`:

| campo | tipo |
|---|---|
| `itens` | `OrganizacaoAdminResponse[]` |
| `pagina` | number |
| `tamanho` | number |
| `totalItens` | number |
| `totalPaginas` | number |

`OrganizacaoAdminResponse`:

| campo | tipo |
|---|---|
| `id` | number |
| `nome` | string |
| `planoCodigo` | string (ex. `"GRATIS"`) |
| `planoNome` | string |
| `totalUsuarios` | number |
| `totalCampeonatos` | number |
| `campeonatosAtivos` | number |
| `criadoEm` | string (ISO-8601) |

`PaginaResponse<T>` fica em `common` (será reutilizado). Não expor `Page` do Spring diretamente.

## Backend

- Módulo `admin`: `api/AdminController`, `api/response/*`, `service/AdminPlataformaService` + `impl/AdminPlataformaServiceImpl` (`@Transactional(readOnly = true)`), `repository/` com consultas de projeção.
- **Sem N+1:** as contagens da página saem de **uma** consulta agregada (JPQL com subconsultas ou `group by` em projeção/record), mais a consulta de contagem da paginação. É proibido buscar entidades e contar em laço. Prove com teste: conte as consultas (ex. `Statistics` do Hibernate, ou um `DataSource` proxy de teste) e confira que não crescem com o número de organizações.
- O admin **não** passa a acessar rotas de organizador, e nada nas rotas de organizador muda.
- Validação dos parâmetros na borda (`@Validated` no controller com `@Min`/`@Max`/`@Size`), com 400 em ProblemDetail.

## Frontend

- Feature `features/admin/`: `types.ts` (tipos idênticos ao contrato), `api/adminApi.ts`, hooks (`useResumoPlataforma`, `useOrganizacoesAdmin`) e componentes/páginas.
- `/admin` (já protegida por papel) passa a mostrar:
  - Cartões de resumo com os 4 números do `ResumoPlataformaResponse`.
  - Busca por nome (campo com label, com debounce ou botão "Buscar"; a busca volta para a página 0) e lista de organizações. No celular, cada org vira um cartão; em telas largas, pode ser tabela. Cada item mostra nome, plano, usuários, campeonatos (ativos/total) e data de criação formatada em pt-BR.
  - Paginação "Anterior"/"Próxima" com "Página X de Y", desabilitando os botões nas pontas. Mantém dados anteriores durante a troca de página (`placeholderData: keepPreviousData` ou equivalente).
  - Estados de carregando, erro (ProblemDetail visível, com "Tentar novamente") e vazio ("Nenhuma organização encontrada.").
- Sem cálculo no front: os números vêm da API.

## Testes obrigatórios

Backend:
- Organizador → 403 e sem token → 401, nas duas rotas.
- Admin → 200 com números corretos em cenário com 2+ organizações, usuários e campeonatos em status variados, inclusive `FINALIZADO`, que não conta como ativo.
- Paginação, ordenação e busca sem diferenciar maiúsculas. Parâmetros inválidos → 400.
- Teste de quantidade de consultas, que não cresce com o número de organizações.
- Teste unitário da `Impl` (Mockito) e web test do controller mockando a interface.

Frontend:
- Renderiza o resumo e a lista.
- Busca envia `busca` e volta para a página 0.
- Paginação: as pontas ficam desabilitadas e "Próxima" pede `pagina=1`.
- Estados de vazio e de erro.

## Critérios de aceite

- [ ] Contrato exato nos dois lados.
- [ ] Consulta cruzada só em `/api/v1/admin/**`, sem N+1 (testado).
- [ ] `./mvnw verify` e `npm run lint && npm test && npm run build` verdes.
- [ ] Teste manual: backend em dev contra Postgres descartável, cadastro de 2 organizações e login do admin no navegador (`/admin`) mostrando os números certos.

## Fora de escopo

Ações do admin (trocar plano, bloquear org, editar usuários), detalhe da organização, exportação, gráficos.
