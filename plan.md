# Plano de implementação — StockAlert

## Objetivo
Construir um dashboard web responsivo, em português do Brasil, para acompanhar o estoque de uma loja/empresa. O MVP terá cadastro de produtos, ajuste de estoque, histórico de movimentações, dashboard operacional, alertas de estoque crítico e envio de notificações via Telegram Bot API.

## Decisão de arquitetura

| Abordagem | Tradeoffs | Custo | Complexidade |
| --- | --- | --- | --- |
| Dashboard web + backend com banco gerenciado + verificação agendada | Permite cadastrar produtos, editar limites, persistir histórico e enviar alertas sem manter o navegador aberto. Exige configurar token/chat do Telegram e publicar o backend. | Baixo; usa a infraestrutura gerenciada do projeto e a API gratuita do Telegram | Média |
| Planilha + script de verificação + bot Telegram | Mais rápido para um piloto pequeno, mas sem dashboard completo, controle de usuários ou histórico rico; manutenção fica espalhada entre planilha e script. | Baixo, mas depende de uma planilha e de hospedagem do script | Baixa/média |

Este projeto implementa a primeira opção porque o pedido inclui gestão contínua de produtos e parâmetros. O canal inicial é Telegram, que atende um dos requisitos pedidos e possui Bot API oficial com envio de mensagens e webhooks/callbacks documentados.

## Estrutura e responsabilidades
- `client/src/App.tsx`: shell da aplicação e estado principal da dashboard.
- `client/src/index.css`: tokens visuais, responsividade e componentes de layout.
- `drizzle/schema.ts`: tabelas de produtos, movimentações, alertas e configuração do Telegram.
- `server/inventory.ts`: acesso ao banco, dados demo, regras de estoque e deduplicação de alertas.
- `server/telegram.ts`: cliente server-side da Telegram Bot API; token nunca é devolvido ao frontend.
- `server/routers.ts`: procedimentos tRPC validados para dashboard, CRUD, ajustes e configurações.
- `server/_core/index.ts`: healthcheck, tRPC e callback `POST /api/scheduled/stock-check`.
- `drizzle/`: migração versionada do schema.

## Modelo de dados
- `products`: nome, SKU, categoria, estoque atual, estoque mínimo e status ativo/pausado.
- `stockMovements`: variação, estoque após a operação, motivo e horário.
- `inventoryAlerts`: produto, severidade, mensagem, estado enviado/falhou, horário e `resolvedAt`. Um alerta ativo por produto é mantido até que o estoque seja reposto acima do mínimo.
- `notificationSettings`: configuração singleton para Telegram, frequência e último check; o bot token é armazenado somente no servidor.

## Fluxos principais
1. Ao abrir a aplicação, `dashboard.summary` garante dados de demonstração se o banco estiver vazio e retorna KPIs, alertas e produtos críticos.
2. Criar/editar/excluir produto usa validação Zod no procedimento tRPC.
3. Ajustar estoque calcula a nova quantidade, registra `stockMovements`, resolve alertas quando há reposição e cria um alerta ativo quando a quantidade fica crítica.
4. `checkStockAndNotify` verifica produtos críticos, cria alertas idempotentes e tenta enviar cada alerta pelo Telegram. Alertas já ativos não são reenviados automaticamente.
5. `POST /api/scheduled/stock-check` exige a sessão de tarefa agendada do ambiente e chama a mesma rotina de verificação. O endpoint é idempotente para tolerar retries.
6. A tela Configurações permite salvar chat ID, frequência e token sem retornar o token; o botão de teste usa o backend e mostra somente sucesso/erro.

## Servir e publicar
O frontend é uma SPA renderizada no navegador e o backend Express atende `/api/*` e `/api/trpc`. O frontend obtém dados dinâmicos via tRPC. Assets versionados podem usar cache longo; APIs, configurações e dashboard devem ser `private, no-store`. O container usa o `Dockerfile` existente, inicia `dist/index.js` e responde em `/api/health`.

A rota publicada será: `/api/*` para o servidor e `/*` para os arquivos estáticos com fallback SPA. O callback do scheduler fica em `/api/scheduled/stock-check`.

## Configuração externa
- Criar um bot com `@BotFather` e copiar o token nas Configurações do StockAlert.
- Enviar `/start` ao bot e informar o `chat_id` correspondente.
- Publicar o app antes de registrar a tarefa agendada.
- Registrar uma tarefa de 5 em 5 minutos (cron UTC: `0 */5 * * * *`) apontando para `POST /api/scheduled/stock-check`. A frequência exibida na aplicação documenta a intenção; a tarefa é registrada na plataforma de publicação.
- WhatsApp fica como evolução: requer Meta WhatsApp Business Cloud API ou provedor oficial e templates aprovados; não será incluído no MVP para evitar credenciais e aprovação específicas.

## Verificação
- `pnpm check` para tipos.
- `pnpm test` para a suíte existente.
- `pnpm build` para validar Vite + bundle Express.
- Healthcheck local em `/api/health` e endpoint tRPC no servidor em execução.
- Revisão de código: contratos frontend/backend, deduplicação de alerta, segredo fora do cliente, layout responsivo e rotas do container.
