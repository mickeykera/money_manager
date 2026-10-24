import '../../core/constants/app_constants.dart';
import '../../core/utils/money.dart';

class AccountModel {
  final String id;
  final String name;
  final String type; // 'bank', 'mobile_money', 'cash', 'other'
  final int balanceSantims;
  final String currency;
  final String? accountNumberMasked;
  final bool isSmsLinked;
  final String balanceSource; // 'Latest imported SMS', 'Manual entry'
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    this.balanceSantims = 0,
    this.currency = AppConstants.defaultCurrency,
    this.accountNumberMasked,
    this.isSmsLinked = true,
    this.balanceSource = 'Latest imported SMS',
    required this.createdAt,
    required this.updatedAt,
  });

  Money get balance => Money(balanceSantims, currency: currency);

  AccountModel copyWith({
    String? id,
    String? name,
    String? type,
    int? balanceSantims,
    String? currency,
    String? accountNumberMasked,
    bool? isSmsLinked,
    String? balanceSource,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balanceSantims: balanceSantims ?? this.balanceSantims,
      currency: currency ?? this.currency,
      accountNumberMasked: accountNumberMasked ?? this.accountNumberMasked,
      isSmsLinked: isSmsLinked ?? this.isSmsLinked,
      balanceSource: balanceSource ?? this.balanceSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance_santims': balanceSantims,
      'currency': currency,
      'account_number_masked': accountNumberMasked,
      'is_sms_linked': isSmsLinked ? 1 : 0,
      'balance_source': balanceSource,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    final defaultIsSms = type != AppConstants.accountTypeCash;
    return AccountModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: type,
      balanceSantims: (map['balance_santims'] as int?) ?? 0,
      currency: (map['currency'] as String?) ?? AppConstants.defaultCurrency,
      accountNumberMasked: map['account_number_masked'] as String?,
      isSmsLinked: map['is_sms_linked'] != null ? (map['is_sms_linked'] as int) == 1 : defaultIsSms,
      balanceSource: (map['balance_source'] as String?) ?? (defaultIsSms ? 'Latest imported SMS' : 'Manual entry'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
