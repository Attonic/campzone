# 07b Front: lista e criação de campeonatos [FRONT]

## Objetivo

O organizador entrar no painel, ver seus campeonatos e criar um novo por um assistente em passos, com as regras de pontos corridos ou de mata-mata já preenchidas com valores razoáveis.

## Contexto

- Repo `frontend/`, branch `feature/07b-front-campeonatos`, criada **a partir da `main`** (já tem 00, 07a e 11).
- Backend: tarefa 05 (`docs/specs/05-api-campeonatos.md`, "Campeonatos"), em `feature/06-api-partidas-resultados`, que está sem merge. O contrato abaixo é cópia daquela spec.
- Leia `frontend/CLAUDE.md` e reaproveite `features/admin/` como modelo de lista paginada, além de `components/{Button,Input,Alert,Paginacao,ErroAoCarregar}` e `lib/formatar.ts`.
- Regra de negócio fica no backend. O assistente só oferece opções válidas para facilitar; quem decide é a API, e todo erro dela aparece na tela.

## Contrato consumido

| Método e rota | Entrada | Sucesso | Erros |
|---|---|---|---|
| `GET /api/v1/campeonatos?pagina=0&tamanho=20` | query | 200 `PaginaResponse<CampeonatoResumoResponse>` | 400 |
| `POST /api/v1/campeonatos` | `CriarCampeonatoRequest` | 201 `CampeonatoResponse` | 400, 409 (limite do plano) |
| `GET /api/v1/campeonatos/{id}` | | 200 `CampeonatoResponse` | 404 |
| `DELETE /api/v1/campeonatos/{id}` | | 204 | 404, 409 |

Tipos em `features/campeonato/types.ts`, com nomes e campos idênticos:

```ts
type FormatoCampeonato = 'PONTOS_CORRIDOS' | 'MATA_MATA'
type StatusCampeonato = 'RASCUNHO' | 'EM_ANDAMENTO' | 'FINALIZADO'
type CriterioDesempate = 'PONTOS' | 'VITORIAS' | 'SALDO' | 'PRO' | 'CONFRONTO_DIRETO' | 'SORTEIO'
type TipoConfronto = 'JOGO_UNICO' | 'IDA_E_VOLTA' | 'SERIE'
type DesempateMataMata = 'GOLS_FORA' | 'PRORROGACAO' | 'PENALTIS' | 'SORTEIO'
type Seeding = 'ALEATORIO' | 'MANUAL' | 'CABECAS_DE_CHAVE'

interface ConfigPontosCorridosRequest {
  turnos: number
  pontosVitoria: number
  pontosEmpate: number
  pontosDerrota: number
  permiteEmpate: boolean
  criteriosDesempate: CriterioDesempate[]
}
interface ConfigMataMataRequest {
  tipoConfronto: TipoConfronto
  melhorDe: number | null
  desempates: DesempateMataMata[]
  seeding: Seeding
  disputaTerceiroLugar: boolean
}
interface CriarCampeonatoRequest {
  nome: string
  modalidade: string
  formato: FormatoCampeonato
  configPontosCorridos: ConfigPontosCorridosRequest | null
  configMataMata: ConfigMataMataRequest | null
}
// ConfigPontosCorridosResponse e ConfigMataMataResponse têm os mesmos campos.
interface CampeonatoResumoResponse {
  id: number
  nome: string
  modalidade: string
  slug: string
  formato: FormatoCampeonato
  status: StatusCampeonato
  publico: boolean
  totalParticipantes: number
  criadoEm: string
}
interface CampeonatoResponse extends CampeonatoResumoResponse {
  configPontosCorridos: ConfigPontosCorridosResponse | null
  configMataMata: ConfigMataMataResponse | null
}
```

O backend é estrito com tipos: número vai como número, nunca como texto. Campo vazio não vai como `""`, e o que é anulável vai como `null`.

## Requisitos

### Rotas

Dentro de `/app`, sob a guarda e o layout existentes:

- `/app`: lista de campeonatos (substitui o conteúdo atual de `PainelPage`).
- `/app/campeonatos/novo`: assistente.
- `/app/campeonatos/:id`: detalhe.

### Lista

- Cada item mostra nome, modalidade, formato, status, total de participantes e data de criação, e leva ao detalhe.
- Paginada com `Paginacao`, mantendo a página anterior visível ao trocar.
- Botão "Novo campeonato". Estados de loading, erro e vazio; o vazio convida a criar o primeiro.
- Rótulos em português: "Pontos corridos", "Mata-mata", "Rascunho", "Em andamento", "Finalizado". Status não depende só de cor.

### Assistente

Passos, com indicação de "Passo N de 4" e botões Voltar e Continuar. Voltar preserva o que foi preenchido. Os passos são estado local, não URL. Ao mudar de passo, o foco vai para o título do novo passo.

1. **Básico:** `nome` (2..120) e `modalidade` (2..60), com validação de UX contada depois de aparar os espaços. A modalidade é texto livre, com sugestões por `datalist`: Futebol, Futebol society, Xadrez, Esports.
2. **Formato:** escolha entre pontos corridos e mata-mata, com uma frase explicando cada um. Campo de opção real (`radio`), não um `div` clicável.
3. **Regras:** conforme o formato, já preenchidas com os padrões abaixo.
4. **Revisão:** resumo legível de tudo e botão "Criar campeonato". Durante o envio, o botão fica desabilitado com "Criando…", e não pode haver envio duplo. Sucesso vai para o detalhe, substituindo a entrada do histórico (`replace`).

**Padrões de pontos corridos:** `turnos` 1; pontos 3/1/0; empate permitido; critérios `PONTOS, VITORIAS, SALDO, PRO, CONFRONTO_DIRETO, SORTEIO`.

**Regras de pontos corridos (passo 3):**
- `turnos`: campo numérico, de 1 a 10, com a explicação "1 = só ida, 2 = ida e volta".
- Pontos: campos numéricos inteiros de 0 a 100.
- Empate não permitido esconde `pontosEmpate`, e o valor enviado é igual a `pontosDerrota`. O campo não se aplica nesse caso e o motor exige `vitória ≥ empate ≥ derrota`.
- Critérios: lista ordenada, com botões "Subir" e "Descer" operáveis por teclado, e um rótulo acessível que diz o critério (ex.: "Subir Saldo de gols"). Sem arrastar e soltar nem dependência nova.
  - `PONTOS` fica sempre em primeiro, fixo.
  - `SORTEIO` pode ser ligado ou desligado e fica sempre em último.
  - Os demais podem ser ligados, desligados e reordenados.
  - Rótulos: Pontos, Vitórias, Saldo de gols, Gols marcados, Confronto direto, Sorteio.
  - Explique em uma linha que, sem sorteio, participantes empatados em tudo dividem a posição.

**Padrões de mata-mata:** `JOGO_UNICO`, `melhorDe` nulo, desempate só `PENALTIS`, `ALEATORIO`, sem disputa de 3º lugar.

**Regras de mata-mata (passo 3):**
- Tipo de confronto: Jogo único, Ida e volta ou Série. Em Série, um `select` com "melhor de" 3, 5, 7, 9, 11, 13 ou 15 (padrão 3). Fora de Série, `melhorDe` vai `null`.
- Desempates: montados sem lista livre, sempre nesta ordem, gerando `desempates`:
  1. Gols fora: caixa de seleção, visível só em Ida e volta. Trocar o tipo de confronto a remove.
  2. Prorrogação: caixa de seleção.
  3. Decisão final, obrigatória: "Pênaltis" ou "Sorteio" (`radio`).
- Seeding: Sorteio (`ALEATORIO`), Definida por você (`MANUAL`) ou Cabeças de chave (`CABECAS_DE_CHAVE`), com uma frase explicando cada opção e avisando que a posição de cada participante é informada ao cadastrá-lo.
- Disputa de 3º lugar: caixa de seleção.

**Erros da API (no envio):**
- `erros[]` com `campo` conhecido: volta ao passo do campo e mostra o erro junto dele. Confira no teste contra o backend real quais nomes de `campo` chegam, inclusive os aninhados como `configPontosCorridos.turnos`.
- 400 sem `erros[]`, como o erro de config recusada pelo motor, e `campo` desconhecido: mostra o `detail` na revisão.
- 409 do limite do plano: mostra o `detail` na revisão, com link para a lista. O preenchido não se perde.

### Detalhe

- Nome, modalidade, formato, status, visibilidade (`publico`), total de participantes, data e as regras em texto legível, com os mesmos rótulos do assistente.
- Excluir só em `RASCUNHO`, com confirmação inline na própria página (botões "Confirmar exclusão" e "Cancelar"). Não use `window.confirm`. O 204 invalida a lista e volta a `/app`. O 409 mostra o `detail` e recarrega o campeonato, porque o status pode ter mudado.
- 404: mensagem "Campeonato não encontrado" com link para a lista, distinta do erro genérico.
- A seção de participantes e geração é da tarefa 08. Nesta tarefa, não coloque aviso de "em breve" na tela.

### Camadas

`features/campeonato/{types.ts,api/campeonatoApi.ts,hooks/,components/,pages/}`, com `campeonatoKeys`. Criar e excluir invalidam a lista. Os rótulos ficam num só módulo da feature. A tradução do estado do formulário para `CriarCampeonatoRequest` fica numa função pura, testada à parte.

### Herdado de tarefas anteriores (commits próprios)

1. `TZ=UTC` fixado nos testes, corrigindo os 3 testes de data que falham em UTC+9 ou mais. Prove rodando com `TZ=Asia/Tokyo`.
2. Unificar `semearSessao` (`test/fixtures.ts` e `guardas.test.tsx`).
3. Comentário em `App.test.tsx` explicando por que há um teste por arquivo com o App real.
4. `httpClient`: não mentir o tipo em corpo vazio. `http.delete` passa a devolver `Promise<void>`, e os demais continuam como estão se nenhuma rota usada hoje devolver corpo vazio. Registre a decisão no relatório.

## Testes obrigatórios (Vitest e Testing Library, API mockada)

- **Lista:** loading, erro, vazio, itens com rótulos em português, paginação, navegação ao detalhe.
- **Assistente:**
  - caminho feliz completo nos dois formatos, conferindo o **corpo exato** enviado com os padrões;
  - tradução: pontos com empate proibido; critérios reordenados e desligados; série com `melhorDe`; `melhorDe` nulo fora de série; gols fora só em ida e volta, e removido ao trocar o tipo; sorteio como decisão final; números como `number`, nunca texto;
  - validação de UX impede avançar, com texto de espaços, nome curto, número vazio ou fora do intervalo;
  - Voltar preserva os dados, também ao trocar de formato e voltar;
  - envio único com clique duplo;
  - 400 com `erros[]` volta ao passo certo; 400 sem `erros[]` e 409 mostram o `detail` na revisão sem perder nada.
- **Critérios:** subir e descer por teclado; primeiro e último nos limites; `PONTOS` fixo; `SORTEIO` sempre último.
- **Detalhe:** os dois formatos; 404; erro genérico; excluir só em rascunho; cancelar a confirmação; 204 volta à lista invalidada; 409 mostra o `detail`.
- **Guardas:** as rotas novas continuam exigindo `ORGANIZADOR`.

## Critérios de aceite

- [ ] Contrato acima exatamente, sem campo nem endpoint inventado.
- [ ] `npm run lint && npm test && npm run build` verde, também com `TZ=Asia/Tokyo` no `npm test`.
- [ ] **Teste contra o backend real** (fora do repositório): com o backend da branch atual de `backend/` em Postgres descartável (porta 55444) e a aplicação na 8080, envie por `curl`, com o proxy do Vite no caminho, os corpos produzidos pela função de tradução nos dois padrões e em ao menos uma variação de cada opção (empate proibido, série, ida e volta com gols fora, sorteio final, cada seeding). Todos precisam dar 201. Force também o 409 do limite e um 400 de campo aninhado, e leve os JSONs reais ao relatório. Remova o container e pare os processos pelo PID no fim. Não troque a branch de `backend/`.
- [ ] Layout funciona na largura de celular (360 px) e por teclado.

## Fora de escopo

Editar campeonato, participantes, geração, resultados, classificação, chave (08), alterar visibilidade (08), página pública (09), mostrar limite do plano antes do envio (não há endpoint).
