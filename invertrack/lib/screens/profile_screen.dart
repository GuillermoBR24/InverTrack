import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:invertrack/providers/currency_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  bool _notificationsEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  String? _avatarUrl;
  String _username = '';

  String get _userEmail => supabase.auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── CARGAR PERFIL DESDE SUPABASE ─────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _username   = data['username'] ?? _userEmail.split('@').first;
          _avatarUrl  = data['avatar_url'];
        });
      } else {
        setState(() => _username = _userEmail.split('@').first);
      }
    } catch (e) {
      _showSnack('Error al cargar el perfil: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── CERRAR SESIÓN ────────────────────────────────────────────────────────────
  Future<void> _signOut() async {
    final confirmed = await _showConfirmDialog(
      title: 'Cerrar sesión',
      message: '¿Seguro que quieres cerrar sesión?',
      confirmLabel: 'Cerrar sesión',
      confirmColor: Theme.of(context).colorScheme.primary,
    );
    if (!confirmed) return;

    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ── ELIMINAR CUENTA ──────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmDialog(
      title: 'Eliminar cuenta',
      message:
          'Esta acción es irreversible. Se borrarán todos tus datos, activos y foto de perfil.',
      confirmLabel: 'Eliminar',
      confirmColor: const Color(0xFFFF6B6B),
    );
    if (!confirmed) return;

    final emailConfirmed = await _showEmailConfirmDialog();
    if (!emailConfirmed) return;

    setState(() => _isSaving = true);

    try {
      final uid = supabase.auth.currentUser!.id;

      // Borrar avatar del Storage
      final extensions = ['jpg', 'jpeg', 'png', 'webp'];
      await Future.wait(
        extensions.map((ext) => supabase.storage
            .from('avatars')
            .remove(['$uid/avatar.$ext'])
            .catchError((_) => <FileObject>[])),
      );

      // Llamar a la función SQL que borra todo incluido auth.users
      await supabase.rpc('delete_user_account');

      // Limpiar sesión local
      await supabase.auth.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      _showSnack('Error al eliminar la cuenta: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _showEmailConfirmDialog() async {
    final controller = TextEditingController();
    final formKey    = GlobalKey<FormState>();

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Confirma tu correo',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escribe tu correo electrónico para confirmar que quieres eliminar tu cuenta.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa tu correo';
                      if (v.trim() != _userEmail) {
                        return 'El correo no coincide';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text(
                  'Confirmar eliminación',
                  style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── EDITAR CAMPO (bottom sheet) ──────────────────────────────────────────────
  Future<void> _editField({
    required String title,
    required String currentValue,
    bool isPassword = false,
  }) async {
    final controller = TextEditingController(
      text: isPassword ? '' : currentValue,
    );
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Editar $title',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: controller,
                obscureText: isPassword,
                autofocus: true,
                decoration: InputDecoration(labelText: title),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Este campo no puede estar vacío';
                  if (isPassword && v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    final uid = supabase.auth.currentUser!.id;
                    if (isPassword) {
                      await supabase.auth.updateUser(
                        UserAttributes(password: controller.text.trim()),
                      );
                    } else if (title == 'nombre de usuario') {
                      // Guardar en tabla profiles
                      await supabase.from('profiles').upsert({
                        'id': uid,
                        'username': controller.text.trim(),
                        'updated_at': DateTime.now().toIso8601String(),
                      });
                      if (mounted) setState(() => _username = controller.text.trim());
                    } else {
                      // Email → actualizar en auth
                      await supabase.auth.updateUser(
                        UserAttributes(email: controller.text.trim()),
                      );
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _showSnack('$title actualizado correctamente');
                      setState(() {});
                    }
                  } on AuthException catch (e) {
                    if (ctx.mounted) {
                      _showSnack(e.message, isError: true);
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      _showSnack('Error: $e', isError: true);
                    }
                  }
                },
                child: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SUBIR AVATAR ─────────────────────────────────────────────────────────────
  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isSaving = true);

      final uid   = supabase.auth.currentUser!.id;
      final bytes = await picked.readAsBytes();

      // En web picked.path es una blob URL — usamos mimeType directamente
      final mime  = picked.mimeType ?? 'image/jpeg';
      final ext   = mime.split('/').last; // 'jpeg', 'png', 'webp'...
      final path  = '$uid/avatar.$ext';

      await supabase.storage.from('avatars').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: mime,
        ),
      );

      final publicUrl =
          '${supabase.storage.from('avatars').getPublicUrl(path)}'
          '?t=${DateTime.now().millisecondsSinceEpoch}';

      await supabase.from('profiles').upsert({
        'id':         uid,
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() => _avatarUrl = publicUrl);
      _showSnack('Foto de perfil actualizada');
    } catch (e) {
      _showSnack('Error al subir la foto: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_rounded,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFFF6B6B) : null,
    ));
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF111827),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            content: Text(message,
                style: Theme.of(context).textTheme.bodyMedium),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel,
                    style: TextStyle(
                        color: confirmColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    const cardColor   = Color(0xFF1E2D3D);
    const borderColor = Color(0xFF1E3A5F);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Perfil',
            style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              children: [

                // ── CABECERA AVATAR ────────────────────────────────────────
                Column(
                  children: [
                    Stack(
                      children: [
                        // Avatar — foto o inicial
                        GestureDetector(
                          onTap: _showAvatarOptions,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D47A1), Color(0xFF0288D1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: _avatarUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: _avatarUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                      errorWidget: (_, __, ___) => Center(
                                        child: Text(
                                          _username.isNotEmpty
                                              ? _username[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        _username.isNotEmpty
                                            ? _username[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        // Botón cámara
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showAvatarOptions,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF0A0E1A), width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: Color(0xFF003A5C)),
                            ),
                          ),
                        ),

                        // Overlay de carga al subir foto
                        if (_isSaving)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _username,
                      style: tt.headlineMedium?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(_userEmail,
                        style: tt.bodyMedium?.copyWith(fontSize: 13)),
                  ],
                ),

                const SizedBox(height: 32),

                // ── SECCIÓN: CUENTA ────────────────────────────────────────
                _SectionLabel(label: 'Cuenta'),
                const SizedBox(height: 10),
                _SettingsCard(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  children: [
                    _SettingsTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Nombre de usuario',
                      value: _username,
                      onTap: () => _editField(
                        title: 'nombre de usuario',
                        currentValue: _username,
                      ),
                    ),
                    _Divider(color: borderColor),
                    _SettingsTile(
                      icon: Icons.email_outlined,
                      label: 'Correo electrónico',
                      value: _userEmail,
                      onTap: () => _editField(
                        title: 'correo electrónico',
                        currentValue: _userEmail,
                      ),
                    ),
                    _Divider(color: borderColor),
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      label: 'Contraseña',
                      value: '••••••••',
                      onTap: () => _editField(
                        title: 'contraseña',
                        currentValue: '',
                        isPassword: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── SECCIÓN: PREFERENCIAS ──────────────────────────────────────
                _SectionLabel(label: 'Preferencias'),
                const SizedBox(height: 10),
                _SettingsCard(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  children: [
                    // Notificaciones
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.notifications_outlined,
                                color: scheme.primary, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text('Notificaciones',
                                style: tt.bodyLarge?.copyWith(fontSize: 14)),
                          ),
                          Switch.adaptive(
                            value: _notificationsEnabled,
                            activeColor: scheme.primary,
                            onChanged: (v) =>
                                setState(() => _notificationsEnabled = v),
                          ),
                        ],
                      ),
                    ),

                    _Divider(color: borderColor),

                    // ── SELECTOR DE MONEDA ──────────────────────────────
                    Consumer<CurrencyProvider>(
                      builder: (context, cp, _) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.currency_exchange_rounded,
                                  color: scheme.primary, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Moneda',
                                      style: tt.bodyMedium
                                          ?.copyWith(fontSize: 12)),
                                  Text(
                                    cp.currency == 'USD'
                                        ? 'Dólar estadounidense'
                                        : 'Euro',
                                    style: tt.bodyLarge
                                        ?.copyWith(fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            // Toggle USD / EUR
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A0E1A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF1E3A5F)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: ['USD', 'EUR'].map((c) {
                                  final isSelected = cp.currency == c;
                                  return GestureDetector(
                                    onTap: cp.loading
                                        ? null
                                        : () => cp.setCurrency(c),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? scheme.primary.withOpacity(0.2)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(9),
                                        border: isSelected
                                            ? Border.all(
                                                color: scheme.primary,
                                                width: 1.5)
                                            : null,
                                      ),
                                      child: cp.loading && isSelected
                                          ? SizedBox(
                                              width: 14, height: 14,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  color: scheme.primary))
                                          : Text(
                                              c,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? scheme.primary
                                                    : const Color(
                                                        0xFF7BA7C2),
                                                fontSize: 13,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── SECCIÓN: SESIÓN ────────────────────────────────────────
                _SectionLabel(label: 'Sesión'),
                const SizedBox(height: 10),
                _SettingsCard(
                  cardColor: cardColor,
                  borderColor: borderColor,
                  children: [
                    _SettingsTile(
                      icon: Icons.logout_rounded,
                      label: 'Cerrar sesión',
                      iconColor: scheme.primary,
                      labelColor: scheme.primary,
                      onTap: _signOut,
                    ),
                    _Divider(color: borderColor),
                    _SettingsTile(
                      icon: Icons.delete_outline_rounded,
                      label: 'Eliminar cuenta',
                      iconColor: const Color(0xFFFF6B6B),
                      labelColor: const Color(0xFFFF6B6B),
                      onTap: _deleteAccount,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                Center(
                  child: Text('InverTrack v1.0.0',
                      style: tt.bodyMedium?.copyWith(fontSize: 11)),
                ),
              ],
            ),
    );
  }
}

// ── WIDGETS AUXILIARES — sin cambios ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.children,
    required this.cardColor,
    required this.borderColor,
  });

  final List<Widget> children;
  final Color cardColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.value,
    this.iconColor,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final resolvedIconColor = iconColor ?? scheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: resolvedIconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: resolvedIconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: tt.bodyMedium?.copyWith(
                          fontSize: 12, color: labelColor)),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(value!,
                        style: tt.bodyLarge?.copyWith(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: const Color(0xFF7BA7C2), size: 18),
          ],
        ),
      ),
    );
  }
  
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: color, indent: 56, endIndent: 16);
  }
}

