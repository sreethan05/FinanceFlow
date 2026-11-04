import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/finance_api.dart';
import 'product_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.onLogout});
  final FinanceApi api;
  final VoidCallback onLogout;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _budgets = [];
  List<Map<String, dynamic>> _goals = [];
  String _search = '';
  String _typeFilter = 'ALL';
  String _currency = 'INR';
  NumberFormat get _money => NumberFormat.currency(
      locale: 'en_IN',
      name: _currency,
      symbol: {
        'INR': '₹',
        'USD': '\$',
        'EUR': '€',
        'GBP': '£',
        'CAD': 'C\$',
        'AUD': 'A\$'
      }[_currency],
      decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        widget.api.dashboard(),
        widget.api.transactions(),
        widget.api.budgets(),
        widget.api.savingsGoals(),
        widget.api.profile()
      ]);
      if (!mounted) return;
      setState(() {
        _summary = values[0] as Map<String, dynamic>;
        _transactions = values[1] as List<Map<String, dynamic>>;
        _budgets = values[2] as List<Map<String, dynamic>>;
        _goals = values[3] as List<Map<String, dynamic>>;
        _currency =
            '${(values[4] as Map<String, dynamic>)['currency'] ?? 'INR'}';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is FinanceApiException
            ? error.message
            : 'Could not load your finances. Pull to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: const Color(0xFF126B52),
                    borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            const Text('FinanceFlow',
                style: TextStyle(fontWeight: FontWeight.w700))
          ]),
          actions: [
            IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => NotificationsScreen(api: widget.api))),
                icon: const Icon(Icons.notifications_none_rounded)),
            const SizedBox(width: 6)
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: IndexedStack(index: _tab, children: [
                      _overview(),
                      _transactionList(),
                      _planning(),
                      AnalyticsScreen(api: widget.api),
                      ProfileScreen(
                          api: widget.api, onLogout: _logout, onSaved: _load)
                    ])),
        floatingActionButton: _tab == 1
            ? FloatingActionButton.extended(
                onPressed: _addTransaction,
                icon: const Icon(Icons.add),
                label: const Text('Add transaction'))
            : null,
        bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() => _tab = value),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Activity'),
              NavigationDestination(
                  icon: Icon(Icons.track_changes_outlined),
                  selectedIcon: Icon(Icons.track_changes),
                  label: 'Plans'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Analytics'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile')
            ]),
      );

  Widget _overview() =>
      ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 100), children: [
        Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        const Text('Your money, in focus.',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        _BalanceCard(summary: _summary, money: _money),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _MetricCard(
                  title: 'Income',
                  value: _amount(['totalIncome', 'income'], _summary),
                  icon: Icons.south_west_rounded,
                  color: const Color(0xFF147A57))),
          const SizedBox(width: 12),
          Expanded(
              child: _MetricCard(
                  title: 'Expenses',
                  value: _amount(['totalExpenses', 'expenses'], _summary),
                  icon: Icons.north_east_rounded,
                  color: const Color(0xFFBA5947)))
        ]),
        const SizedBox(height: 24),
        _sectionHeader('Recent activity',
            onTap: () => setState(() => _tab = 1)),
        const SizedBox(height: 8),
        if (_transactions.isEmpty)
          const _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              message: 'Add your first transaction to see your cash flow here.')
        else
          ..._transactions.take(5).map(_transactionTile),
      ]);

  Widget _transactionList() {
    final filtered = _transactions.where((item) {
      final matchesType = _typeFilter == 'ALL' || item['type'] == _typeFilter;
      final category =
          item['category'] is Map ? '${(item['category'] as Map)['name']}' : '';
      final query = _search.toLowerCase();
      return matchesType &&
          (query.isEmpty ||
              '${item['description']} $category'.toLowerCase().contains(query));
    }).toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
        children: [
          const Text('Activity',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
              decoration: const InputDecoration(
                  hintText: 'Search transactions',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _search = v)),
          const SizedBox(height: 10),
          SegmentedButton<String>(segments: const [
            ButtonSegment(value: 'ALL', label: Text('All')),
            ButtonSegment(value: 'INCOME', label: Text('Income')),
            ButtonSegment(value: 'EXPENSE', label: Text('Expenses'))
          ], selected: {
            _typeFilter
          }, onSelectionChanged: (v) => setState(() => _typeFilter = v.first)),
          const SizedBox(height: 12),
          if (_transactions.isEmpty)
            const _EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Your activity will appear here',
                message: 'Add income or expenses to begin tracking.')
          else if (filtered.isEmpty)
            const _EmptyState(
                icon: Icons.search_off,
                title: 'No matching transactions',
                message: 'Try another search or filter.')
          else
            ...filtered.map(_transactionTile)
        ]);
  }

  Widget _planning() =>
      ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
        const Text('Your plans',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('MONTHLY BUDGETS',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF66736A))),
          TextButton.icon(
              onPressed: _addBudget,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New'))
        ]),
        const SizedBox(height: 4),
        if (_budgets.isEmpty)
          const _EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'No budgets set',
              message: 'Plan a monthly limit for each spending category.')
        else
          ..._budgets.map(_budgetTile),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('SAVINGS GOALS',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF66736A))),
          TextButton.icon(
              onPressed: _addGoal,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New'))
        ]),
        const SizedBox(height: 4),
        if (_goals.isEmpty)
          const _EmptyState(
              icon: Icons.flag_outlined,
              title: 'No savings goals yet',
              message: 'Create a goal to keep a milestone in view.')
        else
          ..._goals.map(_goalTile)
      ]);

  Widget _transactionTile(Map<String, dynamic> item) {
    final category = item['category'] is Map
        ? (item['category'] as Map)['name']
        : 'Transaction';
    final isIncome = item['type'] == 'INCOME';
    final amount = _number(item['amount']);
    final date =
        DateTime.tryParse('${item['transactionDate'] ?? ''}')?.toLocal();
    return Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
            onTap: () => _transactionActions(item),
            leading: CircleAvatar(
                backgroundColor: isIncome
                    ? const Color(0xFFE4F3EB)
                    : const Color(0xFFF9E9E5),
                child: Icon(isIncome ? Icons.south_west : Icons.north_east,
                    color: isIncome
                        ? const Color(0xFF147A57)
                        : const Color(0xFFBA5947),
                    size: 19)),
            title: Text('${item['description'] ?? category}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '$category${date == null ? '' : ' · ${DateFormat('d MMM').format(date)}'}'),
            trailing: Text('${isIncome ? '+' : '−'}${_money.format(amount)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isIncome
                        ? const Color(0xFF147A57)
                        : const Color(0xFF28332D)))));
  }

  Widget _budgetTile(Map<String, dynamic> item) {
    final limit = _number(item['amountLimit'] ?? item['limit']);
    final spent = _number(item['spent'] ?? item['amountSpent']);
    final progress =
        limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0).toDouble();
    final category = item['category'] is Map
        ? (item['category'] as Map)['name']
        : (item['categoryName'] ?? 'Budget');
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$category',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${_money.format(spent)} / ${_money.format(limit)}'),
                  PopupMenuButton<String>(
                      onSelected: (value) => _budgetAction(item, value),
                      itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit', child: Text('Change limit')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete budget'))
                          ])
                ])
              ]),
              const SizedBox(height: 11),
              LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8))
            ])));
  }

  Widget _goalTile(Map<String, dynamic> item) {
    final target = _number(item['targetAmount']);
    final current = _number(item['currentAmount']);
    final progress =
        target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0).toDouble();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                    child: Text('${item['name'] ?? 'Savings goal'}',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(progress * 100).round()}%'),
                  PopupMenuButton<String>(
                      onSelected: (value) => _goalAction(item, value),
                      itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit',
                                child: Text('Update saved amount')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete goal'))
                          ])
                ])
              ]),
              const SizedBox(height: 6),
              Text(
                  '${_money.format(current)} saved of ${_money.format(target)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 11),
              LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8))
            ])));
  }

  Widget _sectionHeader(String title, {VoidCallback? onTap}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        if (onTap != null)
          TextButton(onPressed: onTap, child: const Text('See all'))
      ]);

  Future<void> _addTransaction() async {
    final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _TransactionForm(api: widget.api));
    if (created == true) _load();
  }

  Future<void> _transactionActions(Map<String, dynamic> item) async {
    final action = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit transaction'),
                  onTap: () => Navigator.pop(context, 'edit')),
              ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete transaction'),
                  onTap: () => Navigator.pop(context, 'delete'))
            ])));
    if (action == 'edit') {
      final saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _TransactionForm(api: widget.api, initial: item));
      if (saved == true) _load();
    }
    if (action == 'delete') {
      try {
        await widget.api.deleteTransaction('${item['id']}');
        _load();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e is FinanceApiException
                  ? e.message
                  : 'Could not delete this transaction.')));
      }
    }
  }

  Future<void> _addBudget() async {
    final categories = await widget.api.categories(type: 'EXPENSE');
    if (!mounted) return;
    final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => _AmountDialog(
            title: 'New monthly budget',
            categories: categories,
            amountLabel: 'Monthly limit'));
    if (result == null) return;
    try {
      final now = DateTime.now();
      await widget.api.createBudget(
          categoryId: result['categoryId']!,
          amountLimit: result['amount']!,
          month: now.month,
          year: now.year);
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is FinanceApiException
                ? e.message
                : 'Could not create the budget.')));
    }
  }

  Future<void> _budgetAction(Map<String, dynamic> item, String action) async {
    try {
      if (action == 'delete') {
        await widget.api.deleteBudget('${item['id']}');
      } else {
        final value = await _amountPrompt(
            context, 'Update monthly limit', '${item['amountLimit'] ?? ''}');
        if (value == null) return;
        await widget.api.updateBudget('${item['id']}', {'amountLimit': value});
      }
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is FinanceApiException
                ? e.message
                : 'Could not update this budget.')));
    }
  }

  Future<void> _goalAction(Map<String, dynamic> item, String action) async {
    try {
      if (action == 'delete') {
        await widget.api.deleteGoal('${item['id']}');
      } else {
        final value = await _amountPrompt(
            context, 'Update saved amount', '${item['currentAmount'] ?? '0'}');
        if (value == null) return;
        await widget.api.updateGoal('${item['id']}', {'currentAmount': value});
      }
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is FinanceApiException
                ? e.message
                : 'Could not update this goal.')));
    }
  }

  Future<void> _addGoal() async {
    final result = await showDialog<Map<String, String>>(
        context: context, builder: (_) => const _GoalDialog());
    if (result == null) return;
    try {
      await widget.api.createGoal(
          name: result['name']!,
          targetAmount: result['amount']!,
          currentAmount: result['current'] ?? '0');
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is FinanceApiException
                ? e.message
                : 'Could not create the goal.')));
    }
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (mounted) widget.onLogout();
  }

  String _amount(List<String> keys, Map<String, dynamic> source) {
    final totals = source['totals'] is Map ? source['totals'] as Map : source;
    for (final key in keys) {
      if (totals.containsKey(key)) return _money.format(_number(totals[key]));
    }
    return _money.format(0);
  }

  double _number(dynamic value) => double.tryParse('$value') ?? 0;
}

Future<String?> _amountPrompt(
    BuildContext context, String title, String initial) async {
  final controller = TextEditingController(text: initial);
  final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(title),
            content: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '₹ ')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () {
                    if ((double.tryParse(controller.text) ?? 0) > 0)
                      Navigator.pop(context, controller.text.trim());
                  },
                  child: const Text('Save'))
            ],
          ));
  controller.dispose();
  return value;
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog(
      {required this.title,
      required this.categories,
      required this.amountLabel});
  final String title, amountLabel;
  final List<Map<String, dynamic>> categories;
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _amount = TextEditingController();
  String? _category;
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.categories
                    .map((x) => DropdownMenuItem(
                        value: '${x['id']}', child: Text('${x['name']}')))
                    .toList(),
                onChanged: (v) => setState(() => _category = v)),
            const SizedBox(height: 12),
            TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: widget.amountLabel))
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (_category == null ||
                      (double.tryParse(_amount.text) ?? 0) <= 0) return;
                  Navigator.pop(context, {
                    'categoryId': _category!,
                    'amount': _amount.text.trim()
                  });
                },
                child: const Text('Create'))
          ]);
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog();
  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _current = TextEditingController(text: '0');
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Savings goal'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Goal name')),
            const SizedBox(height: 10),
            TextField(
                controller: _target,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Target amount')),
            const SizedBox(height: 10),
            TextField(
                controller: _current,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Already saved'))
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (_name.text.trim().length < 2 ||
                      (double.tryParse(_target.text) ?? 0) <= 0) return;
                  Navigator.pop(context, {
                    'name': _name.text.trim(),
                    'amount': _target.text.trim(),
                    'current': _current.text.trim().isEmpty
                        ? '0'
                        : _current.text.trim()
                  });
                },
                child: const Text('Create'))
          ]);
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.money});
  final Map<String, dynamic> summary;
  final NumberFormat money;
  @override
  Widget build(BuildContext context) {
    final totals =
        summary['totals'] is Map ? summary['totals'] as Map : summary;
    final income =
        double.tryParse('${totals['income'] ?? totals['totalIncome'] ?? 0}') ??
            0;
    final expenses = double.tryParse(
            '${totals['expenses'] ?? totals['totalExpenses'] ?? 0}') ??
        0;
    final balance = double.tryParse(
            '${totals['net'] ?? totals['balance'] ?? totals['currentBalance'] ?? income - expenses}') ??
        income - expenses;
    return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: const Color(0xFF145B48),
            borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CURRENT BALANCE',
              style: TextStyle(
                  color: Color(0xFFD1E6DC),
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(money.format(balance),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.trending_up_rounded,
                color: Color(0xFFB7E8CD), size: 17),
            const SizedBox(width: 6),
            Text('Based on your recorded income and spending',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .8), fontSize: 12))
          ])
        ]));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});
  final String title, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)))
          ])));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(children: [
            Icon(icon, size: 30, color: const Color(0xFF126B52)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
          ])));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Try again'))
          ])));
}

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({required this.api, this.initial});
  final FinanceApi api;
  final Map<String, dynamic>? initial;
  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'EXPENSE';
  String? _category;
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _categories = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    if (item != null) {
      _amount.text = '${item['amount'] ?? ''}';
      _description.text = '${item['description'] ?? ''}';
      _notes.text = '${item['notes'] ?? ''}';
      _type = '${item['type'] ?? 'EXPENSE'}';
      _category =
          '${item['categoryId'] ?? (item['category'] is Map ? (item['category'] as Map)['id'] : '')}';
      _date =
          DateTime.tryParse('${item['transactionDate'] ?? ''}')?.toLocal() ??
              DateTime.now();
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.api.categories(type: _type);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (!_categories.any((category) => '${category['id']}' == _category)) {
          _category = null;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
          key: _form,
          child: ListView(shrinkWrap: true, children: [
            Center(
                child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            Text(
                widget.initial == null ? 'New transaction' : 'Edit transaction',
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'EXPENSE',
                      label: Text('Expense'),
                      icon: Icon(Icons.north_east)),
                  ButtonSegment(
                      value: 'INCOME',
                      label: Text('Income'),
                      icon: Icon(Icons.south_west))
                ],
                selected: {
                  _type
                },
                onSelectionChanged: (v) {
                  setState(() {
                    _type = v.first;
                    _category = null;
                  });
                  _loadCategories();
                }),
            const SizedBox(height: 14),
            TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount', prefixText: '₹ '),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                    ? 'Enter an amount greater than zero.'
                    : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a description.'
                    : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: _categories.any((c) => '${c['id']}' == _category)
                    ? _category
                    : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(
                        value: '${c['id']}', child: Text('${c['name']}')))
                    .toList(),
                onChanged: (v) => setState(() => _category = v),
                validator: (v) => v == null ? 'Choose a category.' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_outlined))),
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat('d MMMM yyyy').format(_date))),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const CircularProgressIndicator()
                    : const Text('Save transaction'))
          ])));

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 1)));
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.initial == null) {
        await widget.api.createTransaction(
            amount: _amount.text.trim(),
            type: _type,
            categoryId: _category!,
            description: _description.text,
            date: _date,
            notes: _notes.text);
      } else {
        await widget.api.updateTransaction('${widget.initial!['id']}', {
          'amount': _amount.text.trim(),
          'type': _type,
          'categoryId': _category!,
          'description': _description.text.trim(),
          'transactionDate':
              '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
          'notes': _notes.text.trim()
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        setState(() => _error = error is FinanceApiException
            ? error.message
            : 'Could not save the transaction.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
