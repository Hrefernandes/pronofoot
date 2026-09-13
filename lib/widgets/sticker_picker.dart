import 'package:flutter/material.dart';

import '../core/hex.dart';
import '../core/stickers.dart';
import '../core/theme.dart';
import 'group_avatar.dart';
import 'profile_avatar.dart';

/// Sélecteur de sticker + couleur, réutilisé pour le profil (E6) et les
/// groupes (E4/E5) — même catalogue, seule la forme de l'aperçu change.
class StickerPicker extends StatelessWidget {
  const StickerPicker({
    super.key,
    required this.icon,
    required this.color,
    required this.onIconChanged,
    required this.onColorChanged,
    this.squared = false,
  });

  final String icon;
  final String color;
  final bool squared;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<String> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: squared
              ? GroupAvatar(icon: icon, color: color, size: 64)
              : ProfileAvatar(icon: icon, color: color, size: 64),
        ),
        const SizedBox(height: AppSpacing.l),
        Text('COULEUR', style: AppText.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final hex in Stickers.colors)
              _ColorSwatch(
                hex: hex,
                selected: hex.toUpperCase() == color.toUpperCase(),
                onTap: () => onColorChanged(hex),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        _StickerGroup(
          label: 'Football',
          items: Stickers.football,
          selectedCode: icon,
          onSelected: onIconChanged,
        ),
        _StickerGroup(
          label: 'Animaux',
          items: Stickers.animaux,
          selectedCode: icon,
          onSelected: onIconChanged,
        ),
        _StickerGroup(
          label: 'Symboles',
          items: Stickers.symboles,
          selectedCode: icon,
          onSelected: onIconChanged,
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: AppColors.craie, width: 2)
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorFromHex(hex),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _StickerGroup extends StatelessWidget {
  const _StickerGroup({
    required this.label,
    required this.items,
    required this.selectedCode,
    required this.onSelected,
  });

  final String label;
  final List<StickerDef> items;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label.toUpperCase(), style: AppText.eyebrow),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final sticker in items)
                _StickerButton(
                  sticker: sticker,
                  selected: sticker.code == selectedCode,
                  onTap: () => onSelected(sticker.code),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickerButton extends StatelessWidget {
  const _StickerButton({
    required this.sticker,
    required this.selected,
    required this.onTap,
  });

  final StickerDef sticker;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: sticker.label,
      child: Material(
        color: selected ? AppColors.or : AppColors.tribune,
        borderRadius: AppRadii.allS,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.allS,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: AppRadii.allS,
              border: Border.all(
                color: selected ? AppColors.or : AppColors.ligne,
              ),
            ),
            child: Icon(
              sticker.icon,
              size: 22,
              color: selected ? AppColors.surOr : AppColors.craie,
            ),
          ),
        ),
      ),
    );
  }
}
