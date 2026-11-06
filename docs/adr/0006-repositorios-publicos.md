# ADR 0006: Repositórios públicos

- Data: 2026-11-06
- Status: aceita (decisão do Antonio)

## Contexto

A ADR 0001 criou os repositórios como privados. O Antonio quer mostrar o projeto no currículo, inclusive o fluxo de desenvolvimento com agentes, e um recrutador não consegue ver repositório privado.

## Decisão

- `Attonic/campzone-backend` e `Attonic/campzone-frontend` passam a ser públicos. O restante da ADR 0001 continua valendo (repos separados).
- O histórico mantém as datas reais dos commits. Não há reescrita para mudar datas.
- A raiz deixa de ser só local e vira o repo público `Attonic/campzone`, só com documentação e agentes. Isso substitui o "raiz sem git" da ADR 0001. Ela ignora `backend/` e `frontend/`, e o orquestrador commita direto na `main` dela.
- Sem o `gh` instalado, cada tarefa aprovada entra por merge local com `--no-ff` e push da `main`, com o OK do Antonio, em vez de PR. Quando o `gh` estiver disponível, volta o fluxo de PR do `CLAUDE.md`.

## Consequências

- Nada sensível pode entrar em nenhum commit: credenciais de produção só por variável de ambiente, `.env` fora do git (DoD item 5).
- As credenciais do `application-dev.yml` ficam públicas. Elas valem só para o ambiente local, e o perfil `prod` não sobe sem as próprias variáveis.
- O e-mail configurado nos commits fica visível.
- As tarefas publicadas sem `gh` não têm PR. O histórico delas fica nos merges, nas specs e no backlog.
- As branches empilhadas entraram com `--no-ff`, não com squash, porque o squash quebraria a pilha. Por isso o commit `073af88` da tarefa 01, que não compila sozinho, continua no histórico.
- O `scripts/setup-fedora.sh` ainda cria repos com `--private`; a tarefa 10 já prevê atualizá-lo.
