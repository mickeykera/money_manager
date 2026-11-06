import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/services/android_sms_service.dart';

void main() {
  group('AndroidSmsService.looksLikeFinancialSms', () {
    test('matches CBE debit alerts', () {
      expect(
        AndroidSmsService.looksLikeFinancialSms(
          'Dear Customer, ETB 64.80 has been debited from your account 1000***4821. Balance: ETB 4,280.50.',
          sender: '127',
        ),
        isTrue,
      );
    });

    test('matches Telebirr and M-PESA alerts', () {
      expect(
        AndroidSmsService.looksLikeFinancialSms(
          'Your payment of ETB 180.00 to Kaldis Coffee completed. Trans ID: R5678GH.',
          sender: 'Telebirr',
        ),
        isTrue,
      );
      expect(
        AndroidSmsService.looksLikeFinancialSms(
          'TD94RNM67E Confirmed. ETB 450.00 paid to Safaricom Supermarket. New M-PESA balance is ETB 1,820.00.',
          sender: '700',
        ),
        isTrue,
      );
    });

    test('matches telecom bundle updates', () {
      expect(
        AndroidSmsService.looksLikeFinancialSms(
          'You have successfully purchased 10GB Monthly Data bundle for ETB 300.00.',
          sender: '994',
        ),
        isTrue,
      );
      expect(
        AndroidSmsService.looksLikeFinancialSms(
          'Your remaining package balance is 7.20 GB Data valid until 2026-11-24.',
          sender: 'Ethio telecom',
        ),
        isTrue,
      );
      expect(
        AndroidSmsService.looksLikeFinancialSms(
          'Dear customer, you have purchased 145 Minutes. Valid until 2026-11-24.',
          sender: '994',
        ),
        isTrue,
      );
    });

    test('matches Amharic financial keywords', () {
      expect(
        AndroidSmsService.looksLikeFinancialSms(
          'ከሂሳብዎ ብር 500.00 ተቀንሷል። ቀሪ ሂሳብዎ ብር 2,000.00 ነው።',
          sender: 'CBE',
        ),
        isTrue,
      );
    });

    test('ignores personal messages', () {
      expect(
        AndroidSmsService.looksLikeFinancialSms(
          'Hey, are we still meeting at 6pm for dinner?',
          sender: '+251911223344',
        ),
        isFalse,
      );
      expect(
        AndroidSmsService.looksLikeFinancialSms(
          'Happy birthday! Have a wonderful day.',
          sender: '+251922334455',
        ),
        isFalse,
      );
    });
  });
}
