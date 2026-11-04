import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api/finance_api.dart';

const _green = Color(0xFF126B52);
final _money =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

double _num(dynamic value) => double.tryParse('$value') ?? 0;
String _msg(Object error) => error is FinanceApiException
    ? error.message
    : 'Something went wrong. Please try again.';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(
      {super.key, required this.api, required this.onLogout, this.onSaved});
  final FinanceApi api;
  final VoidCallback onLogout;
  final VoidCallback? onSaved;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  final _name = TextEditingController();
  String _currency = 'INR';
  final Map<String, bool> _preferences = {
    'budgetAlerts': true,
    'recurringReminders': true,
    'spendingAlerts': true,
    'goalMilestones': true,
    'monthlySummary': true,
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.profile();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _name.text = '${data['name'] ?? ''}';
        _currency = '${data['currency'] ?? 'INR'}';
        final prefs = data['notificationPreference'];
        if (prefs is Map) {
          for (final key in _preferences.keys) {
            _preferences[key] = prefs[key] is bool ? prefs[key] as bool : true;
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = _msg(e);
          _loading = false;
        });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.api.updateProfile({
        'name': _name.text.trim(),
        'currency': _currency,
        'preferences': _preferences,
      });
      if (mounted) setState(() => _profile = updated);
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_profile == null)
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error ?? 'Could not load profile'),
        TextButton(onPressed: _load, child: const Text('Retry'))
      ]));
    final name = '${_profile!['name'] ?? 'FinanceFlow user'}';
    final email = '${_profile!['email'] ?? ''}';
    return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          const Text('Your profile',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFE3F2EA),
                        child: Text(
                            name.isEmpty
                                ? 'F'
                                : name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: _green,
                                fontSize: 24,
                                fontWeight: FontWeight.w700))),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 17)),
                          const SizedBox(height: 4),
                          Text(email,
                              style: TextStyle(color: Colors.grey.shade600))
                        ]))
                  ]))),
          const SizedBox(height: 16),
          const Text('PERSONAL DETAILS',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF66736A))),
          const SizedBox(height: 9),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline))),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(
                            labelText: 'Display currency',
                            prefixIcon: Icon(Icons.currency_exchange)),
                        items: const [
                          DropdownMenuItem(
                              value: 'INR', child: Text('INR · Indian rupee')),
                          DropdownMenuItem(
                              value: 'USD', child: Text('USD · US dollar')),
                          DropdownMenuItem(
                              value: 'EUR', child: Text('EUR · Euro')),
                          DropdownMenuItem(
                              value: 'GBP',
                              child: Text('GBP · Pound sterling')),
                          DropdownMenuItem(
                              value: 'CAD',
                              child: Text('CAD · Canadian dollar')),
                          DropdownMenuItem(
                              value: 'AUD',
                              child: Text('AUD · Australian dollar'))
                        ],
                        onChanged: (v) =>
                            setState(() => _currency = v ?? _currency)),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? 'Saving…' : 'Save changes')))
                  ]))),
          const SizedBox(height: 18),
          const Text('NOTIFICATION PREFERENCES',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF66736A))),
          const SizedBox(height: 9),
          Card(
              child: Column(children: [
            _preference('Budget alerts', 'Know when a spending limit is close.',
                'budgetAlerts'),
            _preference('Spending alerts', 'Get a note about unusual activity.',
                'spendingAlerts'),
            _preference('Recurring reminders', 'Keep regular bills in view.',
                'recurringReminders'),
            _preference('Savings milestones',
                'Celebrate progress on your goals.', 'goalMilestones'),
            _preference('Monthly summary', 'Receive a monthly money recap.',
                'monthlySummary'),
          ])),
          const SizedBox(height: 20),
          const Text('YOUR FINANCES',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF66736A))),
          const SizedBox(height: 9),
          _menu(
              context,
              Icons.repeat_rounded,
              'Recurring payments',
              'Manage regular income and bills',
              RecurringScreen(api: widget.api)),
          _menu(
              context,
              Icons.insights_rounded,
              'AI money insights',
              'Understand trends and get ideas',
              InsightsScreen(api: widget.api)),
          _menu(context, Icons.auto_awesome_rounded, 'Ask FinanceFlow',
              'Chat about your spending', AssistantScreen(api: widget.api)),
          _menu(
              context,
              Icons.notifications_none_rounded,
              'Notifications',
              'Budget and savings updates',
              NotificationsScreen(api: widget.api)),
          _menu(
              context,
              Icons.category_outlined,
              'Categories',
              'Organize income and spending',
              CategoriesScreen(api: widget.api)),
          _menu(context, Icons.file_download_outlined, 'Export transactions',
              'Download a private CSV copy', ExportScreen(api: widget.api)),
          _menu(
              context,
              Icons.document_scanner_outlined,
              'Scan a receipt',
              'Read a receipt and review before saving',
              ReceiptScannerScreen(api: widget.api)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFAB493A),
                  padding: const EdgeInsets.all(14))),
          const SizedBox(height: 10),
          Center(
              child: Text(
                  'Your financial information is private to your account.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
        ]);
  }

  Widget _menu(BuildContext context, IconData icon, String title,
          String subtitle, Widget screen) =>
      Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEAF3ED),
                  child: Icon(icon, color: _green)),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => screen))));

  Widget _preference(String title, String subtitle, String key) =>
      SwitchListTile(
        value: _preferences[key] ?? true,
        onChanged: (value) => setState(() => _preferences[key] = value),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        activeColor: _green,
      );
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.api});
  final FinanceApi api;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.dashboard();
      if (mounted)
        setState(() {
          _data = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = _msg(e);
          _loading = false;
        });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
          child: TextButton(
              onPressed: _load,
              child: Text('Could not load analytics · Retry\n$_error',
                  textAlign: TextAlign.center)));
    final totals = _data['totals'] is Map ? _data['totals'] as Map : {};
    final monthly =
        (_data['monthly'] is List ? _data['monthly'] as List : const [])
            .whereType<Map>()
            .toList();
    final categories = (_data['categoryBreakdown'] is List
            ? _data['categoryBreakdown'] as List
            : const [])
        .whereType<Map>()
        .toList();
    final maxValue = monthly.fold<double>(
        1,
        (max, row) => [_num(row['income']), _num(row['expenses']), max]
            .reduce((a, b) => a > b ? a : b));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Analytics',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Your last six months at a glance',
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _stat('Income', _money.format(_num(totals['income'])),
                  const Color(0xFF147A57))),
          const SizedBox(width: 10),
          Expanded(
              child: _stat('Spending', _money.format(_num(totals['expenses'])),
                  const Color(0xFFBA5947)))
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _stat(
                  'Net cash flow', _money.format(_num(totals['net'])), _green)),
          const SizedBox(width: 10),
          Expanded(
              child: _stat('Savings rate',
                  '${_num(totals['savingsRate']).toStringAsFixed(1)}%', _green))
        ]),
        const SizedBox(height: 22),
        const Text('INCOME VS SPENDING',
            style: TextStyle(
                fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  SizedBox(
                      height: 150,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: monthly.map((row) {
                            final income = _num(row['income']);
                            final expenses = _num(row['expenses']);
                            return Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5),
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Expanded(
                                              child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                Expanded(
                                                    child: Container(
                                                        height: (income /
                                                                maxValue *
                                                                110)
                                                            .clamp(3, 110),
                                                        decoration: BoxDecoration(
                                                            color: const Color(
                                                                0xFF5BAF83),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        5)))),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                    child: Container(
                                                        height: (expenses /
                                                                maxValue *
                                                                110)
                                                            .clamp(3, 110),
                                                        decoration: BoxDecoration(
                                                            color: const Color(
                                                                0xFFE9A28D),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        5)))),
                                              ])),
                                          const SizedBox(height: 7),
                                          Text(
                                              '${row['month']}'.split('-').last,
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                        ])));
                          }).toList())),
                  const SizedBox(height: 10),
                  const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.circle, color: Color(0xFF5BAF83), size: 10),
                        SizedBox(width: 5),
                        Text('Income', style: TextStyle(fontSize: 11)),
                        SizedBox(width: 16),
                        Icon(Icons.circle, color: Color(0xFFE9A28D), size: 10),
                        SizedBox(width: 5),
                        Text('Expenses', style: TextStyle(fontSize: 11))
                      ]),
                ]))),
        const SizedBox(height: 22),
        const Text('SPENDING BY CATEGORY',
            style: TextStyle(
                fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (categories.isEmpty)
          const _SimpleEmpty(
              text: 'Add a few expenses to see your category breakdown.')
        else
          ...categories.take(8).map((row) {
            final fraction = (_num(row['percentage']) / 100).clamp(0.0, 1.0);
            return Card(
                margin: const EdgeInsets.only(bottom: 7),
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                            child: Text('${row['name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                        Text(_money.format(_num(row['amount']))),
                        const SizedBox(width: 8),
                        Text('${_num(row['percentage']).toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12))
                      ]),
                      const SizedBox(height: 9),
                      LinearProgressIndicator(
                          value: fraction,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(8),
                          color: _green),
                    ])));
          }),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Card(
      child: Padding(
          padding: const EdgeInsets.all(15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 7),
            FittedBox(
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 19,
                        color: color,
                        fontWeight: FontWeight.w700)))
          ])));
}

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key, required this.api});
  final FinanceApi api;
  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  Future<void> _load() async {
    try {
      final rows = await widget.api.recurring();
      if (mounted)
        setState(() {
          _rows = rows;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = _msg(e);
          _loading = false;
        });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _create() async {
    final categories = await widget.api.categories();
    if (!mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create an expense category first.')));
      return;
    }
    final form = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _RecurringDialog(categories: categories));
    if (form == null) return;
    try {
      await widget.api.createRecurring(form);
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recurring payments')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('Add rule')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: TextButton(
                        onPressed: _load, child: Text('Retry · $_error')))
                : _rows.isEmpty
                    ? const Center(
                        child: _SimpleEmpty(
                            text:
                                'Track salary, rent, bills and subscriptions here.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: _rows.map((row) {
                          final category = row['category'] is Map
                              ? (row['category'] as Map)['name']
                              : 'Payment';
                          final active = row['isActive'] == true;
                          return Card(
                              child: ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: Color(0xFFEAF3ED),
                                child: Icon(Icons.repeat, color: _green)),
                            title: Text('${row['description'] ?? category}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '$category · ${row['frequency'] ?? 'MONTHLY'} · ${active ? 'Active' : 'Paused'}'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                try {
                                  if (value == 'delete') {
                                    await widget.api
                                        .deleteRecurring('${row['id']}');
                                  } else {
                                    await widget.api.updateRecurring(
                                        '${row['id']}',
                                        {'isActive': value == 'resume'});
                                  }
                                  await _load();
                                } catch (e) {
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(_msg(e))));
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: active ? 'pause' : 'resume',
                                    child: Text(active ? 'Pause' : 'Resume')),
                                const PopupMenuItem(
                                    value: 'delete', child: Text('Delete'))
                              ],
                            ),
                          ));
                        }).toList()),
      );
}

class _RecurringDialog extends StatefulWidget {
  const _RecurringDialog({required this.categories});
  final List<Map<String, dynamic>> categories;
  @override
  State<_RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends State<_RecurringDialog> {
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  String? _category;
  String _frequency = 'MONTHLY';
  String _type = 'EXPENSE';
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('New recurring rule'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'EXPENSE', label: Text('Expense')),
                  ButtonSegment(value: 'INCOME', label: Text('Income'))
                ],
                selected: {
                  _type
                },
                onSelectionChanged: (values) => setState(() {
                      _type = values.first;
                      _category = null;
                    })),
            const SizedBox(height: 10),
            TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 10),
            TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.categories
                    .where((x) => x['type'] == _type)
                    .map((x) => DropdownMenuItem(
                        value: '${x['id']}', child: Text('${x['name']}')))
                    .toList(),
                onChanged: (v) => setState(() => _category = v)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: const ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']
                    .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(v[0] + v.substring(1).toLowerCase())))
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v ?? _frequency))
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (_category == null ||
                      _desc.text.trim().isEmpty ||
                      _num(_amount.text) <= 0) return;
                  Navigator.pop(context, {
                    'categoryId': _category,
                    'amount': _amount.text.trim(),
                    'type': _type,
                    'frequency': _frequency,
                    'interval': 1,
                    'startDate':
                        DateTime.now().toIso8601String().substring(0, 10),
                    'description': _desc.text.trim()
                  });
                },
                child: const Text('Create'))
          ]);
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});
  final FinanceApi api;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  Future<void> _load() async {
    try {
      final data = await widget.api.notifications();
      if (mounted)
        setState(() {
          _rows = (data['data'] as List? ?? const [])
              .whereType<Map>()
              .map((x) => Map<String, dynamic>.from(x))
              .toList();
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = _msg(e);
          _loading = false;
        });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _read(Map<String, dynamic> row) async {
    await widget.api.markNotificationsRead(ids: ['${row['id']}']);
    if (mounted) setState(() => row['isRead'] = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Notifications'), actions: [
        TextButton(
            onPressed: _rows.isEmpty
                ? null
                : () async {
                    await widget.api.markNotificationsRead(all: true);
                    _load();
                  },
            child: const Text('Mark all read'))
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: TextButton(
                      onPressed: _load, child: Text('Retry · $_error')))
              : _rows.isEmpty
                  ? const Center(
                      child: _SimpleEmpty(
                          text:
                              'You’re all caught up. Budget and goal updates will show here.'))
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: _rows
                          .map((row) => Card(
                              child: ListTile(
                                  onTap: () => _read(row),
                                  leading: CircleAvatar(
                                      backgroundColor: row['isRead'] == true
                                          ? Colors.grey.shade100
                                          : const Color(0xFFEAF3ED),
                                      child: Icon(
                                          row['isRead'] == true
                                              ? Icons.notifications_none
                                              : Icons
                                                  .notifications_active_outlined,
                                          color: _green)),
                                  title: Text('${row['title'] ?? 'FinanceFlow update'}',
                                      style: TextStyle(
                                          fontWeight: row['isRead'] == true
                                              ? FontWeight.w500
                                              : FontWeight.w700)),
                                  subtitle: Text('${row['message'] ?? ''}'),
                                  trailing: row['isRead'] == true ? null : const Icon(Icons.circle, color: _green, size: 9))))
                          .toList()));
}

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.api});
  final FinanceApi api;
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, dynamic>? _insight;
  bool _busy = false;
  String? _error;
  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final row = await widget.api.generateInsight();
      if (mounted) setState(() => _insight = row);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _insight?['content'];
    return Scaffold(
        appBar: AppBar(title: const Text('AI money insights')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFFE7F3EB),
                  borderRadius: BorderRadius.circular(20)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, color: _green),
                    SizedBox(height: 12),
                    Text('A clearer view of your money',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 20)),
                    SizedBox(height: 6),
                    Text(
                        'Insights use your recorded transactions and offer general information, not guaranteed financial advice.')
                  ])),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: const Icon(Icons.insights),
              label: Text(_busy
                  ? 'Reviewing your finances…'
                  : 'Generate this month’s insight')),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red))),
          if (content is Map) ...[
            const SizedBox(height: 20),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${content['summary'] ?? ''}',
                              style:
                                  const TextStyle(fontSize: 16, height: 1.45)),
                          const SizedBox(height: 18),
                          if ((content['trends'] as List? ?? const [])
                              .isNotEmpty)
                            const Text('TRENDS',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    letterSpacing: 1)),
                          ...((content['trends'] as List? ?? const [])
                              .map((x) => _bullet('$x'))),
                          if ((content['recommendations'] as List? ?? const [])
                              .isNotEmpty)
                            const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text('IDEAS TO CONSIDER',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 1))),
                          ...((content['recommendations'] as List? ?? const [])
                              .map((x) => _bullet('$x')))
                        ])))
          ]
        ]));
  }

  Widget _bullet(String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_outline, size: 18, color: _green),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35)))
      ]));
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, required this.api});
  final FinanceApi api;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.chatHistory();
      if (mounted) setState(() => _messages = rows);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.length < 2 || _busy) return;
    _input.clear();
    setState(() {
      _error = null;
      _busy = true;
      _messages.add({'role': 'USER', 'content': text});
    });
    try {
      final reply = await widget.api.askAssistant(text);
      if (mounted) setState(() => _messages.add(reply));
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ask FinanceFlow')),
        body: Column(children: [
          Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.auto_awesome,
                                color: _green, size: 36),
                            const SizedBox(height: 10),
                            const Text('Your finances, explained',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 19)),
                            const SizedBox(height: 12),
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  'How much did I spend last month?',
                                  'What are my top categories?',
                                  'Am I within my budget?'
                                ]
                                    .map((x) => ActionChip(
                                        label: Text(x),
                                        onPressed: () {
                                          _input.text = x;
                                          _send();
                                        }))
                                    .toList()),
                          ])))
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      children: _messages.map((row) {
                        final user = row['role'] == 'USER';
                        return Align(
                            alignment: user
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(13),
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                decoration: BoxDecoration(
                                    color: user
                                        ? const Color(0xFFE5F2EA)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFFE7ECE8))),
                                child: Text('${row['content'] ?? ''}',
                                    style: const TextStyle(height: 1.35))));
                      }).toList())),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red))),
          SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                                hintText: 'Ask about your spending…'))),
                    const SizedBox(width: 8),
                    IconButton.filled(
                        onPressed: _busy ? null : _send,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.arrow_upward)),
                  ]))),
        ]),
      );
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.api});
  final FinanceApi api;
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  Future<void> _load() async {
    try {
      final rows = await widget.api.categories();
      if (mounted)
        setState(() {
          _rows = rows;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _add() async {
    final data = await showDialog<Map<String, String>>(
        context: context, builder: (_) => const _CategoryDialog());
    if (data == null) return;
    try {
      await widget.api.createCategory(data['name']!, data['type']!);
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add category')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(14), children: [
              for (final type in ['EXPENSE', 'INCOME']) ...[
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(type == 'EXPENSE' ? 'EXPENSES' : 'INCOME',
                        style: const TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700))),
                ..._rows.where((x) => x['type'] == type).map((row) => Card(
                    child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEAF3ED),
                            child: Icon(
                                type == 'INCOME'
                                    ? Icons.south_west
                                    : Icons.shopping_bag_outlined,
                                color: _green)),
                        title: Text('${row['name']}'),
                        trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              try {
                                if (v == 'delete')
                                  await widget.api
                                      .deleteCategory('${row['id']}');
                                else {
                                  final name = await _textDialog(context,
                                      'Rename category', '${row['name']}');
                                  if (name != null)
                                    await widget.api
                                        .renameCategory('${row['id']}', name);
                                }
                                _load();
                              } catch (e) {
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_msg(e))));
                              }
                            },
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'rename', child: Text('Rename')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Delete'))
                                ]))))
              ]
            ]));
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _name = TextEditingController();
  String _type = 'EXPENSE';
  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Add category'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Category name')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'EXPENSE', child: Text('Expense')),
                  DropdownMenuItem(value: 'INCOME', child: Text('Income'))
                ],
                onChanged: (v) => setState(() => _type = v ?? _type))
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => _name.text.trim().isEmpty
                    ? null
                    : Navigator.pop(
                        context, {'name': _name.text.trim(), 'type': _type}),
                child: const Text('Add'))
          ]);
}

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key, required this.api});
  final FinanceApi api;
  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final _picker = ImagePicker();
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  File? _image;
  List<Map<String, dynamic>> _categories = [];
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _scanning = false;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _extracted;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final photo = await _picker.pickImage(
        source: source, imageQuality: 88, maxWidth: 1800);
    if (photo == null) return;
    setState(() {
      _image = File(photo.path);
      _extracted = null;
      _error = null;
      _scanning = true;
    });
    try {
      final values = await Future.wait([
        widget.api.scanReceipt(File(photo.path)),
        widget.api.categories(type: 'EXPENSE')
      ]);
      final data = values.first as Map<String, dynamic>;
      final categories = values.last as List<Map<String, dynamic>>;
      final extracted = data['extractedData'] is Map
          ? Map<String, dynamic>.from(data['extractedData'] as Map)
          : <String, dynamic>{};
      final suggested = '${extracted['suggestedCategory'] ?? ''}'.toLowerCase();
      final match = categories
          .where((x) => '${x['name']}'.toLowerCase() == suggested)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryId = match == null
            ? (categories.isEmpty ? null : '${categories.first['id']}')
            : '${match['id']}';
        _extracted = extracted;
        _amount.text = '${extracted['totalAmount'] ?? ''}';
        _merchant.text = '${extracted['merchant'] ?? ''}';
        _date = DateTime.tryParse('${extracted['transactionDate'] ?? ''}') ??
            DateTime.now();
        _scanning = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = _msg(e);
          _scanning = false;
        });
    }
  }

  Future<void> _save() async {
    if (_categoryId == null ||
        _merchant.text.trim().isEmpty ||
        _num(_amount.text) <= 0) {
      setState(() =>
          _error = 'Review the amount, merchant and category before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.createTransaction(
          amount: _amount.text.trim(),
          type: 'EXPENSE',
          categoryId: _categoryId!,
          description: _merchant.text.trim(),
          date: _date,
          notes: 'Added from a scanned receipt');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt transaction saved.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Receipt scanner')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('Scan and review',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              'We’ll read the receipt details, then let you confirm them before creating a transaction.',
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          if (_image != null)
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(_image!, height: 200, fit: BoxFit.cover)),
          if (_image == null)
            Container(
                height: 150,
                decoration: BoxDecoration(
                    color: const Color(0xFFEAF3ED),
                    borderRadius: BorderRadius.circular(18)),
                child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 40, color: _green),
                      SizedBox(height: 8),
                      Text('Choose a receipt image')
                    ])),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed:
                        _scanning ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'))),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed:
                        _scanning ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera')))
          ]),
          if (_scanning)
            const Padding(
                padding: EdgeInsets.all(18),
                child: Center(
                    child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Reading the receipt…')
                ]))),
          if (_extracted != null) ...[
            const SizedBox(height: 20),
            const Text('REVIEW EXTRACTED DETAILS',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
                controller: _merchant,
                decoration: const InputDecoration(
                    labelText: 'Merchant / description',
                    prefixIcon: Icon(Icons.store_outlined))),
            const SizedBox(height: 10),
            TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Amount', prefixText: '₹ ')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration:
                    const InputDecoration(labelText: 'Expense category'),
                items: _categories
                    .map((x) => DropdownMenuItem(
                        value: '${x['id']}', child: Text('${x['name']}')))
                    .toList(),
                onChanged: (value) => setState(() => _categoryId = value)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)));
                  if (date != null && mounted) setState(() => _date = date);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat('d MMMM yyyy').format(_date))),
            const SizedBox(height: 8),
            Text(
                'Check these details against the receipt. Nothing is saved until you confirm.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _saving ? null : _save,
                child:
                    Text(_saving ? 'Saving…' : 'Confirm and save transaction')),
          ],
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 14),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red))),
        ]),
      );
}

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.api});
  final FinanceApi api;
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _busy = false;
  String? _message;
  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final csv = await widget.api.exportTransactions();
      await Clipboard.setData(ClipboardData(text: csv));
      final count = '${csv.split('\n').length - 2}';
      if (mounted)
        setState(() => _message =
            'CSV copied to your clipboard ($count transactions). Paste it into a file or spreadsheet to save it.');
    } catch (e) {
      if (mounted) setState(() => _message = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Export transactions')),
      body: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.file_download_outlined, color: _green, size: 40),
            const SizedBox(height: 12),
            const Text('Your data, in a portable format',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Prepare a CSV of your transactions. It includes only records in your account.'),
            const SizedBox(height: 18),
            FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.download),
                label: Text(_busy ? 'Preparing…' : 'Copy CSV export')),
            if (_message != null)
              Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(_message!))
          ])));
}

Future<String?> _textDialog(
    BuildContext context, String title, String initial) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'Name')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Save'))
              ]));
  controller.dispose();
  return result;
}

class _SimpleEmpty extends StatelessWidget {
  const _SimpleEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600))));
}
