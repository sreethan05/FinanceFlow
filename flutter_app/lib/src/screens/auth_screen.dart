import 'package:flutter/material.dart';

import '../api/finance_api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.onSignedIn});
  final FinanceApi api;
  final VoidCallback onSignedIn;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFF126B52), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28)),
              const SizedBox(height: 22),
              const Text('FinanceFlow', style: TextStyle(fontSize: 16, color: Color(0xFF126B52), fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_register ? 'Start with a clear view.' : 'Good to see you again.', style: const TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_register ? 'Create your private finance workspace.' : 'Sign in to see how your money is moving.', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 28),
              Card(child: Padding(padding: const EdgeInsets.all(20), child: Form(key: _form, child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_register) ...[
                    TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)), validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name.' : null),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)), validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email.' : null),
                  const SizedBox(height: 14),
                  TextFormField(controller: _password, obscureText: _obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => (v == null || v.length < (_register ? 10 : 8)) ? 'Use at least ${_register ? 10 : 8} characters.' : null),
                  if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _busy ? null : _submit, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_register ? 'Create account' : 'Sign in')),
                ],
              )))),
              const SizedBox(height: 18),
              Center(child: TextButton(onPressed: _busy ? null : () => setState(() { _register = !_register; _error = null; }), child: Text(_register ? 'Already have an account? Sign in' : 'New to FinanceFlow? Create an account'))),
              const SizedBox(height: 8),
              Center(child: Text('Your financial data stays private to your account.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            ],
          )),
        ))),
      );

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_register) {
        await widget.api.register(name: _name.text, email: _email.text, password: _password.text);
      }
      await widget.api.login(_email.text, _password.text);
      widget.onSignedIn();
    } catch (error) {
      if (mounted) setState(() => _error = error is FinanceApiException ? error.message : 'Could not connect. Check your server address and try again.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
}
