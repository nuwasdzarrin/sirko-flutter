import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/users.dart';
import '../../../core/errors/failures.dart';
import '../application/user_providers.dart';
import '../domain/permission.dart';
import '../domain/permission_resolver.dart';

const _minPinLength = 6;

/// Form tambah/edit karyawan + editor permission (role `custom`). Owner tak
/// bisa diubah peran/PIN dari sini kecuali dirinya sendiri (disederhanakan:
/// owner hanya bisa edit nama).
class UserFormScreen extends ConsumerStatefulWidget {
  final User? user;
  const UserFormScreen({super.key, this.user});

  bool get isEdit => user != null;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  final _pin = TextEditingController();
  final _pinConfirm = TextEditingController();

  late AppRole _role;
  late bool _isActive;
  late Set<Permission> _customPermissions;
  bool _submitting = false;

  bool get _isOwner => widget.user?.role == AppRole.owner;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _name = TextEditingController(text: u?.name ?? '');
    _username = TextEditingController(text: u?.username ?? '');
    _role = u?.role ?? AppRole.cashier;
    _isActive = u?.isActive ?? true;
    _customPermissions = u == null
        ? <Permission>{}
        : PermissionResolver.decodePermissions(u.permissions);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _pin.dispose();
    _pinConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final repo = ref.read(userRepositoryProvider);
    try {
      if (widget.isEdit) {
        if (!_isOwner) {
          await repo.update(
            widget.user!.id,
            name: _name.text.trim(),
            username: _username.text.trim(),
            role: _role,
            permissions: _customPermissions,
            isActive: _isActive,
          );
        } else {
          // Owner: hanya nama yang boleh diubah dari form ini.
          await repo.update(
            widget.user!.id,
            name: _name.text.trim(),
            username: widget.user!.username,
            role: AppRole.owner,
            isActive: true,
          );
        }
        if (_pin.text.isNotEmpty) {
          await repo.changePin(widget.user!.id, _pin.text);
        }
      } else {
        await repo.create(
          name: _name.text.trim(),
          username: _username.text.trim(),
          pin: _pin.text,
          role: _role,
          permissions: _customPermissions,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Karyawan' : 'Tambah Karyawan'),
        actions: [
          IconButton(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _username,
              enabled: !_isOwner,
              decoration: const InputDecoration(
                labelText: 'Username (untuk login)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Username wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            if (!_isOwner)
              DropdownButtonFormField<AppRole>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Peran',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: AppRole.admin, child: Text('Admin')),
                  DropdownMenuItem(
                      value: AppRole.cashier, child: Text('Kasir')),
                  DropdownMenuItem(value: AppRole.staff, child: Text('Staf')),
                  DropdownMenuItem(
                      value: AppRole.custom, child: Text('Custom')),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              )
            else
              const ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: Text('Pemilik'),
                subtitle: Text('Akses penuh (tak dapat diubah).'),
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: widget.isEdit
                    ? 'PIN baru (kosongkan bila tak diubah)'
                    : 'PIN',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (!widget.isEdit && (v == null || v.length < _minPinLength)) {
                  return 'PIN minimal $_minPinLength digit';
                }
                if (widget.isEdit &&
                    v != null &&
                    v.isNotEmpty &&
                    v.length < _minPinLength) {
                  return 'PIN minimal $_minPinLength digit';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pinConfirm,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Ulangi PIN',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (_pin.text.isNotEmpty && v != _pin.text) ? 'PIN tidak sama' : null,
            ),
            if (!_isOwner) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Aktif'),
                subtitle: const Text('User nonaktif tak bisa login.'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            if (_role == AppRole.custom && !_isOwner) ...[
              const Divider(height: 32),
              Text('Izin (Custom)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final p in Permission.values)
                CheckboxListTile(
                  value: _customPermissions.contains(p),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _customPermissions.add(p);
                    } else {
                      _customPermissions.remove(p);
                    }
                  }),
                  title: Text(p.label),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
