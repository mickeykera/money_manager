import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../domain/models/transaction_model.dart';
import '../../services/app_state.dart';

class AddTransactionScreen extends StatefulWidget {
  final AppState appState;
  final TransactionModel? existingTransaction;

  const AddTransactionScreen({
    super.key,
    required this.appState,
    this.existingTransaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TextEditingController _notesController;
  late TextEditingController _referenceController;

  late String _selectedType;
  late String _selectedCategoryId;
  late String _selectedAccountId;
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;

    _amountController = TextEditingController(
      text: existing != null ? (existing.amountSantims / 100.0).toStringAsFixed(2) : '',
    );
    _merchantController = TextEditingController(text: existing?.merchant ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _referenceController = TextEditingController(text: existing?.reference ?? '');

    _selectedType = existing?.type ?? AppConstants.typeExpense;

    _selectedCategoryId = existing?.categoryId ??
        (widget.appState.categories.isNotEmpty ? widget.appState.categories.first.id : 'cat_other');

    _selectedAccountId = existing?.accountId ??
        (widget.appState.accounts.isNotEmpty ? widget.appState.accounts.first.id : 'acc_cbe');

    _selectedDateTime = existing?.timestamp ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final money = Money.parseString(_amountController.text.trim());
    if (money.santims <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than 0')),
      );
      return;
    }

    const uuid = Uuid();
    final existing = widget.existingTransaction;

    final tx = TransactionModel(
      id: existing?.id ?? uuid.v4(),
      amountSantims: money.santims.abs(),
      currency: AppConstants.defaultCurrency,
      type: _selectedType,
      merchant: _merchantController.text.trim(),
      timestamp: _selectedDateTime,
      categoryId: _selectedCategoryId,
      accountId: _selectedAccountId,
      source: existing?.source ?? AppConstants.sourceManual,
      importStatus: existing?.importStatus ?? AppConstants.statusPosted,
      sourceFingerprint: existing?.sourceFingerprint,
      originalMessage: existing?.originalMessage,
      reference: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      isReviewed: true,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (existing != null) {
      await widget.appState.updateTransaction(tx);
    } else {
      await widget.appState.addTransaction(tx);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final isEditing = widget.existingTransaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Transaction Type Selector (Expense, Income, Transfer, Refund, Reversal)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: AppConstants.typeExpense, label: Text('Expense')),
                ButtonSegment(value: AppConstants.typeIncome, label: Text('Income')),
                ButtonSegment(value: AppConstants.typeTransfer, label: Text('Transfer')),
                ButtonSegment(value: AppConstants.typeRefund, label: Text('Refund')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) {
                setState(() => _selectedType = set.first);
              },
            ),
            const SizedBox(height: 24),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount (ETB)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondaryTextColor),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      prefixText: 'ETB ',
                      prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                      hintText: '0.00',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter an amount';
                      final parsed = Money.parseString(val);
                      if (parsed.santims <= 0) return 'Amount must be greater than zero';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Merchant / Counterparty
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: 'Merchant or Description',
                hintText: 'e.g. Kaldi\'s Coffee, Fresh Corner, Rent',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Enter description or merchant';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: widget.appState.categories.map((cat) {
                return DropdownMenuItem(
                  value: cat.id,
                  child: Row(
                    children: [
                      Icon(
                        IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
                        size: 18,
                        color: Color(cat.colorValue),
                      ),
                      const SizedBox(width: 10),
                      Text(cat.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategoryId = val);
              },
            ),
            const SizedBox(height: 16),

            // Account Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountId,
              decoration: const InputDecoration(
                labelText: 'Account / Payment Source',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: widget.appState.accounts.map((acc) {
                return DropdownMenuItem(
                  value: acc.id,
                  child: Text(acc.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedAccountId = val);
              },
            ),
            const SizedBox(height: 16),

            // Date & Time Picker
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date & Time',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  DateFormat('yyyy-MM-dd, hh:mm a').format(_selectedDateTime),
                  style: TextStyle(color: primaryTextColor),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bank Reference (Optional)
            TextFormField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Bank Reference Code (Optional)',
                hintText: 'e.g. FT242981234, TB261024.1430',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Notes (Optional)
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add personal notes or receipts info...',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(isEditing ? 'Save Changes' : 'Record Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
