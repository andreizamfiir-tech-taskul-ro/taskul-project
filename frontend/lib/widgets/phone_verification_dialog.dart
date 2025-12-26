import 'package:flutter/material.dart';

import '../state/auth_state.dart';

class PhoneVerificationDialog extends StatefulWidget {
  final String initialPhone;

  const PhoneVerificationDialog({
    super.key,
    required this.initialPhone,
  });

  @override
  State<PhoneVerificationDialog> createState() => _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState extends State<PhoneVerificationDialog> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  String? _lastCodeDev; // shown only for local dev convenience
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = widget.initialPhone;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introdu un numar de telefon')),
      );
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final auth = AuthState.instance;
      final code = await auth.sendPhoneVerification(phone: phone);
      _lastCodeDev = code;
      _error = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cod trimis (dev: vezi mai jos)')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introdu codul de 4 cifre')),
      );
      return;
    }
    if (_verifying) return;
    setState(() => _verifying = true);
    try {
      await AuthState.instance.verifyPhoneCode(code);
      _error = null;
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefon verificat')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0040FF);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 520 ? screenWidth * 0.92 : 520.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.phone_iphone, color: primaryBlue),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Verificare numar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Introdu numarul de telefon si codul din SMS (4 cifre).',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numar de telefon',
                  filled: true,
                  fillColor: const Color(0xFFF4F6FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E6F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: primaryBlue),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        letterSpacing: 8,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        filled: true,
                        fillColor: const Color(0xFFF4F6FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E6F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryBlue),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _sending ? null : _sendCode,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryBlue,
                      side: BorderSide(color: primaryBlue),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Trimite cod'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Continua'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              if (_lastCodeDev != null) ...[
                const SizedBox(height: 8),
                Text(
                  'DEV code: $_lastCodeDev',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
