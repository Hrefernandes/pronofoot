import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronofoot/core/hex.dart';
import 'package:pronofoot/core/stickers.dart';

void main() {
  group('stickerForegroundColor', () {
    test('fond clair → symbole sombre', () {
      expect(
        stickerForegroundColor(colorFromHex('#FFB020')),
        const Color(0xFF0B1220),
      );
    });

    test('fond sombre → symbole clair', () {
      expect(
        stickerForegroundColor(colorFromHex('#0B1220')),
        const Color(0xFFF2F5FF),
      );
    });

    test('la palette sélectionnable ne contient jamais le vert `exact`', () {
      // Contrainte non négociable du dossier : #5CE28A est réservé au badge
      // « score exact » et ne doit jamais être proposé comme avatar.
      expect(Stickers.colors, isNot(contains('#5CE28A')));
    });
  });

  group('Stickers.byCode', () {
    test('code connu → sticker correspondant', () {
      expect(Stickers.byCode('fire').icon, Icons.local_fire_department);
    });

    test('code inconnu → repli silencieux sur le premier sticker', () {
      expect(Stickers.byCode('inexistant'), Stickers.all.first);
      expect(Stickers.byCode(null), Stickers.all.first);
    });
  });
}
