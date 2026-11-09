# 08a Front: participantes, edição e geração [FRONT]

## Objetivo

O organizador preparar o campeonato no painel: cadastrar os participantes, ajustar nome e regras enquanto é rascunho e gerar a tabela ou a chave, entendendo antes que gerar não tem volta.

## Contexto

- Repo `frontend/`, branch `feature/08a-front-participantes-geracao`, criada **a partir de `feature/07b-front-campeonatos`** (aprovada, sem merge; branches empilhadas).
- Backend: tarefa 05 (`docs/specs/05-api-campeonatos.md`, seções "Campeonatos" e "Participantes"). O contrato abaixo é cópia daquela spec.
- Leia `frontend/CLAUDE.md` e a spec 07b. Reaproveite `features/campeonato/` (rótulos, `RegrasPontosCorridos`, `RegrasMataMata`, `CriteriosDesempate`, tradução de erros) e os `components/`.
- A tarefa 08b (resultados, classificação, chave e finalização) vem depois, sobre esta branch.

## Contrato consumido

| Método e rota | Entrada | Sucesso | Erros |
|---|---|---|---|
| `PUT /api/v1/campeonatos/{id}` | `AtualizarCampeonatoRequest` | 200 `CampeonatoResponse` | 400, 404, 409 |
| `POST /api/v1/campeonatos/{id}/gerar` | sem corpo | 201 `GeracaoResponse` | 404, 409, 422 |
| `GET /api/v1/campeonatos/{id}/participantes` | | 200 `ParticipanteResponse[]` | 404 |
| `POST /api/v1/campeonatos/{id}/participantes` | `CriarParticipanteRequest` | 201 `ParticipanteResponse` | 400, 404, 409 |
| `PUT /api/v1/campeonatos/{id}/participantes/{participanteId}` | `AtualizarParticipanteRequest` | 200 `ParticipanteResponse` | 400, 404, 409 |
| `DELETE /api/v1/campeonatos/{id}/participantes/{participanteId}` | | 204 | 404, 409 |

```ts
interface AtualizarCampeonatoRequest {
  nome: string
  modalidade: string
  publico: boolean
  configPontosCorridos: ConfigPontosCorridosRequest | null // null = não altera
  configMataMata: ConfigMataMataRequest | null             // null = não altera
}
interface GeracaoResponse {
  campeonatoId: number
  status: 'EM_ANDAMENTO'
  totalFases: number
  totalRodadas: number
  totalConfrontos: number
  totalPartidas: number
}
// em features/participante/types.ts
interface CriarParticipanteRequest { nome: string; seed: number | null }
interface AtualizarParticipanteRequest { nome: string; seed: number | null }
interface ParticipanteResponse { id: number; nome: string; seed: number | null }
```

Regras do backend que a tela precisa respeitar:
- `nome`, `modalidade` e `publico` mudam em qualquer status. Config só em `RASCUNHO`, senão 409. Formato e slug nunca mudam.
- Participante (nome 2..120, seed ≥ 1 ou `null`): criar, excluir ou mudar a seed fora de `RASCUNHO` dá 409. **Corrigir o nome é permitido em qualquer status, desde que a seed vá igual à atual.** Mandar `null` no lugar da seed atual é mudar a seed.
- Nome repetido no campeonato: 409. Limite de participantes do plano: 409 com `detail`.
- Gerar: 422 com a mensagem do motor (menos de 2 participantes, seeds inválidas), sem mudar nada.

## Requisitos

### Participantes (seção no detalhe do campeonato)

- Lista na ordem da API, com estados de loading, erro e vazio. O vazio explica que são necessários pelo menos 2 para gerar.
- **Em `RASCUNHO`:** adicionar (formulário curto no topo da seção; depois de adicionar, limpa o campo e devolve o foco a ele, para cadastrar vários em sequência), editar e excluir. Excluir tem confirmação inline, sem `window.confirm`.
- **Depois de gerado:** só corrigir o nome. Não há adicionar, excluir nem seed editável. O `PUT` reenvia a seed atual.
- **Seed:** o campo só aparece em mata-mata com seeding `MANUAL` ("Posição na chave", obrigatória na prática) ou `CABECAS_DE_CHAVE` ("Cabeça de chave", opcional). Explique em uma linha o que cada um significa. Fora desses casos, a seed vai `null` e não aparece. Campo vazio vai `null`, nunca `""`. A validação de unicidade e sequência é do motor e aparece no 422 da geração.
- Erros: `erros[]` junto do campo e `detail` (nome repetido, limite do plano, status mudou) visível na seção. Depois de um 409 de status, recarregue o campeonato e os participantes.
- Mutations invalidam os participantes **e** o campeonato (`totalParticipantes`).

### Editar campeonato (`/app/campeonatos/:id/editar`)

- Página única, não assistente: nome e modalidade sempre; regras (os mesmos componentes do passo 3 do assistente, já preenchidos com a config atual) só em `RASCUNHO`. O formato aparece como texto, não editável.
- O `publico` vai com o valor atual; mudar visibilidade é da tarefa 09.
- Fora de `RASCUNHO`, as configs vão `null`. Em `RASCUNHO`, vai a config do formato e a outra `null`.
- Erros como no assistente: campo junto do campo, o resto no topo. Sucesso volta ao detalhe.
- Botão "Editar" no detalhe.

### Gerar

- Botão "Gerar tabela" (pontos corridos) ou "Gerar chave" (mata-mata), só em `RASCUNHO`.
- **Confirmação forte, inline:** abre um painel com o resumo (formato, quantidade de participantes) e o aviso, em texto claro, de que depois de gerar não é possível incluir ou excluir participantes, nem mudar as regras ou as posições na chave, e que o campeonato ocupa a vaga do plano até ser finalizado. O botão final só habilita depois de marcar "Entendi que não dá para desfazer". O foco vai ao painel ao abrir e volta ao botão ao cancelar.
- Durante o envio: "Gerando…", sem envio duplo.
- 201: invalida o campeonato e os participantes e mostra a confirmação com os números do `GeracaoResponse` (rodadas e partidas, ou confrontos e partidas). O status passa a "Em andamento".
- 422 e 409: `detail` no painel, sem fechar. O 409 recarrega o campeonato.
- Com menos de 2 participantes, o botão continua disponível. A regra é do motor e o 422 explica, mas a tela mostra ao lado quantos participantes há.

### Herdado da 07b (commits próprios)

1. Teste "erro de caixa de seleção": usar `not.toHaveAccessibleDescription(expect.stringContaining(mensagem))` e conferir `not.toBeInvalid()`.
2. Teste do `descartarErroDoEnvio()` dentro de `alterar()`: erro misto, corrigir o campo no passo de destino e seguir à revisão sem clicar em Voltar.
3. `CriteriosDesempate`: a mensagem do limite não pode contradizer a numeração (ex.: "Vitórias já está no topo dos critérios que se movem") e é anunciada de novo a cada tentativa.

## Testes obrigatórios (Vitest e Testing Library, API mockada)

- **Participantes:**
  - loading, erro e vazio;
  - adicionar em sequência, com o foco de volta ao campo;
  - editar; excluir com confirmação e cancelamento;
  - 400 no campo, 409 de nome repetido e do limite;
  - **renomear depois de gerado reenvia a seed atual** (corpo exato);
  - seed visível só nos seedings certos; vazio vai `null`;
  - em `EM_ANDAMENTO` não há adicionar nem excluir;
  - 409 de status recarrega.
- **Editar:** os dois formatos; em rascunho a config vai preenchida e alterada; fora de rascunho as configs vão `null` (corpo exato); `publico` preservado; erros.
- **Gerar:**
  - o botão final só habilita com a confirmação marcada; cancelar;
  - foco;
  - envio único;
  - 201 com os números;
  - 422 com a mensagem do motor;
  - 409.
- **Guardas:** `/app/campeonatos/:id/editar` exige `ORGANIZADOR`.

## Critérios de aceite

- [ ] Contrato acima exatamente, sem campo nem endpoint inventado.
- [ ] `npm run lint && npm test && npm run build` verde, também com `TZ=Asia/Tokyo` no `npm test`.
- [ ] **Teste contra o backend real** (fora do repositório, mesmo procedimento da 07b, Postgres descartável na porta 55444). Com a branch atual de `backend/` (`feature/06-api-partidas-resultados`), monte por `curl` o fluxo que a tela faz:
  - um campeonato de cada formato e 9 participantes, para ver o 409 do limite;
  - nome repetido;
  - `MANUAL` com seed faltando, que dá 422 ao gerar;
  - geração, depois renomeação com a seed reenviada (200) e sem ela (409);
  - edição com as configs `null` depois de gerado.

  Leve os JSONs reais ao relatório. Remova o container e pare os processos pelo PID no fim.
- [ ] Layout a 360 px e uso por teclado conferidos, inclusive o painel de confirmação.

## Fora de escopo

Resultados, tabela, classificação, chave e finalizar (08b), visibilidade e página pública (09).
