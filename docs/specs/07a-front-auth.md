# 07a Front: login, cadastro e painel vazio [FRONT]

## Objetivo

O Antonio conseguir entrar no CampZone pelo navegador: tela de login única que leva cada papel ao seu lugar, cadastro de organização, painel do organizador (vazio por enquanto) e área do admin (vazia por enquanto), com logout.

## Contexto

- Repo `frontend/`, branch `feature/07a-front-auth`, criada **a partir de `feature/00-scaffold`** (o front não tem a 01/02; branches empilhadas).
- Backend: tarefa 02 (`docs/specs/02-auth.md`). O **contrato abaixo é cópia fiel da spec 02**. Se o back mudar, esta spec é atualizada antes.
- ADR 0002: papéis `ADMIN_PLATAFORMA` e `ORGANIZADOR`.
- Contas de dev (após a 02): `admin@campzone.dev` / `admin12345` e `organizador@campzone.dev` / `organizador123`.

## Contrato consumido (da spec 02)

- `POST /api/v1/public/auth/cadastro`
  - `CadastrarOrganizacaoRequest` `{ nomeOrganizacao, nome, email, senha }`.
  - Respostas: **201** `AutenticacaoResponse`, **409** e-mail já cadastrado, **400** validação (`erros[{campo, mensagem}]`).
- `POST /api/v1/public/auth/login`
  - `LoginRequest` `{ email, senha }`.
  - Respostas: **200** `AutenticacaoResponse`, **401** "E-mail ou senha inválidos.", **400** validação.
- `GET /api/v1/auth/me` (com `Authorization: Bearer <token>`)
  - Respostas: **200** `UsuarioResponse`, **401** sem token ou com token inválido/expirado.

Tipos (em `features/auth/types.ts`, nomes e campos idênticos):

```ts
type Papel = 'ADMIN_PLATAFORMA' | 'ORGANIZADOR'
interface CadastrarOrganizacaoRequest { nomeOrganizacao: string; nome: string; email: string; senha: string }
interface LoginRequest { email: string; senha: string }
interface UsuarioResponse { id: number; nome: string; email: string; papel: Papel; organizacaoId: number | null; organizacaoNome: string | null }
interface AutenticacaoResponse { token: string; tipo: 'Bearer'; expiraEm: string; usuario: UsuarioResponse }
```

## Requisitos

1. **Sessão** (`features/auth/`):
   - O token fica num único módulo de sessão. Guarde em `localStorage` (decisão do orquestrador para o MVP: sobrevive a recarregar a página). Ele nunca vai para URL nem para log.
   - O cliente HTTP base (`lib/api`) passa a enviar `Authorization: Bearer` quando houver token. O ponto de injeção é configurável e o `lib/api` não depende de `features/`.
   - Ao receber **401** de rota autenticada: limpa a sessão e manda para `/login`. Na volta do login, vai para a página onde estava.
   - Ao abrir o app com token salvo, valida com `GET /auth/me`. Se vier 401, a sessão é limpa.
   - Expiração: use `expiraEm` para descartar um token vencido sem chamar a API. Isso não é regra de negócio, é higiene de sessão.
2. **Rotas**:
   - `/login`: pública. Se já estiver logado, redireciona pelo papel.
   - `/cadastro`: pública. Depois do sucesso, já entra logado e vai para `/app`.
   - `/app`: guarda que exige `ORGANIZADOR`. Mostra o layout do painel com cabeçalho (nome da organização, nome do usuário, botão Sair) e conteúdo "Nenhum campeonato ainda", com o texto "Em breve você poderá criar campeonatos aqui." Sem botão de criar, porque a API não existe ainda.
   - `/admin`: guarda que exige `ADMIN_PLATAFORMA`. Layout com cabeçalho ("Admin da plataforma", nome, Sair) e conteúdo "Painel da plataforma em construção."
   - Papel errado na rota: redireciona para a área do próprio papel.
   - Sem sessão em rota protegida: vai para `/login`.
   - `/`: a home atual ganha links "Entrar" e "Criar conta". Logado, mostra "Ir para o painel".
   - Redirecionamento pós-login pelo papel: `ADMIN_PLATAFORMA` → `/admin` e `ORGANIZADOR` → `/app`.
3. **Formulários**:
   - `label` em todo campo; validação de UX (obrigatórios, formato de e-mail, senha 8..72, nomes 2..100) antes de enviar.
   - Botão desabilitado com "Entrando…" ou "Criando…" durante o envio.
   - Erros da API visíveis: o `detail` do ProblemDetail no topo do formulário, e `erros[]` mapeados para os campos (`campo` = nome do campo do Request).
   - O 401 do login mostra a mensagem do backend.
   - Senha com `type="password"` e `autocomplete` corretos (`current-password` no login, `new-password` no cadastro).
4. **Logout**: limpa a sessão e o cache do TanStack Query (`queryClient.clear()`), e vai para `/login`.
5. **Camadas** (`frontend/CLAUDE.md`):
   - `features/auth/types.ts`, `api/authApi.ts`, `hooks/` (`useLogin`, `useCadastro`, `useUsuarioAtual`, `useLogout`), `components/`, `pages/`.
   - Componentes só chamam hooks.
   - Componentes visuais genéricos (Input com label e erro, Button) em `src/components/`.
6. **UX**: mobile first, foco visível, contraste ok e o mesmo visual escuro da home.

## Testes obrigatórios (Vitest + Testing Library, API mockada)

- Login ok de organizador vai para `/app`, e login ok de admin vai para `/admin`.
- Login 401 mostra "E-mail ou senha inválidos."
- Validação de UX impede o envio (e-mail inválido, senha curta).
- Cadastro ok entra logado em `/app`. Cadastro 409 mostra o `detail`. Cadastro 400 mostra os erros nos campos certos.
- Guardas:
  - sem sessão em `/app` vai para `/login`;
  - organizador em `/admin` vai para `/app`;
  - admin em `/app` vai para `/admin`.
- Sessão:
  - um 401 numa chamada autenticada limpa a sessão e redireciona;
  - token com `expiraEm` no passado é descartado.
- O cliente HTTP envia `Authorization` quando há token e não envia quando não há.
- Logout limpa a sessão.

## Critérios de aceite

- [ ] Contrato exatamente como acima; nenhum campo ou endpoint inventado.
- [ ] `npm run lint && npm test && npm run build` verde.
- [ ] Teste manual: com o backend da `feature/02-auth` rodando, login das duas contas de dev no navegador (`npm run dev`), cadastro de uma org nova e logout. Se o backend não estiver disponível para você, reporte e deixe o teste manual para o orquestrador.

## Fora de escopo

Lista e wizard de campeonatos (07b), conteúdo do admin (11), recuperar senha, "lembrar de mim", refresh token, convite de membros.
