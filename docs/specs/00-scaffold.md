# 00 Scaffold [FULL]

## Objetivo

Deixar o repositório pronto para desenvolver: backend Spring Boot 4 e frontend React compilando e testando, PostgreSQL local via docker-compose, CI no GitHub Actions e README mínimo. Nenhuma regra de negócio.

## Ambiente (máquina do Antonio, Fedora)

- O `java` padrão do sistema é o **17**. Use o JDK 21 explicitamente: `export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk` antes do `./mvnw`.
- Node 24 / npm 11. Docker 29 com `docker compose` (plugin v5), usuário já roda `docker` sem sudo (Testcontainers funciona).
- `backend/` e `frontend/` são **repositórios git próprios** (ADR 0001), cada um já com `main` (CLAUDE.md + .gitignore) e a branch `feature/00-scaffold`. A raiz do workspace não é repo. Git sempre dentro da pasta da área.
- `backend/CLAUDE.md` e `frontend/CLAUDE.md` já existem: **nunca sobrescreva**. Gere os projetos numa pasta temporária e mova os arquivos para dentro.

## Parte BACK (`dev-back`)

Tudo dentro de `backend/` (repo `campzone-backend`), inclusive a infra: `backend/docker-compose.yml`, `backend/.env.example`, `backend/.github/workflows/ci.yml`, `backend/README.md`.

1. **Projeto** pelo Spring Initializr (`https://start.spring.io`, consulte os metadados para pegar a **4.x estável mais recente** (hoje 4.1.1, pedido do Antonio), não fixe de memória): Maven, Java 21, Jar, `groupId=br.com.codeacle`, `artifactId=campzone`, pacote `br.com.codeacle.campzone`. Dependências: Spring Web (webmvc), Spring Data JPA, Spring Security, Validation, PostgreSQL Driver, Testcontainers. **Sem Flyway, sem Liquibase, sem Lombok, sem MapStruct.** Mantenha o `mvnw` executável.
2. **Configuração**:
   - `application.yml`: nome da app, `spring.jpa.hibernate.ddl-auto=update`, `open-in-view: false`, datasource lido de variáveis de ambiente com default para o compose local (`DB_URL`, `DB_USER`, `DB_PASSWORD`).
   - Perfil `local`: `application-local.yml` está no `.gitignore`; versione `application-local.example.yml` com o conteúdo de exemplo e explique no README que basta copiar.
   - Nenhum segredo real versionado.
3. **Pacotes**: crie só a classe principal em `br.com.codeacle.campzone`. Não crie módulos vazios nem placeholders (eles nascem nas tarefas seguintes).
4. **Segurança mínima de scaffold**: uma `SecurityConfig` stateless (sem sessão, CSRF desligado para API) que libera `/api/v1/public/**` e exige autenticação no resto. Sem JWT ainda (tarefa 02). Sem usuário/senha default logado no console como “segredo” (desligue o `UserDetailsService` gerado automaticamente ou documente).
5. **Erros**: um `@RestControllerAdvice` base em `common` devolvendo `ProblemDetail` para erro de validação (`MethodArgumentNotValidException`) e genérico 500 sem vazar stacktrace. Com teste.
6. **Testes**: `contextLoads` com Testcontainers (PostgreSQL, `@ServiceConnection`) e teste de web layer do advice e da `SecurityConfig` (rota pública acessível, rota privada → 401). `./mvnw verify` verde.
7. **`backend/docker-compose.yml`**: serviço `postgres` (imagem oficial, versão major estável atual, ex. `postgres:17`), volume nomeado, porta 5432, healthcheck, credenciais via `.env` com defaults (`.env.example` versionado).
8. **CI** `backend/.github/workflows/ci.yml`: dispara em push e pull_request; `actions/setup-java` Temurin 21 com cache Maven; `./mvnw -B verify` (Testcontainers usa o Docker do runner `ubuntu-latest`).
9. **`backend/README.md`**: pré-requisitos no Fedora (JDK 21, `JAVA_HOME`, Docker), `docker compose up -d`, `./mvnw spring-boot:run -Dspring-boot.run.profiles=local`, `./mvnw verify`. Mencione que o front está em `campzone-frontend`.

## Parte FRONT (`dev-front`)

Tudo dentro de `frontend/` (repo `campzone-frontend`), inclusive `frontend/.github/workflows/ci.yml` e `frontend/README.md`.

1. `npm create vite@latest` (template `react-ts`) numa pasta temporária, mover para `frontend/` sem sobrescrever `frontend/CLAUDE.md`.
2. Dependências (versões estáveis mais recentes no momento): React Router, TanStack Query, Tailwind CSS (plugin oficial do Vite), Vitest + Testing Library + jsdom.
3. TypeScript `strict`. Scripts: `lint`, `test` (`vitest run`), `build`.
4. Estrutura mínima: `src/app/` (providers: `QueryClientProvider` + router), `src/lib/api/` com um cliente HTTP base (`baseURL` de `import.meta.env.VITE_API_URL`, default `/api/v1`) que converte erro em `ProblemDetail` tipado, `src/features/` vazio por enquanto. Uma rota `/` com página simples “CampZone” estilizada com Tailwind. Proxy do Vite `/api` → `http://localhost:8080`.
5. Testes: render da página inicial e teste do cliente HTTP convertendo uma resposta de erro em `ProblemDetail` (com `fetch` mockado).
6. `.env.example` do front se usar variável.
7. CI `frontend/.github/workflows/ci.yml`: push/PR; `actions/setup-node` (LTS) com cache npm; `npm ci && npm run lint && npm test && npm run build`.
8. `frontend/README.md`: `npm install`, `npm run dev` (com o backend do `campzone-backend` rodando), checks.

## Critérios de aceite

- [ ] `cd backend && ./mvnw verify` passa (com `JAVA_HOME` no 21), incluindo `contextLoads` com Testcontainers.
- [ ] Spring Boot é a 4.x estável mais recente (4.1.1) do Initializr na data; Java 21; sem Flyway/Liquibase/`.sql` de schema.
- [ ] `cd backend && docker compose up -d` sobe o PostgreSQL saudável e a app conecta com o perfil `local`.
- [ ] `GET /api/v1/public/qualquer` não exige autenticação (404 é aceitável); qualquer outra rota sem auth → 401.
- [ ] Erros saem como `ProblemDetail`.
- [ ] `cd frontend && npm run lint && npm test && npm run build` passa.
- [ ] `backend/CLAUDE.md` e `frontend/CLAUDE.md` intactos.
- [ ] Workflow de CI válido em cada repo.
- [ ] README de cada repo explica como rodar no Fedora.
- [ ] Nada criado na raiz do workspace.
- [ ] Nenhum segredo versionado; `application-local.yml` e `.env` ignorados.

## Contrato da API

Nenhum endpoint de negócio nesta tarefa. Convenções que passam a valer: prefixo `/api/v1`, públicas em `/api/v1/public/**`, erros em `ProblemDetail` (RFC 9457).

## Fora de escopo

Entidades, JWT, cadastro/login, módulos de negócio, JaCoCo (entra na 03), telas reais, deploy.

---

## Adendo A: perfis `dev` e `prod` [BACK] (pedido do Antonio, 2026-10-21)

Objetivo: ter um `application` de dev e um de prod já configurados, e o banco local funcionando sem ajuste manual.

Contexto: na máquina do Antonio a 5432 está ocupada por outro PostgreSQL. Há mudanças não commitadas do Antonio em `backend/.env.example` e `backend/src/main/resources/application.yml` trocando 5432 → 5433: incorpore essa intenção (não descarte).

1. **Perfis**: `application.yml` (comum), `application-dev.yml` e `application-prod.yml`, todos em `src/main/resources` e versionados. O perfil `local` e o `config/application-local.example.yml` deixam de existir (substituídos pelo `dev`).
2. **Base (`application.yml`)**: só o que é comum (nome, `open-in-view: false`, `ddl-auto: update`, sem credenciais). `spring.profiles.default: dev`, para que rodar na IDE sem perfil caia no dev.
3. **`dev`**: datasource `${DB_URL:jdbc:postgresql://localhost:5433/campzone}`, `${DB_USER:campzone}`, `${DB_PASSWORD:campzone}` (credenciais só do Docker local, não são segredo); log DEBUG em `br.com.codeacle.campzone`.
4. **`prod`**: datasource **só** por `DB_URL`, `DB_USER`, `DB_PASSWORD`, **sem default**: se faltar, a app não sobe (falha rápida e clara). `server.port: ${PORT:8080}`, log INFO, `show-sql` desligado, sem detalhes de erro na resposta (`server.error.include-*: never`), pool Hikari com tamanho por env com default sensato. Nada de segredo versionado.
5. **Banco local**: porta padrão **5433** no `docker-compose.yml` (`127.0.0.1:${POSTGRES_PORT:-5433}:5432`) e no `.env.example`. O PostgreSQL do projeto já está rodando (`campzone-postgres`, healthy em 127.0.0.1:5433): use-o e **deixe-o rodando** ao final.
6. **Testes**: os testes continuam com Testcontainers (sem depender do banco local). Adicione um teste provando que o perfil `prod` sem `DB_URL`/`DB_USER`/`DB_PASSWORD` falha ao iniciar (ou que as propriedades não têm default), e que o perfil default é `dev`.
7. **README**: como rodar no IntelliJ (SDK temurin-21, `CampzoneApplication` sem configurar perfil = dev; `TestCampzoneApplication` como alternativa sem docker-compose), `docker compose up -d`, e como rodar em prod (`SPRING_PROFILES_ACTIVE=prod` + variáveis obrigatórias, `java -jar`).

Critérios de aceite do adendo:
- [ ] `docker compose up -d` sobe na 5433 sem `.env` e a app sobe com `./mvnw spring-boot:run` (sem informar perfil) conectando nele.
- [ ] `SPRING_PROFILES_ACTIVE=prod` sem as variáveis do banco: a app não sobe, com mensagem clara.
- [ ] `SPRING_PROFILES_ACTIVE=prod` com as variáveis: a app sobe.
- [ ] Nenhum resquício do perfil `local`; `./mvnw verify` verde.

Fora de escopo do adendo: Dockerfile, deploy, actuator/health, JWT (o `JWT_SECRET` obrigatório em prod entra na tarefa 02), front.
