import 'package:flutter/material.dart';

import '../models/models.dart';

class StockColors {
  static const navy = Color(0xFF15253A);
  static const ink = Color(0xFF24344A);
  static const blue = Color(0xFF2F5BFF);
  static const lime = Color(0xFFB9E769);
  static const cream = Color(0xFFF6F4EE);
  static const surface = Color(0xFFFFFEFA);
  static const line = Color(0xFFE7E5DD);
  static const muted = Color(0xFF7A8491);
  static const coral = Color(0xFFEF6A5B);
  static const amber = Color(0xFFE4A74B);
  static const softBlue = Color(0xFFE9EEFF);
  static const softCoral = Color(0xFFFCE9E5);
  static const softAmber = Color(0xFFFFF4DC);
  static const softLime = Color(0xFFEDF7D8);
}

ThemeData buildStockTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: StockColors.cream,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: StockColors.blue,
        brightness: Brightness.light,
      ).copyWith(
        primary: StockColors.blue,
        surface: StockColors.surface,
        onSurface: StockColors.ink,
      ),
  appBarTheme: const AppBarTheme(
    backgroundColor: StockColors.cream,
    foregroundColor: StockColors.navy,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: StockColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: StockColors.line),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFFCFBF7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: StockColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: StockColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: StockColors.blue, width: 1.5),
    ),
    labelStyle: const TextStyle(color: StockColors.muted, fontSize: 13),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: StockColors.surface,
    indicatorColor: StockColors.softBlue,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  ),
);

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 34 : 38,
        height: compact ? 34 : 38,
        decoration: BoxDecoration(
          color: StockColors.navy,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.inventory_2_rounded,
          color: StockColors.lime,
          size: 20,
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 9),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: StockColors.navy,
              letterSpacing: -0.7,
            ),
            children: [
              TextSpan(text: 'Stock'),
              TextSpan(
                text: 'Alert',
                style: TextStyle(color: StockColors.blue),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final (
      label,
      color,
      background,
      icon,
    ) = product.status == ProductStatus.paused
        ? (
            'Pausado',
            StockColors.muted,
            const Color(0xFFEEF0F3),
            Icons.pause_circle_outline,
          )
        : product.isOutOfStock
        ? (
            'Sem estoque',
            StockColors.coral,
            StockColors.softCoral,
            Icons.warning_amber_rounded,
          )
        : product.isCritical
        ? (
            'Repor agora',
            const Color(0xFF9A6C21),
            StockColors.softAmber,
            Icons.trending_down_rounded,
          )
        : (
            'Saudável',
            const Color(0xFF62852F),
            StockColors.softLime,
            Icons.check_circle_outline,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.background = StockColors.surface,
    this.valueColor = StockColors.navy,
    this.iconColor = StockColors.blue,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color background;
  final Color valueColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Card(
    color: background,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: StockColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            style: const TextStyle(color: StockColors.muted, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onAdjust,
    this.onEdit,
    this.onDelete,
  });

  final Product product;
  final VoidCallback onAdjust;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(13),
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
              Icons.inventory_2_outlined,
              color: StockColors.blue,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StockColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${product.sku} · ${product.category}',
                  style: const TextStyle(
                    color: StockColors.muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.stock}',
                style: TextStyle(
                  color: product.isCritical
                      ? StockColors.coral
                      : StockColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'mín. ${product.minimumStock}',
                style: const TextStyle(color: StockColors.muted, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(width: 7),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: StockColors.muted),
            onSelected: (value) {
              if (value == 'adjust') onAdjust();
              if (value == 'edit') onEdit?.call();
              if (value == 'delete') onDelete?.call();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'adjust', child: Text('Ajustar estoque')),
              PopupMenuItem(value: 'edit', child: Text('Editar produto')),
              PopupMenuItem(value: 'delete', child: Text('Excluir produto')),
            ],
          ),
        ],
      ),
    ),
  );
}
