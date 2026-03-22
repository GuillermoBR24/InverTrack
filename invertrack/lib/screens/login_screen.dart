import 'package:flutter/material.dart';
import 'package:invertrack/screens/home_screen.dart';
import 'package:invertrack/screens/register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _ResetPhase { none, enterEmail, enterCode, enterNewPassword }

class _LoginScreenState extends State<LoginScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading       = false;
  bool _obscurePassword = true;

  // Recuperación
  _ResetPhase _resetPhase          = _ResetPhase.none;
  final _resetEmailCtrl            = TextEditingController();
  final _resetCodeCtrl             = TextEditingController();
  final _newPassCtrl               = TextEditingController();
  final _confirmPassCtrl           = TextEditingController();
  bool _resetLoading               = false;
  bool _obscureNewPass             = true;
  bool _obscureConfirmPass         = true;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailCtrl.dispose();
    _resetCodeCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── LOGIN ──────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String emailToUse = _emailController.text.trim();

      if (!emailToUse.contains('@')) {
        final result = await supabase
            .rpc('get_email_by_username', params: {'p_username': emailToUse});
        if (result == null || result.toString().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No existe ningún usuario con ese nombre'),
                backgroundColor: Color(0xFFFF6B6B),
              ),
            );
          }
          return;
        }
        emailToUse = result.toString();
      }

      await supabase.auth.signInWithPassword(
        email: emailToUse,
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── PASO 1: Enviar código al email ─────────────────────────────────────────
  Future<void> _sendResetEmail() async {
    final email = _resetEmailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ingresa tu email'),
        backgroundColor: Color(0xFFFF6B6B),
      ));
      return;
    }
    setState(() => _resetLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) {
        setState(() => _resetPhase = _ResetPhase.enterCode);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Código enviado. Revisa tu bandeja de entrada.'),
        ));
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  // ── PASO 2: Verificar OTP ─────────────────────────────────────────────────
  Future<void> _verifyCode() async {
    final email = _resetEmailCtrl.text.trim();
    final token = _resetCodeCtrl.text.trim();
    if (token.isEmpty) return;
    setState(() => _resetLoading = true);
    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      if (mounted) {
        setState(() => _resetPhase = _ResetPhase.enterNewPassword);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Código inválido o expirado: ${e.message}'),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  // ── PASO 3: Guardar nueva contraseña ───────────────────────────────────────
  Future<void> _updatePassword() async {
    final newPass     = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();
    if (newPass.isEmpty || confirmPass.isEmpty) return;
    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Las contraseñas no coinciden'),
        backgroundColor: Color(0xFFFF6B6B),
      ));
      return;
    }
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mínimo 6 caracteres'),
        backgroundColor: Color(0xFFFF6B6B),
      ));
      return;
    }
    setState(() => _resetLoading = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPass));
      if (mounted) {
        setState(() {
          _resetPhase = _ResetPhase.none;
          _resetEmailCtrl.clear();
          _resetCodeCtrl.clear();
          _newPassCtrl.clear();
          _confirmPassCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('¡Contraseña actualizada correctamente!'),
        ));
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFFF6B6B),
        ));
      }
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  void _cancelReset() {
    setState(() {
      _resetPhase = _ResetPhase.none;
      _resetEmailCtrl.clear();
      _resetCodeCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
    });
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_resetPhase != _ResetPhase.none) {
      return _buildResetFlow(context);
    }
    return _buildLogin(context);
  }

  // ── UI LOGIN (diseño original intacto) ────────────────────────────────────
  Widget _buildLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Bienvenido',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicia sesión para continuar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email / username
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo o nombre de usuario',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu correo o nombre de usuario';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu contraseña';
                          }
                          if (value.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // ¿Olvidaste tu contraseña? → abre flujo de recuperación
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () => setState(
                              () => _resetPhase = _ResetPhase.enterEmail),
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botón login
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text(
                                  'Iniciar sesión',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Registro
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿No tienes cuenta? ',
                        style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      child: const Text('Regístrate',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── UI RECUPERACIÓN (mismo estilo que el login) ───────────────────────────
  Widget _buildResetFlow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Título e icono según fase
    final String title;
    final String subtitle;
    final IconData icon;

    switch (_resetPhase) {
      case _ResetPhase.enterEmail:
        title    = 'Recuperar contraseña';
        subtitle = 'Introduce tu email y te enviaremos un código';
        icon     = Icons.lock_reset_rounded;
        break;
      case _ResetPhase.enterCode:
        title    = 'Introduce el código';
        subtitle = 'Revisa tu email: ${_resetEmailCtrl.text.trim()}';
        icon     = Icons.pin_rounded;
        break;
      case _ResetPhase.enterNewPassword:
        title    = 'Nueva contraseña';
        subtitle = 'Elige una contraseña segura';
        icon     = Icons.key_rounded;
        break;
      default:
        title    = '';
        subtitle = '';
        icon     = Icons.lock_rounded;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icono — mismo tamaño y estilo que el login
                Icon(icon, size: 72, color: scheme.primary),
                const SizedBox(height: 24),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),

                // Formulario según fase
                if (_resetPhase == _ResetPhase.enterEmail) ...[
                  TextFormField(
                    controller: _resetEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Tu email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _resetLoading ? null : _sendResetEmail,
                      child: _resetLoading
                          ? const SizedBox(
                              height: 22, width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('Enviar código',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],

                if (_resetPhase == _ResetPhase.enterCode) ...[
                  TextFormField(
                    controller: _resetCodeCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8),
                    decoration: const InputDecoration(
                      labelText: 'Código de verificación',
                      prefixIcon: Icon(Icons.pin_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: _resetLoading ? null : _sendResetEmail,
                      child: const Text('¿No lo recibiste? Reenviar código'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _resetLoading ? null : _verifyCode,
                      child: _resetLoading
                          ? const SizedBox(
                              height: 22, width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('Verificar código',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],

                if (_resetPhase == _ResetPhase.enterNewPassword) ...[
                  TextFormField(
                    controller: _newPassCtrl,
                    obscureText: _obscureNewPass,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNewPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(
                            () => _obscureNewPass = !_obscureNewPass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPassCtrl,
                    obscureText: _obscureConfirmPass,
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(() =>
                            _obscureConfirmPass = !_obscureConfirmPass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _resetLoading ? null : _updatePassword,
                      child: _resetLoading
                          ? const SizedBox(
                              height: 22, width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('Guardar contraseña',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Volver al login — mismo estilo que el link de registro
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _cancelReset,
                    child: const Text('← Volver al inicio de sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}