# StockAlert Mobile — direção visual e fluxos

## Direção
Aplicativo operacional para uso com uma mão: navy profundo, azul elétrico, verde-lima e creme quente. Cards de alto contraste, tipografia nativa legível, navegação inferior e ações de ajuste sempre a um toque.

## Telas
- **Visão geral:** saudação, KPIs de total, crítico, sem estoque e última verificação; lista de itens que pedem atenção; atividade de alertas.
- **Produtos:** catálogo em cards, busca visual, status e menu com ajustar/editar/excluir; formulário em bottom sheet.
- **Alertas:** estado do Telegram, verificação manual e últimas ocorrências integradas à visão geral.
- **Configurações:** token mascarado no servidor, chat ID, frequência, ativação, teste de conexão e orientação de configuração.

## Fluxos
1. Abrir app → carregar dashboard do backend → mostrar fallback de demonstração se o servidor estiver indisponível.
2. Produtos → Novo produto → preencher nome/SKU/categoria/estoque/mínimo → salvar.
3. Produto crítico → menu → Ajustar estoque → informar quantidade e motivo → confirmar → atualizar dashboard.
4. Configurações → token/chat ID → testar conexão → ativar alertas → salvar.
5. Verificar agora → backend deduplica alertas em aberto → envia Telegram somente quando há configuração válida.

## Responsividade
O layout usa cards fluidos, `NavigationBar`, `SafeArea`, `RefreshIndicator` e bottom sheets, com alvo mínimo de toque de 44 px. A interface prioritária é portrait mobile.
