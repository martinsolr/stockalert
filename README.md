# StockAlert — Monitor de Estoque

Dashboard em português do Brasil para acompanhar produtos, níveis mínimos, movimentações e alertas automáticos via Telegram.

## Stack

- React + Vite + Tailwind
- Express + tRPC
- Drizzle ORM + MySQL gerenciado
- Telegram Bot API server-side
- Callback agendado `POST /api/scheduled/stock-check`

## Desenvolvimento

```bash
pnpm dev
pnpm check
pnpm test
pnpm build
```

O servidor usa `PORT` (padrão `3000`) e responde em `/api/health`.

## Configurar Telegram

1. No Telegram, abra `@BotFather`, use `/newbot` e copie o token.
2. Abra uma conversa com o bot criado e envie `/start`.
3. Descubra o `chat_id` usando `https://api.telegram.org/botSEU_TOKEN/getUpdates` ou um bot auxiliar.
4. Abra **Configurações** no StockAlert, informe token e chat ID, habilite os alertas e clique em **Testar conexão**.

O token não é retornado ao frontend e não fica em variáveis públicas. Para produção, proteja também o acesso ao painel com autenticação da sua hospedagem.

## Verificação automática

Depois de publicar a aplicação, crie uma tarefa agendada na hospedagem apontando para:

- Método: `POST`
- URL: `https://SEU-DOMINIO/api/scheduled/stock-check`
- Cron UTC: `0 */5 * * * *`

O endpoint usa a sessão de tarefa do ambiente e é idempotente: o mesmo produto não recebe alertas duplicados enquanto não voltar acima do estoque mínimo.

## Publicar no Marvel App

O Marvel App normalmente é usado para prototipar telas e não substitui um backend persistente. Use o código da pasta `client/` como base visual se o Marvel aceitar React/HTML, mas publique o projeto completo (frontend + backend) em uma hospedagem Node que ofereça banco e tarefas agendadas. Não cole tokens do Telegram no JavaScript do navegador.

## Evolução para WhatsApp

O MVP atende o requisito de alertas via Telegram. Para WhatsApp, acrescente a WhatsApp Business Cloud API da Meta ou um provedor oficial, com número empresarial e templates aprovados. A lógica de alerta já está isolada em `server/telegram.ts` para permitir um segundo adaptador.
