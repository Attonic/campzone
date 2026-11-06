# ADR 0004: Perfil explícito obrigatório (sem `spring.profiles.default`)

- Data: 2026-10-21
- Status: aceita (orquestrador, achado de segurança da revisão da tarefa 02; Antonio avisado)

## Contexto

Na tarefa 00, `spring.profiles.default: dev` foi adotado para que rodar na IDE "sem configurar nada" caísse no dev. Com a tarefa 02, o perfil dev passou a ter um segredo JWT versionado e um admin com senha pública. Assim, um deploy que esquecesse `SPRING_PROFILES_ACTIVE=prod` subiria sem erro, com tokens forjáveis e admin conhecido.

## Decisão

- Remover `spring.profiles.default`. Se nenhum perfil estiver ativo, a aplicação **não sobe** e mostra uma mensagem clara ("defina `SPRING_PROFILES_ACTIVE=dev` ou `prod`").
- Conveniência de dev preservada sem afetar o jar:
  - configuração de execução do IntelliJ versionada em `backend/.run/` com o perfil `dev`;
  - `./mvnw spring-boot:run` usa `dev` por padrão (configuração do plugin no `pom.xml`, que não vale para `java -jar`).
- Os testes declaram o perfil explicitamente.

## Consequências

- `java -jar` sem perfil falha rápido em qualquer ambiente, então não há como cair em dev por esquecimento.
- Quem abre o projeto no IntelliJ continua rodando com um clique, pela configuração compartilhada.
