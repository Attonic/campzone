# 02 Auth e multi-tenant [BACK]

## Objetivo

Cadastro de organização + organizador, login com JWT, dois papéis (`ADMIN_PLATAFORMA` e `ORGANIZADOR`, ADR 0002), `organizacaoId` extraído do token e base do isolamento multi-tenant. Em dev, um admin e um organizador de teste prontos para o Antonio entrar.

## Contexto

- Repo `backend/`, branch `feature/02-auth`, criada **a partir de `feature/01-dominio`** (branches empilhadas).
- ADR 0002 é obrigatória: admin sem organização, só em `/api/v1/admin/**`; organizador só nas rotas de organização.
- Rotas sem autenticação ficam **só** em `/api/v1/public/**`, por isso o login e o cadastro moram em `/api/v1/public/auth/**`.

## Decisões técnicas (do orquestrador)

1. **JWT com o resource server do Spring Security** (`spring-boot-starter-oauth2-resource-server`): `NimbusJwtEncoder`/`NimbusJwtDecoder` com HMAC-SHA256. Nada de jjwt ou outra lib.
2. **Segredo**: `campzone.jwt.segredo` (no mínimo 32 bytes).
   - **dev**: valor fixo de desenvolvimento no `application-dev.yml`, com comentário "não é segredo".
   - **prod**: `JWT_SECRET` obrigatório, somado às variáveis do `VariaveisObrigatoriasProd`.
   - Expiração em `campzone.jwt.expiracao` (`Duration`, padrão `PT8H`). Sem refresh token no MVP.
3. **Claims**: `sub` = id do usuário, `papel`, `org` = `organizacaoId` (só no organizador), `nome`, `iat`, `exp`. Autoridades: `ROLE_ADMIN_PLATAFORMA` ou `ROLE_ORGANIZADOR`.
4. **Senha**: `PasswordEncoder` delegante do Spring (bcrypt). Nunca logar senha nem token.
5. **`organizacaoId` do token**: um único ponto de leitura, por exemplo um argument resolver com `@OrganizacaoAtual Long organizacaoId` nos controllers, ou um `UsuarioAutenticado` injetável. Ele **nunca** lê body, query, header ou path. Se o principal não tiver `org` (admin), responde 403.
6. **Autorização na `SecurityConfig`**:
   - `/api/v1/public/**`: liberado.
   - `/api/v1/admin/**`: `ADMIN_PLATAFORMA`.
   - `/api/v1/auth/me`: qualquer autenticado.
   - Demais `/api/v1/**`: `ORGANIZADOR`.
   - Resto: negado.
   - 401 e 403 continuam em ProblemDetail.
7. **Módulos**: `Usuario` em `auth/domain`. Controller, request, response, mapper, service e impl em `auth/` (o service segue o par interface + `Impl`). Org criada pelo `OrganizacaoService` + `Impl`, chamado pelo service de auth via interface.

## Entidade nova

`Usuario` (`auth/domain`): `id`, `nome`, `email` (único global, guardado normalizado em minúsculas, sem espaços), `senhaHash`, `papel` (`ADMIN_PLATAFORMA`/`ORGANIZADOR`), `organizacao` (ManyToOne LAZY, **obrigatória para `ORGANIZADOR` e nula para `ADMIN_PLATAFORMA`**, invariante no domínio), `criadoEm`. Índice em `organizacao_id`, unique `uk_usuario_email`.

## Seeds

- **`AdminSeeder`** (todos os perfis, idempotente): garante o admin da plataforma com `campzone.admin.email`/`campzone.admin.senha`.
  - dev: `admin@campzone.dev` / `admin12345` no `application-dev.yml`.
  - prod: `ADMIN_EMAIL`/`ADMIN_SENHA` obrigatórios (no `VariaveisObrigatoriasProd`).
  - Só cria se não existir usuário com aquele e-mail e nunca sobrescreve a senha.
- **`DevDadosSeeder`** (`@Profile("dev")`, idempotente): cria a org "Organização Demo" no plano `GRATIS` e o organizador `organizador@campzone.dev` / `organizador123`.
- O README lista as duas contas de dev.

## Contrato da API

Datas ISO-8601. Erros em ProblemDetail (validação com `erros[{campo, mensagem}]`).

### `POST /api/v1/public/auth/cadastro` (público)

`CadastrarOrganizacaoRequest`:

| campo | tipo | regra |
|---|---|---|
| `nomeOrganizacao` | string | obrigatório, 2..100 |
| `nome` | string | obrigatório, 2..100 (nome do organizador) |
| `email` | string | obrigatório, e-mail válido, ≤ 254 |
| `senha` | string | obrigatória, 8..72 |

Respostas:
- **201** `AutenticacaoResponse`: cria a org no plano `GRATIS` e o usuário `ORGANIZADOR`, e já devolve o token.
- **409**: e-mail já cadastrado, com `detail` claro.
- **400**: erro de validação.

### `POST /api/v1/public/auth/login` (público)

`LoginRequest`: `email` (obrigatório), `senha` (obrigatória).

Respostas:
- **200** `AutenticacaoResponse`.
- **401**: ProblemDetail com o mesmo `detail` para e-mail inexistente e senha errada ("E-mail ou senha inválidos."), sem enumeração de usuário.
- **400**: erro de validação.

### `GET /api/v1/auth/me` (autenticado, qualquer papel)

- **200** `UsuarioResponse`.
- **401** sem token, ou com token inválido ou expirado.

### Tipos de saída

`AutenticacaoResponse`:

| campo | tipo |
|---|---|
| `token` | string (JWT) |
| `tipo` | string, sempre `"Bearer"` |
| `expiraEm` | string ISO-8601 (instante) |
| `usuario` | `UsuarioResponse` |

`UsuarioResponse`:

| campo | tipo |
|---|---|
| `id` | number |
| `nome` | string |
| `email` | string |
| `papel` | `"ADMIN_PLATAFORMA"` \| `"ORGANIZADOR"` |
| `organizacaoId` | number \| null |
| `organizacaoNome` | string \| null |

## Herdado da 00/01 (fazer junto)

- Erros barrados antes do DispatcherServlet (firewall do Security, `RequestRejectedException`) e falhas do filtro JWT saem em ProblemDetail (`RequestRejectedHandler` e/ou `ErrorController` próprios). Teste com `/api/v1/public/a;b` → 400 em `application/problem+json`.
- Isolar o `ApiTesteController` de teste do component scan (não pode aparecer em `@SpringBootTest` nem no `TestCampzoneApplication`).
- `InvarianteDominioException` → 400 em ProblemDetail no `GlobalExceptionHandler`.

## Testes obrigatórios

- Cadastro:
  - cria org (plano `GRATIS`) e organizador, e o token devolvido funciona em `/auth/me`;
  - e-mail duplicado devolve 409, inclusive com maiúsculas e espaços diferentes;
  - validação devolve 400 com `erros`.
- Login:
  - ok;
  - senha errada e e-mail inexistente devolvem o **mesmo** 401;
  - a senha fica guardada como hash.
- Token:
  - sem token, malformado, assinado com outro segredo ou expirado: todos dão 401;
  - em todos esses casos o `/auth/me` responde 401.
- Papéis:
  - o organizador recebe 403 em `/api/v1/admin/**`;
  - o admin recebe 403 numa rota de organizador;
  - os dois acessam `/auth/me`.
- **Isolamento base**: um endpoint de teste (só em `src/test`, isolado do scan) devolve o `organizacaoId` resolvido. Com o token da org A e um `organizacaoId` da org B no body, query e header, ele devolve A.
- Seeds:
  - rodar duas vezes não duplica;
  - o admin não tem organização;
  - prod sem `JWT_SECRET`/`ADMIN_EMAIL`/`ADMIN_SENHA` não sobe, com mensagem clara.
- Service `Impl` com teste unitário (Mockito), e controller com web test mockando a interface.

## Critérios de aceite

- [ ] Contrato acima exatamente (nomes de campos, status, rotas).
- [ ] `organizacaoId` vem só do JWT; teste de isolamento base passando.
- [ ] Papéis aplicados conforme a ADR 0002.
- [ ] Contas de dev funcionando: teste manual com `curl` em dev, com login das duas contas e `/auth/me` de cada uma. Use um Postgres descartável em outra porta (o `campzone-postgres` da 5433 tem schema antigo e aguarda o Antonio liberar a recriação: **não toque nele**).
- [ ] Nada de segredo de prod versionado; senha e token nunca no log.
- [ ] `./mvnw verify` verde.

## Fora de escopo

Telas (07a), endpoints do admin (11), refresh token, recuperação de senha, convite de membros, rate limiting, CORS de produção.
