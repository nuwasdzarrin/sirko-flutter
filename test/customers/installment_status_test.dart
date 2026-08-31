import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/tables/installments.dart';
import 'package:sirko/features/customers/domain/installment_status.dart';

/// §7 — status cicilan (murni). `overdue` diturunkan dari waktu.
void main() {
  const now = 1000000; // acuan "sekarang" (epoch ms) untuk test deterministik.

  group('installmentStatusFor', () {
    test('paid bila sudah lunas (amountPaid >= amountDue)', () {
      expect(
        installmentStatusFor(
            amountDue: 10000, amountPaid: 10000, dueDate: 0, now: now),
        InstallmentStatus.paid,
      );
      // Lebih bayar juga dianggap lunas.
      expect(
        installmentStatusFor(
            amountDue: 10000, amountPaid: 12000, dueDate: 0, now: now),
        InstallmentStatus.paid,
      );
    });

    test('overdue bila belum lunas & sudah lewat tempo', () {
      expect(
        installmentStatusFor(
            amountDue: 10000, amountPaid: 4000, dueDate: now - 1, now: now),
        InstallmentStatus.overdue,
      );
    });

    test('pending bila belum lunas & belum lewat tempo', () {
      expect(
        installmentStatusFor(
            amountDue: 10000, amountPaid: 0, dueDate: now + 1, now: now),
        InstallmentStatus.pending,
      );
    });

    test('batas tepat hari ini (dueDate == now) → belum lewat → pending', () {
      expect(
        installmentStatusFor(
            amountDue: 10000, amountPaid: 0, dueDate: now, now: now),
        InstallmentStatus.pending,
      );
    });

    test('lunas menang atas lewat tempo (dueDate lampau tapi lunas → paid)',
        () {
      expect(
        installmentStatusFor(
            amountDue: 10000, amountPaid: 10000, dueDate: now - 999, now: now),
        InstallmentStatus.paid,
      );
    });
  });

  group('installmentRemaining', () {
    test('sisa = amountDue - amountPaid, clamp ≥ 0', () {
      expect(installmentRemaining(amountDue: 10000, amountPaid: 3000), 7000);
      expect(installmentRemaining(amountDue: 10000, amountPaid: 12000), 0);
      expect(installmentRemaining(amountDue: 10000, amountPaid: 10000), 0);
    });
  });
}
