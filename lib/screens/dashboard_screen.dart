import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/stock_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  bool _loading = true;
  bool _checking = false;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _data == null);
    try {
      final next = await widget.api.fetchDashboard();
      if (!mounted) return;
      setState(() {
        _data = next;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _data ??= demoDashboard();
        _error = 'Modo demonstração: servidor indisponível';
        _loading = false;
      });
    }
  }

  Future<void> _checkAlerts() async {
    setState(() => _checking = true);
    try {
      final result = await widget.api.checkAlerts();
      if (mounted)
        _showMessage(
          '${result.checked} produtos verificados · ${result.created} alertas novos',
        );
      await _load();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

  Future<void> _openProductForm({Product? product}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: StockColors.surface,
      builder: (_) => ProductFormSheet(api: widget.api, product: product),
    );
    if (saved == true) await _load();
  }

  Future<void> _adjustProduct(Product product) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: StockColors.surface,
      builder: (_) => AdjustStockSheet(api: widget.api, product: product),
    );
    if (changed == true) await _load();
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text('O histórico de ${product.name} também será removido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteProduct(product.id);
      await _load();
      if (mounted) _showMessage('Produto excluído.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(),
        actions: [
          if (_error != null)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.cloud_off_outlined,
                color: StockColors.amber,
                size: 18,
              ),
            ),
          IconButton(
            tooltip: 'Configurações',
            onPressed: () => setState(() => _tab = 2),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading && data == null
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: [
                OverviewTab(
                  data: data ?? demoDashboard(),
                  checking: _checking,
                  onRefresh: _load,
                  onCheck: _checkAlerts,
                  onOpenProducts: () => setState(() => _tab = 1),
                  onAdjust: _adjustProduct,
                  onOpenSettings: () => setState(() => _tab = 2),
                ),
                ProductsTab(
                  data: data ?? demoDashboard(),
                  onRefresh: _load,
                  onAdd: () => _openProductForm(),
                  onEdit: (product) => _openProductForm(product: product),
                  onAdjust: _adjustProduct,
                  onDelete: _deleteProduct,
                ),
                SettingsTab(
                  api: widget.api,
                  settings: data?.settings ?? demoDashboard().settings,
                  onSaved: _load,
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Visão geral',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Produtos',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Configurar',
          ),
        ],
      ),
    );
  }
}

class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.data,
    required this.checking,
    required this.onRefresh,
    required this.onCheck,
    required this.onOpenProducts,
    required this.onAdjust,
    required this.onOpenSettings,
  });

  final DashboardData data;
  final bool checking;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCheck;
  final VoidCallback onOpenProducts;
  final void Function(Product product) onAdjust;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'BOM DIA, OPERAÇÃO',
          style: TextStyle(
            color: StockColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Estoque sob controle.',
          style: TextStyle(
            color: StockColors.navy,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Uma visão rápida do que precisa da sua atenção hoje.',
          style: TextStyle(color: StockColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'Produtos',
                value: '${data.products.length}',
                caption: 'Catálogo ativo',
                icon: Icons.inventory_2_outlined,
                background: StockColors.navy,
                valueColor: Colors.white,
                iconColor: StockColors.lime,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                label: 'Crítico',
                value: '${data.criticalProducts}',
                caption: data.criticalProducts == 0
                    ? 'Tudo no limite'
                    : 'Pede atenção',
                icon: Icons.trending_down_rounded,
                background: StockColors.softAmber,
                iconColor: StockColors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                label: 'Sem estoque',
                value: '${data.outOfStock}',
                caption: data.outOfStock == 0
                    ? 'Nenhuma ruptura'
                    : 'Itens parados',
                icon: Icons.warning_amber_rounded,
                iconColor: StockColors.coral,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                label: 'Verificação',
                value: data.settings.lastCheckAt == null
                    ? '—'
                    : DateFormat('HH:mm')
                          .format(data.settings.lastCheckAt!.toLocal()),
                caption: data.settings.enabled
                    ? 'Atualização automática'
                    : 'Manual disponível',
                icon: Icons.schedule_outlined,
                iconColor: const Color(0xFF77A53C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Atenção necessária',
              style: TextStyle(
                color: StockColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -.4,
              ),
            ),
            TextButton(
              onPressed: onOpenProducts,
              child: const Text('Ver todos'),
            ),
          ],
        ),
        if (data.critical.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 34,
                    color: Color(0xFF76A93C),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Operação saudável',
                    style: TextStyle(
                      color: StockColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Nenhum produto abaixo do mínimo.',
                    style: TextStyle(color: StockColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ...data.critical
              .take(4)
              .map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ProductTile(
                    product: product,
                    onAdjust: () => onAdjust(product),
                  ),
                ),
              ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: StockColors.softBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: StockColors.blue,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verificação de alertas',
                        style: TextStyle(
                          color: StockColors.navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Confira os limites agora e notifique o Telegram.',
                        style: TextStyle(
                          color: StockColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: checking ? null : onCheck,
                  child: checking
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verificar'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Alertas recentes',
              style: TextStyle(
                color: StockColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -.4,
              ),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Telegram'),
            ),
          ],
        ),
        if (data.alerts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF76A93C),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Nenhum alerta aberto.',
                    style: TextStyle(color: StockColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ...data.alerts
              .take(4)
              .map(
                (alert) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: StockColors.softCoral,
                      child: Icon(
                        Icons.priority_high_rounded,
                        color: StockColors.coral,
                        size: 17,
                      ),
                    ),
                    title: Text(
                      alert.productName,
                      style: const TextStyle(
                        color: StockColors.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      alert.stock == 0
                          ? 'Sem estoque disponível'
                          : '${alert.stock} un. disponíveis · mínimo ${alert.minimumStock}',
                      style: const TextStyle(
                        color: StockColors.muted,
                        fontSize: 10,
                      ),
                    ),
                    trailing: Text(
                      DateFormat('dd/MM HH:mm')
                          .format(alert.createdAt.toLocal()),
                      style: const TextStyle(
                        color: StockColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ),
      ],
    ),
  );
}

class ProductsTab extends StatefulWidget {
  const ProductsTab({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onAdjust,
    required this.onDelete,
  });

  final DashboardData data;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final void Function(Product product) onEdit;
  final void Function(Product product) onAdjust;
  final void Function(Product product) onDelete;

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final products = widget.data.products
        .where(
          (p) => '${p.name} ${p.sku} ${p.category}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CATÁLOGO OPERACIONAL',
                    style: TextStyle(
                      color: StockColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Produtos.',
                    style: TextStyle(
                      color: StockColors.navy,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Novo'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Cadastre itens e acompanhe os níveis mínimos.',
            style: TextStyle(color: StockColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 17),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar produto, SKU ou categoria',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${products.length} produto(s)',
            style: const TextStyle(
              color: StockColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (products.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Nenhum produto encontrado.')),
              ),
            )
          else
            ...products.map(
              (product) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ProductTile(
                  product: product,
                  onAdjust: () => widget.onAdjust(product),
                  onEdit: () => widget.onEdit(product),
                  onDelete: () => widget.onDelete(product),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({super.key, required this.api, this.product});

  final ApiService api;
  final Product? product;

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  late final TextEditingController name = TextEditingController(
    text: widget.product?.name ?? '',
  );
  late final TextEditingController sku = TextEditingController(
    text: widget.product?.sku ?? '',
  );
  late final TextEditingController category = TextEditingController(
    text: widget.product?.category ?? 'Mercearia',
  );
  late final TextEditingController stock = TextEditingController(
    text: '${widget.product?.stock ?? 0}',
  );
  late final TextEditingController minimum = TextEditingController(
    text: '${widget.product?.minimumStock ?? 5}',
  );
  ProductStatus status = ProductStatus.active;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    status = widget.product?.status ?? ProductStatus.active;
  }

  @override
  void dispose() {
    name.dispose();
    sku.dispose();
    category.dispose();
    stock.dispose();
    minimum.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().length < 2 || sku.text.trim().length < 2) return;
    setState(() => saving = true);
    try {
      if (widget.product == null) {
        await widget.api.createProduct(
          name: name.text.trim(),
          sku: sku.text.trim().toUpperCase(),
          category: category.text.trim(),
          stock: int.tryParse(stock.text) ?? 0,
          minimumStock: int.tryParse(minimum.text) ?? 0,
          status: status,
        );
      } else {
        await widget.api.updateProduct(
          widget.product!.copyWith(
            name: name.text.trim(),
            sku: sku.text.trim().toUpperCase(),
            category: category.text.trim(),
            stock: int.tryParse(stock.text) ?? 0,
            minimumStock: int.tryParse(minimum.text) ?? 0,
            status: status,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Text(
          widget.product == null ? 'Adicionar produto' : 'Editar produto',
          style: const TextStyle(
            color: StockColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Defina o nível mínimo para receber alertas.',
          style: TextStyle(color: StockColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nome do produto'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: sku,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'SKU'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: category,
          decoration: const InputDecoration(labelText: 'Categoria'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Estoque atual'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: minimum,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Estoque mínimo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ProductStatus>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: const [
            DropdownMenuItem(value: ProductStatus.active, child: Text('Ativo')),
            DropdownMenuItem(
              value: ProductStatus.paused,
              child: Text('Pausado'),
            ),
          ],
          onChanged: (value) =>
              setState(() => status = value ?? ProductStatus.active),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving
                ? 'Salvando…'
                : widget.product == null
                ? 'Adicionar produto'
                : 'Salvar alterações',
          ),
        ),
      ],
    ),
  );
}

class AdjustStockSheet extends StatefulWidget {
  const AdjustStockSheet({super.key, required this.api, required this.product});

  final ApiService api;
  final Product product;

  @override
  State<AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends State<AdjustStockSheet> {
  final reason = TextEditingController(text: 'Reposição');
  int amount = 1;
  bool saving = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> save(int change) async {
    setState(() => saving = true);
    try {
      await widget.api.adjustStock(
        id: widget.product.id,
        change: change,
        reason: reason.text.trim().isEmpty
            ? 'Ajuste manual'
            : reason.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        const Text(
          'Ajustar estoque',
          style: TextStyle(
            color: StockColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${widget.product.name} · estoque atual ${widget.product.stock}',
          style: const TextStyle(color: StockColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: () =>
                  setState(() => amount = amount > 1 ? amount - 1 : 1),
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                '$amount',
                style: const TextStyle(
                  color: StockColors.navy,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => setState(() => amount++),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : () => save(-amount),
                child: const Text('− Remover'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: saving ? null : () => save(amount),
                child: const Text('+ Adicionar'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.api,
    required this.settings,
    required this.onSaved,
  });

  final ApiService api;
  final NotificationSettings settings;
  final Future<void> Function() onSaved;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final TextEditingController token = TextEditingController();
  late final TextEditingController chatId = TextEditingController(
    text: widget.settings.chatId ?? '',
  );
  late bool enabled = widget.settings.enabled;
  late int frequency = widget.settings.frequencyMinutes;
  bool saving = false;
  bool testing = false;

  @override
  void didUpdateWidget(covariant SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.chatId != widget.settings.chatId)
      chatId.text = widget.settings.chatId ?? '';
    enabled = widget.settings.enabled;
    frequency = widget.settings.frequencyMinutes;
  }

  @override
  void dispose() {
    token.dispose();
    chatId.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.api.saveSettings(
        token: token.text,
        chatId: chatId.text,
        enabled: enabled,
        frequencyMinutes: frequency,
      );
      token.clear();
      await widget.onSaved();
      if (mounted) _message('Configurações salvas.');
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> test() async {
    if (token.text.trim().isEmpty || chatId.text.trim().isEmpty) {
      _message('Informe token e chat ID para testar.');
      return;
    }
    setState(() => testing = true);
    try {
      await widget.api.testTelegram(token: token.text, chatId: chatId.text);
      if (mounted) _message('Mensagem de teste enviada no Telegram.');
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      const Text(
        'OPERAÇÃO',
        style: TextStyle(
          color: StockColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Configurações.',
        style: TextStyle(
          color: StockColors.navy,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Conecte o Telegram para ser avisado antes de uma ruptura.',
        style: TextStyle(color: StockColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: StockColors.softLime,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.send_rounded, color: Color(0xFF62852F)),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telegram Bot API',
                      style: TextStyle(
                        color: StockColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Token protegido no backend',
                      style: TextStyle(color: StockColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Icon(
                widget.settings.tokenConfigured
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: widget.settings.tokenConfigured
                    ? const Color(0xFF76A93C)
                    : StockColors.amber,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: token,
        obscureText: true,
        decoration: InputDecoration(
          labelText: widget.settings.tokenConfigured
              ? 'Novo token (opcional)'
              : 'Token do bot',
          hintText: widget.settings.tokenConfigured
              ? 'Deixe vazio para manter'
              : '123456:ABC…',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: chatId,
        decoration: const InputDecoration(
          labelText: 'Chat ID',
          hintText: '-1001234567890',
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
        initialValue: frequency,
        decoration: const InputDecoration(
          labelText: 'Frequência de verificação',
        ),
        items: const [
          DropdownMenuItem(value: 1, child: Text('A cada 1 minuto')),
          DropdownMenuItem(value: 5, child: Text('A cada 5 minutos')),
          DropdownMenuItem(value: 15, child: Text('A cada 15 minutos')),
          DropdownMenuItem(value: 60, child: Text('A cada 1 hora')),
        ],
        onChanged: (value) => setState(() => frequency = value ?? 5),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Alertas ativos',
          style: TextStyle(
            color: StockColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'Enviar quando um item atingir o mínimo',
          style: TextStyle(color: StockColors.muted, fontSize: 11),
        ),
        value: enabled,
        onChanged: (value) => setState(() => enabled = value),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: testing ? null : test,
        icon: testing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.send_outlined, size: 17),
        label: Text(testing ? 'Testando…' : 'Testar conexão'),
      ),
      const SizedBox(height: 10),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Salvando…' : 'Salvar configurações'),
      ),
      const SizedBox(height: 16),
      Card(
        color: StockColors.softBlue,
        child: const Padding(
          padding: EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: StockColors.blue, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Crie um bot no @BotFather, adicione-o ao canal ou grupo e use o chat ID correspondente. O token nunca é exibido novamente.',
                  style: TextStyle(
                    color: Color(0xFF667B9C),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

DashboardData demoDashboard() {
  final now = DateTime.now();
  const products = [
    Product(
      id: 1,
      name: 'Café especial 250g',
      sku: 'CAF-250',
      category: 'Mercearia',
      stock: 6,
      minimumStock: 10,
      status: ProductStatus.active,
    ),
    Product(
      id: 2,
      name: 'Leite integral 1L',
      sku: 'LEI-1L',
      category: 'Laticínios',
      stock: 24,
      minimumStock: 12,
      status: ProductStatus.active,
    ),
    Product(
      id: 3,
      name: 'Biscoito de aveia',
      sku: 'BIS-AVE',
      category: 'Mercearia',
      stock: 8,
      minimumStock: 8,
      status: ProductStatus.active,
    ),
    Product(
      id: 4,
      name: 'Sabonete líquido 300ml',
      sku: 'SAB-300',
      category: 'Higiene',
      stock: 42,
      minimumStock: 15,
      status: ProductStatus.active,
    ),
    Product(
      id: 5,
      name: 'Água mineral 500ml',
      sku: 'AGU-500',
      category: 'Bebidas',
      stock: 0,
      minimumStock: 20,
      status: ProductStatus.active,
    ),
  ];
  return DashboardData(
    products: products,
    alerts: [
      InventoryAlert(
        id: 1,
        productId: 5,
        productName: 'Água mineral 500ml',
        sku: 'AGU-500',
        stock: 0,
        minimumStock: 20,
        message: 'Sem estoque',
        status: 'open',
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
    ],
    settings: const NotificationSettings(
      enabled: false,
      frequencyMinutes: 5,
      chatId: null,
      tokenConfigured: false,
      maskedToken: null,
      lastCheckAt: null,
    ),
  );
}
