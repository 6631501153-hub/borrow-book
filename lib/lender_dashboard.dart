import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/main.dart';

/// Lender dashboard showing totals and status counts.
/// Uses public.asset(status) where status is an enum asset_status with
/// values like 'available', 'borrowed', 'pending', 'disabled'.
class LenderDashboardPage extends StatefulWidget {
  const LenderDashboardPage({super.key});
  @override
  State<LenderDashboardPage> createState() => _LenderDashboardPageState();
}

class _LenderDashboardPageState extends State<LenderDashboardPage> {
  bool _loading = true;
  String? _error;

  int total = 0, available = 0, borrowed = 0, pending = 0, disabled = 0;

  // Your real table + status column
  static const String _table = 'asset';
  static const String _statusColumn = 'status';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _fetchCounts();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int> _countAll() async {
    final List<dynamic> rows = await supabase.from(_table).select('id');
    return rows.length;
  }

  Future<int> _countWhereStatus(String status) async {
    // Try case-insensitive first; fall back to exact match if ilike unsupported
    try {
      final List<dynamic> rows = await supabase
          .from(_table)
          .select('id')
          .ilike(_statusColumn, status);
      return rows.length;
    } catch (_) {
      final List<dynamic> rows = await supabase
          .from(_table)
          .select('id')
          .eq(_statusColumn, status);
      return rows.length;
    }
  }

  Future<void> _fetchCounts() async {
    final r = await Future.wait<int>([
      _countAll(),
      _countWhereStatus('available'),
      _countWhereStatus('borrowed'),
      _countWhereStatus('pending'),
      _countWhereStatus('disabled'),
    ]);
    total = r[0];
    available = r[1];
    borrowed = r[2];
    pending = r[3];
    disabled = r[4];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Dashboard',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _loading
                  ? _SkeletonHeader()
                  : _error != null
                      ? _ErrorBox(message: _error!, onRetry: _refresh)
                      : _TotalCard(total: total),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _loading
                  ? const _SkeletonGrid()
                  : _StatsGrid(
                      borrowed: borrowed,
                      available: available,
                      pending: pending,
                      disabled: disabled,
                    ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// ==== UI bits ====
class _TotalCard extends StatelessWidget {
  final int total;
  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1E3A8A), width: 2),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'total book : $total',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B2C66),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int borrowed, available, pending, disabled;
  const _StatsGrid({
    required this.borrowed,
    required this.available,
    required this.pending,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 16,
      spacing: 16,
      children: [
        _StatCard(
          title: 'borrowed',
          value: borrowed,
          bg: const Color(0xFF3B82F6), // blue
          textOnDark: true,
        ),
        _StatCard(
          title: 'avaliable', // matches mock spelling
          value: available,
          bg: const Color(0xFF4CAF50), // green
          textOnDark: true,
        ),
        _StatCard(
          title: 'pending',
          value: pending,
          bg: const Color(0xFFF4C43A), // yellow
          textOnDark: false,
        ),
        _StatCard(
          title: 'disable',
          value: disabled,
          bg: const Color(0xFFE24B45), // red
          textOnDark: true,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final Color bg;
  final bool textOnDark;

  const _StatCard({
    required this.title,
    required this.value,
    required this.bg,
    required this.textOnDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = textOnDark ? Colors.white : Colors.black87;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: c,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                color: c,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Failed to load dashboard',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SkeletonHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid({super.key});
  @override
  Widget build(BuildContext context) {
    Widget box() => Container(
          width: 160,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(16),
          ),
        );
    return Wrap(spacing: 16, runSpacing: 16, children: [box(), box(), box(), box()]);
  }
}