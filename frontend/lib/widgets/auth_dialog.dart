import 'package:flutter/material.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  bool _isLogin = true;
  bool _rememberMe = false;

  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() => _isLogin = !_isLogin);
  }

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isLogin ? 'Login placeholder' : 'Signup placeholder'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0040FF);
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = width < 520 ? width * 0.92 : 520.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(primaryBlue),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLogin ? 'Bine ati revenit!' : 'Creati cont',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Continuati cu',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    _buildSocialRow(primaryBlue),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'sau',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!_isLogin) _buildNameFields(),
                    _buildTextField(
                      controller: _emailCtrl,
                      hint: 'Adresa de e-mail',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _passwordCtrl,
                      hint: 'Parola',
                      obscure: true,
                    ),
                    const SizedBox(height: 6),
                    if (!_isLogin)
                      Text(
                        'Cel putin 8 caractere, o majuscula, o litera mica, un numar si un caracter special',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      )
                    else
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (val) => setState(() => _rememberMe = val ?? false),
                          ),
                          const Text('Tine-ma minte'),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            child: const Text('V-ati uitat parola?'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _submit,
                      child: Text(_isLogin ? 'Conectare' : 'De acord, continua'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Prin ${_isLogin ? 'autentificare' : 'crearea contului'}, sunteti de acord cu Termenii de utilizare si intelegeti Politica de confidentialitate.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryBlue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Autentificati-va sau creati un cont',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _toggleMode,
                  child: Text(
                    _isLogin ? 'Creati cont' : 'Conectare',
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialRow(Color primaryBlue) {
    Widget buildButton({
      required Color color,
      required Widget icon,
      required String label,
      Color? borderColor,
    }) {
      return Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: borderColor ?? color),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () {},
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildButton(
          color: const Color(0xFF1877F2),
          icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
          label: 'Facebook',
        ),
        const SizedBox(width: 8),
        buildButton(
          color: Colors.grey.shade400,
          borderColor: Colors.grey.shade400,
          icon: const Icon(Icons.g_mobiledata, color: Colors.black87, size: 22),
          label: 'Google',
        ),
        if (_isLogin) ...[
          const SizedBox(width: 8),
          buildButton(
            color: Colors.black,
            borderColor: Colors.black,
            icon: const Icon(Icons.apple, color: Colors.black),
            label: 'Apple',
          ),
        ],
      ],
    );
  }

  Widget _buildNameFields() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _firstNameCtrl,
              hint: 'Prenume',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTextField(
              controller: _lastNameCtrl,
              hint: 'Nume',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF0040FF)),
        ),
      ),
    );
  }
}

Future<void> showAuthDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const AuthDialog(),
  );
}
