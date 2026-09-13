import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/exceptions.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/sticker_picker.dart';

/// Feuille modale « Créer un groupe » (E4).
Future<void> showCreateGroupSheet(BuildContext context, WidgetRef ref) {
  return _showSheet(context, const _CreateGroupSheet());
}

/// Feuille modale « Rejoindre avec un code » (E4).
Future<void> showJoinGroupSheet(BuildContext context, WidgetRef ref) {
  return _showSheet(context, const _JoinGroupSheet());
}

/// Feuille modale « Paramètres du groupe » (E5, admin uniquement — la RLS
/// refuse la mise à jour côté serveur si l'appelant n'est pas admin).
Future<void> showEditGroupSheet(BuildContext context, Group group) {
  return _showSheet(context, _EditGroupSheet(group: group));
}

Future<void> _showSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.nuit,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadii.xl),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenEdge,
        right: AppSpacing.screenEdge,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.l,
      ),
      child: child,
    ),
  );
}

/// En-tête commun des feuilles modales : titre + croix explicite pour
/// revenir en arrière (en plus du geste de balayage vers le bas).
class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.cardTitle)),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            color: AppColors.ardoise,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  int _pointsExact = 3;
  int _pointsResult = 1;
  String _avatarIcon = 'ball';
  String _avatarColor = '#FFB020';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final group = await ref
          .read(groupRepositoryProvider)
          .createGroup(
            name: _name.text,
            description: _description.text,
            pointsExact: _pointsExact,
            pointsResult: _pointsResult,
            avatarIcon: _avatarIcon,
            avatarColor: _avatarColor,
          );
      if (!mounted) return;
      ref.invalidate(myGroupsProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Groupe « ${group.name} » créé.')));
    } on AppException catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader('CRÉER UN GROUPE'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom du groupe'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 3) return 'Au moins 3 caractères.';
                if (t.length > 50) return '50 caractères maximum.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.m),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (facultatif)',
              ),
              maxLength: 200,
            ),
            const SizedBox(height: AppSpacing.s),
            _ScoringRow(
              label: 'Score exact',
              value: _pointsExact,
              min: _pointsResult + 1,
              max: 10,
              onChanged: (v) => setState(() => _pointsExact = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ScoringRow(
              label: 'Bon résultat',
              value: _pointsResult,
              min: 0,
              max: _pointsExact - 1,
              onChanged: (v) => setState(() => _pointsResult = v),
            ),
            const SizedBox(height: AppSpacing.l),
            StickerPicker(
              icon: _avatarIcon,
              color: _avatarColor,
              squared: true,
              onIconChanged: (v) => setState(() => _avatarIcon = v),
              onColorChanged: (v) => setState(() => _avatarColor = v),
            ),
            const SizedBox(height: AppSpacing.s),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const _SpinnerLabel()
                  : const Text('CRÉER LE GROUPE'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditGroupSheet extends ConsumerStatefulWidget {
  const _EditGroupSheet({required this.group});

  final Group group;

  @override
  ConsumerState<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends ConsumerState<_EditGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.group.name);
  late final _description = TextEditingController(
    text: widget.group.description ?? '',
  );
  late int _pointsExact = widget.group.pointsExact;
  late int _pointsResult = widget.group.pointsResult;
  late String _avatarIcon = widget.group.avatarIcon;
  late String _avatarColor = widget.group.avatarColor;
  late bool _showHistory = widget.group.showPredictionHistory;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .updateGroupSettings(
            groupId: widget.group.id,
            name: _name.text,
            description: _description.text,
            pointsExact: _pointsExact,
            pointsResult: _pointsResult,
            avatarIcon: _avatarIcon,
            avatarColor: _avatarColor,
            showPredictionHistory: _showHistory,
          );
      if (!mounted) return;
      ref.invalidate(groupProvider(widget.group.id));
      ref.invalidate(predictionHistoryProvider(widget.group.id));
      ref.invalidate(myGroupsProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Paramètres mis à jour.')));
    } on AppException catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader('PARAMÈTRES DU GROUPE'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom du groupe'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 3) return 'Au moins 3 caractères.';
                if (t.length > 50) return '50 caractères maximum.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.m),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description (facultatif)',
              ),
              maxLength: 200,
            ),
            const SizedBox(height: AppSpacing.s),
            _ScoringRow(
              label: 'Score exact',
              value: _pointsExact,
              min: _pointsResult + 1,
              max: 10,
              onChanged: (v) => setState(() => _pointsExact = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ScoringRow(
              label: 'Bon résultat',
              value: _pointsResult,
              min: 0,
              max: _pointsExact - 1,
              onChanged: (v) => setState(() => _pointsResult = v),
            ),
            const SizedBox(height: AppSpacing.l),
            StickerPicker(
              icon: _avatarIcon,
              color: _avatarColor,
              squared: true,
              onIconChanged: (v) => setState(() => _avatarIcon = v),
              onColorChanged: (v) => setState(() => _avatarColor = v),
            ),
            const SizedBox(height: AppSpacing.l),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showHistory,
              onChanged: (v) => setState(() => _showHistory = v),
              activeThumbColor: AppColors.or,
              title: Text('Historique des pronostics', style: AppText.body),
              subtitle: Text(
                'Visible par tous les membres, onglet du groupe.',
                style: AppText.bodyMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const _SpinnerLabel() : const Text('ENREGISTRER'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoringRow extends StatelessWidget {
  const _ScoringRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.body)),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppText.mono.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _JoinGroupSheet extends ConsumerStatefulWidget {
  const _JoinGroupSheet();

  @override
  ConsumerState<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<_JoinGroupSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  GroupSummary? _preview;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() {
        _preview = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final summary = await ref.read(groupRepositoryProvider).findByCode(code);
      if (mounted) setState(() => _preview = summary);
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _preview = null;
          _error = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final group = await ref
          .read(groupRepositoryProvider)
          .joinByCode(_code.text.trim().toUpperCase());
      if (!mounted) return;
      ref.invalidate(myGroupsProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenue dans « ${group.name} ».')),
      );
    } on AppException catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHeader('REJOINDRE AVEC UN CODE'),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: AppText.mono.copyWith(fontSize: 22, letterSpacing: 6),
          inputFormatters: [
            UpperCaseFormatter(),
            FilteringTextInputFormatter.allow(RegExp('[A-Z0-9]')),
          ],
          decoration: const InputDecoration(
            hintText: 'ABC234',
            counterText: '',
          ),
          onChanged: (_) => _lookup(),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_busy && _preview == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.s),
              child: CircularProgressIndicator(color: AppColors.or),
            ),
          )
        else if (_error != null)
          Text(_error!, textAlign: TextAlign.center, style: AppText.bodyMuted)
        else if (_preview != null)
          AppCard(
            child: Text(
              '${_preview!.name} · ${_preview!.memberCount} membres',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: AppSpacing.l),
        ElevatedButton(
          onPressed: (_preview != null && !_busy) ? _join : null,
          child: _busy && _preview != null
              ? const _SpinnerLabel()
              : const Text('REJOINDRE'),
        ),
      ],
    );
  }
}

/// Force les majuscules dans le champ code d'invitation.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _SpinnerLabel extends StatelessWidget {
  const _SpinnerLabel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surOr),
    );
  }
}
