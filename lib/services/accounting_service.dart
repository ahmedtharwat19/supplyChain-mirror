// services/accounting_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart'
    as easy; // <-- إعادة تسمية الاستيراد
import 'package:puresip_purchasing/models/account.dart';
import 'package:puresip_purchasing/models/journal_entry.dart';
import 'package:puresip_purchasing/debug_helper.dart';

class AccountingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── إنشاء الحسابات الافتراضية للشركة ──────────────────────────
  Future<void> createDefaultAccounts({
    required String companyId,
    required String userId,
  }) async {
    try {
      final batch = _firestore.batch();

      final accounts = [
        Account(
          id: '',
          companyId: companyId,
          code: '1000',
          nameAr: easy.tr('account_cash'), // استخدام easy.tr
          nameEn: 'Cash',
          type: AccountType.asset,
          category: AccountCategory.cash,
          createdAt: DateTime.now(),
          balance: 0.0,
        ),
        Account(
          id: '',
          companyId: companyId,
          code: '1100',
          nameAr: easy.tr('account_inventory'),
          nameEn: 'Inventory',
          type: AccountType.asset,
          category: AccountCategory.inventory,
          createdAt: DateTime.now(),
          balance: 0.0,
        ),
        Account(
          id: '',
          companyId: companyId,
          code: '2000',
          nameAr: easy.tr('account_payable'),
          nameEn: 'Accounts Payable',
          type: AccountType.liability,
          category: AccountCategory.accountsPayable,
          createdAt: DateTime.now(),
          balance: 0.0,
        ),
        Account(
          id: '',
          companyId: companyId,
          code: '2100',
          nameAr: easy.tr('account_banks'),
          nameEn: 'Banks',
          type: AccountType.asset,
          category: AccountCategory.bank,
          createdAt: DateTime.now(),
          balance: 0.0,
        ),
        Account(
          id: '',
          companyId: companyId,
          code: '3000',
          nameAr: easy.tr('account_receivable'),
          nameEn: 'Accounts Receivable',
          type: AccountType.asset,
          category: AccountCategory.other,
          createdAt: DateTime.now(),
          balance: 0.0,
        ),
        Account(
          id: '',
          companyId: companyId,
          code: '4000',
          nameAr: easy.tr('account_profit_loss'),
          nameEn: 'Profit/Loss',
          type: AccountType.equity,
          category: AccountCategory.other,
          createdAt: DateTime.now(),
          balance: 0.0,
        ),
      ];

      for (var account in accounts) {
        final docRef = _firestore.collection('accounts').doc();
        batch.set(docRef, {
          ...account.toMap(),
          'id': docRef.id,
          'createdBy': userId,
          'balance': 0.0,
        });
      }

      await batch.commit();
      safeDebugPrint('✅ Default accounts created for company: $companyId');
    } catch (e) {
      safeDebugPrint('❌ Error creating default accounts: $e');
      rethrow;
    }
  }

  // ─── الحصول على حساب معين عن طريق الكود ────────────────────────
  Future<Account?> getAccountByCode({
    required String companyId,
    required String code,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('accounts')
          .where('companyId', isEqualTo: companyId)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Account.fromMap(
            snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      safeDebugPrint('Error getting account by code: $e');
      return null;
    }
  }

  // ─── إنشاء قيد محاسبي لاستلام المشتريات ──────────────────────
  Future<String> createPurchaseReceiptJournalEntry({
    required String companyId,
    required String supplierId,
    required String receiptId,
    required String purchaseOrderId,
    required double totalAmount,
    required String userId,
    required DateTime entryDate,
  }) async {
    try {
      final inventoryAccount = await getAccountByCode(
        companyId: companyId,
        code: '1100',
      );
      final supplierAccount = await getAccountByCode(
        companyId: companyId,
        code: '2000',
      );

      if (inventoryAccount == null || supplierAccount == null) {
        throw Exception('ERR_ACCOUNTS_NOT_FOUND');
      }

      final description = easy.tr(
        'purchase_receipt_description',
        args: [purchaseOrderId],
      );

      final lines = <JournalEntryLine>[
        JournalEntryLine(
          accountId: inventoryAccount.id,
          debit: totalAmount,
          credit: 0.0,
          description: easy.tr(
            'purchase_receipt_debit_inventory',
            args: [purchaseOrderId],
          ),
        ),
        JournalEntryLine(
          accountId: supplierAccount.id,
          debit: 0.0,
          credit: totalAmount,
          description: easy.tr(
            'purchase_receipt_credit_supplier',
            args: [purchaseOrderId],
          ),
        ),
      ];

      final entryId = 'JE-${DateTime.now().millisecondsSinceEpoch}';
      final entry = JournalEntry(
        id: entryId,
        companyId: companyId,
        entryDate: entryDate,
        description: description,
        referenceId: receiptId,
        referenceType: 'stock_receipt',
        lines: lines,
        createdAt: DateTime.now(),
        createdBy: userId,
      );

      final batch = _firestore.batch();

      final entryRef = _firestore.collection('journal_entries').doc(entryId);
      batch.set(entryRef, {
        ...entry.toMap(),
        'supplierId': supplierId,
      });

      for (var line in lines) {
        final balanceChange = line.debit - line.credit;
        final accountRef =
            _firestore.collection('accounts').doc(line.accountId);
        batch.update(accountRef, {
          'balance': FieldValue.increment(balanceChange),
        });
      }

      await batch.commit();

      safeDebugPrint('✅ Journal entry created and balances updated: $entryId');
      return entryId;
    } catch (e) {
      safeDebugPrint('❌ Error creating journal entry: $e');
      rethrow;
    }
  }

  // ─── حركة نقدية (إيداع أو سحب) ──────────────────────────────────
// ─── حركة نقدية (إيداع أو سحب) ──────────────────────────────────
  Future<String> createCashTransactionJournalEntry({
    required String companyId,
    required double amount,
    required String type, // 'deposit' or 'withdrawal'
    required String description,
    required String userId,
    required DateTime entryDate,
  }) async {
    // 1. الحصول على حساب الخزينة (كود 1000)
    final cashAccount =
        await getAccountByCode(companyId: companyId, code: '1000');
    if (cashAccount == null) throw Exception('Cash account not found');

    // 2. البحث عن حساب مقابل مناسب
    Account? contraAccount;

    // تحديد قائمة الأكواد المحتملة حسب نوع العملية
    List<String> possibleCodes;
    if (type == 'deposit') {
      // للإيداع: نفضل حساب البنك (2100) ثم الإيرادات (4000) ثم حساب آخر
      possibleCodes = ['2100', '4000', '3000'];
    } else {
      // للسحب: نفضل حساب المصروفات (5000) ثم الأرباح/الخسائر (4000) ثم حساب آخر
      possibleCodes = ['5000', '4000', '3000'];
    }

    // البحث في الأكواد بالتسلسل
    for (var code in possibleCodes) {
      final acc = await getAccountByCode(companyId: companyId, code: code);
      if (acc != null) {
        contraAccount = acc;
        break;
      }
    }

    // إذا لم يتم العثور على أي حساب مقابل، نستخدم حساب الخزينة نفسه (حل احتياطي)
    if (contraAccount == null) {
      safeDebugPrint(
          '⚠️ No contra account found, using cash account as fallback');
      contraAccount = cashAccount;
    }

    safeDebugPrint(
        '✅ Using contra account: ${contraAccount.code} - ${contraAccount.nameEn}');

    final isDeposit = type == 'deposit';

    String actualDescription = description;
    if (actualDescription.isEmpty) {
      actualDescription =
          easy.tr(isDeposit ? 'cash_deposit' : 'cash_withdrawal');
    }

    final lines = <JournalEntryLine>[
      JournalEntryLine(
        accountId: cashAccount.id,
        debit: isDeposit ? amount : 0.0,
        credit: isDeposit ? 0.0 : amount,
        description: actualDescription,
      ),
      JournalEntryLine(
        accountId: contraAccount.id,
        debit: isDeposit ? 0.0 : amount,
        credit: isDeposit ? amount : 0.0,
        description:
            easy.tr(isDeposit ? 'contra_deposit' : 'contra_withdrawal'),
      ),
    ];

    final entryId = 'JE-${DateTime.now().millisecondsSinceEpoch}';
    final entry = JournalEntry(
      id: entryId,
      companyId: companyId,
      entryDate: entryDate,
      description: actualDescription,
      referenceId: '',
      referenceType: 'cash_transaction',
      lines: lines,
      createdAt: DateTime.now(),
      createdBy: userId,
    );

    final batch = _firestore.batch();
    batch.set(
        _firestore.collection('journal_entries').doc(entryId), entry.toMap());

    for (var line in lines) {
      final balanceChange = line.debit - line.credit;
      final accountRef = _firestore.collection('accounts').doc(line.accountId);
      batch.update(accountRef, {
        'balance': FieldValue.increment(balanceChange),
      });
    }

    await batch.commit();
    safeDebugPrint('✅ Cash transaction recorded: $entryId');
    return entryId;
  }

  // ─── حركة بنكية (إيداع، سحب، تحويل) ────────────────────────────
  Future<String> createBankTransactionJournalEntry({
    required String companyId,
    required String bankAccountId,
    required double amount,
    required String type, // 'deposit', 'withdrawal', 'transfer'
    required String description,
    required String? contraBankAccountId,
    required String userId,
    required DateTime entryDate,
  }) async {
    final bankAccount =
        await _firestore.collection('accounts').doc(bankAccountId).get();
    if (!bankAccount.exists) throw Exception('Bank account not found');

    final isDeposit = type == 'deposit';
    final isWithdrawal = type == 'withdrawal';
    final isTransfer = type == 'transfer';

    String actualDescription = description;
    if (actualDescription.isEmpty) {
      // <-- إضافة الأقواس
      if (isDeposit) {
        actualDescription = easy.tr('bank_deposit');
      } else if (isWithdrawal) {
        actualDescription = easy.tr('bank_withdrawal');
      } else if (isTransfer) {
        actualDescription = easy.tr('bank_transfer');
      }
    }

    List<JournalEntryLine> lines = [];

    lines.add(
      JournalEntryLine(
        accountId: bankAccountId,
        debit: isDeposit || (isTransfer && contraBankAccountId != null)
            ? amount
            : 0.0,
        credit: isWithdrawal || (isTransfer && contraBankAccountId != null)
            ? amount
            : 0.0,
        description: actualDescription,
      ),
    );

    if (isTransfer && contraBankAccountId != null) {
      final contraBank = await _firestore
          .collection('accounts')
          .doc(contraBankAccountId)
          .get();
      if (!contraBank.exists) throw Exception('Contra bank account not found');
      lines.add(
        JournalEntryLine(
          accountId: contraBankAccountId,
          debit: amount,
          credit: 0.0,
          description: easy.tr('bank_transfer_received'),
        ),
      );
      lines[0] = JournalEntryLine(
        accountId: bankAccountId,
        debit: 0.0,
        credit: amount,
        description: easy.tr('bank_transfer_sent'),
      );
    } else {
      final contraAccount =
          await getAccountByCode(companyId: companyId, code: '4000');
      if (contraAccount == null) throw Exception('Contra account not found');
      lines.add(
        JournalEntryLine(
          accountId: contraAccount.id,
          debit: isDeposit ? 0.0 : amount,
          credit: isDeposit ? amount : 0.0,
          description: easy
              .tr(isDeposit ? 'contra_bank_deposit' : 'contra_bank_withdrawal'),
        ),
      );
    }

    final entryId = 'JE-${DateTime.now().millisecondsSinceEpoch}';
    final entry = JournalEntry(
      id: entryId,
      companyId: companyId,
      entryDate: entryDate,
      description: actualDescription,
      referenceId: '',
      referenceType: 'bank_transaction',
      lines: lines,
      createdAt: DateTime.now(),
      createdBy: userId,
    );

    final batch = _firestore.batch();
    batch.set(
        _firestore.collection('journal_entries').doc(entryId), entry.toMap());

    for (var line in lines) {
      final balanceChange = line.debit - line.credit;
      final accountRef = _firestore.collection('accounts').doc(line.accountId);
      batch.update(accountRef, {
        'balance': FieldValue.increment(balanceChange),
      });
    }

    await batch.commit();
    safeDebugPrint('✅ Bank transaction recorded: $entryId');
    return entryId;
  }

  // ─── دفع مستحقات المورد ─────────────────────────────────────────
/*   Future<String> createSupplierPaymentJournalEntry({
    required String companyId,
    required String supplierId,
    required double amount,
    required String paymentMethod,
    required String? bankAccountId,
    required String userId,
    required DateTime entryDate,
  }) async {
    final supplierAccount =
        await getAccountByCode(companyId: companyId, code: '2000');
    if (supplierAccount == null) throw Exception('Supplier account not found');

    String paymentAccountId;
    if (paymentMethod == 'cash') {
      final cashAcc =
          await getAccountByCode(companyId: companyId, code: '1000');
      if (cashAcc == null) throw Exception('Cash account not found');
      paymentAccountId = cashAcc.id;
    } else if (paymentMethod == 'bank') {
      if (bankAccountId == null || bankAccountId.isEmpty) {
        throw Exception('Bank account ID required');
      }
      final bankAcc =
          await _firestore.collection('accounts').doc(bankAccountId).get();
      if (!bankAcc.exists) throw Exception('Bank account not found');
      paymentAccountId = bankAccountId;
    } else {
      throw Exception('Invalid payment method');
    }

    final description = easy.tr(
      'supplier_payment_description',
      args: [supplierId],
    );

    final lines = <JournalEntryLine>[
      JournalEntryLine(
        accountId: supplierAccount.id,
        debit: amount,
        credit: 0.0,
        description: easy.tr('supplier_payment_debit'),
      ),
      JournalEntryLine(
        accountId: paymentAccountId,
        debit: 0.0,
        credit: amount,
        description: paymentMethod == 'cash'
            ? easy.tr('payment_cash')
            : easy.tr('payment_bank'),
      ),
    ];

    final entryId = 'JE-${DateTime.now().millisecondsSinceEpoch}';
    final entry = JournalEntry(
      id: entryId,
      companyId: companyId,
      entryDate: entryDate,
      description: description,
      referenceId: supplierId,
      referenceType: 'supplier_payment',
      lines: lines,
      createdAt: DateTime.now(),
      createdBy: userId,
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection('journal_entries').doc(entryId), {
      ...entry.toMap(),
      'supplierId': supplierId,
    });

    for (var line in lines) {
      final balanceChange = line.debit - line.credit;
      final accountRef = _firestore.collection('accounts').doc(line.accountId);
      batch.update(accountRef, {
        'balance': FieldValue.increment(balanceChange),
      });
    }

    await batch.commit();
    safeDebugPrint('✅ Supplier payment recorded: $entryId');
    return entryId;
  }
 */
// ─── دفع مستحقات المورد ─────────────────────────────────────────
  Future<String> createSupplierPaymentJournalEntry({
    required String companyId,
    required String supplierId,
    required double amount,
    required String paymentMethod,
    required String? bankAccountId,
    required String userId,
    required DateTime entryDate,
  }) async {
    // 1. جلب اسم المورد من قاعدة البيانات
    String supplierName = 'مورد غير معروف';
    try {
      final supplierDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('vendors')
          .doc(supplierId)
          .get();
      if (supplierDoc.exists) {
        final data = supplierDoc.data();
        if (data != null) {
          supplierName = data['nameAr'] ?? data['nameEn'] ?? supplierId;
        }
      }
    } catch (e) {
      safeDebugPrint('⚠️ Could not fetch supplier name: $e');
    }

    final supplierAccount =
        await getAccountByCode(companyId: companyId, code: '2000');
    if (supplierAccount == null) throw Exception('Supplier account not found');

    String paymentAccountId;
    if (paymentMethod == 'cash') {
      final cashAcc =
          await getAccountByCode(companyId: companyId, code: '1000');
      if (cashAcc == null) throw Exception('Cash account not found');
      paymentAccountId = cashAcc.id;
    } else if (paymentMethod == 'bank') {
      if (bankAccountId == null || bankAccountId.isEmpty) {
        throw Exception('Bank account ID required');
      }
      final bankAcc =
          await _firestore.collection('accounts').doc(bankAccountId).get();
      if (!bankAcc.exists) throw Exception('Bank account not found');
      paymentAccountId = bankAccountId;
    } else {
      throw Exception('Invalid payment method');
    }

    // ✅ استخدام اسم المورد في الوصف
    final description = easy.tr(
      'supplier_payment_description',
      args: [supplierName], // تمرير الاسم بدلاً من المعرف
    );

    final lines = <JournalEntryLine>[
      JournalEntryLine(
        accountId: supplierAccount.id,
        debit: amount,
        credit: 0.0,
        description: easy.tr('supplier_payment_debit'),
      ),
      JournalEntryLine(
        accountId: paymentAccountId,
        debit: 0.0,
        credit: amount,
        description: paymentMethod == 'cash'
            ? easy.tr('payment_cash')
            : easy.tr('payment_bank'),
      ),
    ];

    final entryId = 'JE-${DateTime.now().millisecondsSinceEpoch}';
    final entry = JournalEntry(
      id: entryId,
      companyId: companyId,
      entryDate: entryDate,
      description: description,
      referenceId: supplierId,
      referenceType: 'supplier_payment',
      lines: lines,
      createdAt: DateTime.now(),
      createdBy: userId,
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection('journal_entries').doc(entryId), {
      ...entry.toMap(),
      'supplierId': supplierId,
      'supplierName': supplierName, // ✅ إضافة اسم المورد كحقل منفصل
    });

    for (var line in lines) {
      final balanceChange = line.debit - line.credit;
      final accountRef = _firestore.collection('accounts').doc(line.accountId);
      batch.update(accountRef, {
        'balance': FieldValue.increment(balanceChange),
      });
    }

    await batch.commit();
    safeDebugPrint('✅ Supplier payment recorded: $entryId for $supplierName');
    return entryId;
  }

  // ─── تسجيل استلام من عميل ────────────────────────────────────────
  Future<String> createReceivableJournalEntry({
    required String companyId,
    required String customerId,
    required double amount,
    required String paymentMethod,
    required String? bankAccountId,
    required String description,
    required String userId,
    required DateTime entryDate,
  }) async {
    final receivableAccount =
        await getAccountByCode(companyId: companyId, code: '3000');
    if (receivableAccount == null) {
      throw Exception('Receivable account not found');
    }

    String paymentAccountId;
    if (paymentMethod == 'cash') {
      final cashAcc =
          await getAccountByCode(companyId: companyId, code: '1000');
      if (cashAcc == null) throw Exception('Cash account not found');
      paymentAccountId = cashAcc.id;
    } else if (paymentMethod == 'bank') {
      if (bankAccountId == null || bankAccountId.isEmpty) {
        throw Exception('Bank account ID required');
      }
      final bankAcc =
          await _firestore.collection('accounts').doc(bankAccountId).get();
      if (!bankAcc.exists) throw Exception('Bank account not found');
      paymentAccountId = bankAccountId;
    } else {
      throw Exception('Invalid payment method');
    }

    String actualDescription = description;
    if (actualDescription.isEmpty) {
      // <-- إضافة الأقواس
      actualDescription = easy.tr('customer_receipt_default');
    }

    final lines = <JournalEntryLine>[
      JournalEntryLine(
        accountId: paymentAccountId,
        debit: amount,
        credit: 0.0,
        description: paymentMethod == 'cash'
            ? easy.tr('receipt_cash')
            : easy.tr('receipt_bank'),
      ),
      JournalEntryLine(
        accountId: receivableAccount.id,
        debit: 0.0,
        credit: amount,
        description: easy.tr('customer_receipt_credit'),
      ),
    ];

    final entryId = 'JE-${DateTime.now().millisecondsSinceEpoch}';
    final entry = JournalEntry(
      id: entryId,
      companyId: companyId,
      entryDate: entryDate,
      description: actualDescription,
      referenceId: customerId,
      referenceType: 'customer_receipt',
      lines: lines,
      createdAt: DateTime.now(),
      createdBy: userId,
    );

    final batch = _firestore.batch();
    batch.set(_firestore.collection('journal_entries').doc(entryId), {
      ...entry.toMap(),
      'customerId': customerId,
    });

    for (var line in lines) {
      final balanceChange = line.debit - line.credit;
      final accountRef = _firestore.collection('accounts').doc(line.accountId);
      batch.update(accountRef, {
        'balance': FieldValue.increment(balanceChange),
      });
    }

    await batch.commit();
    safeDebugPrint('✅ Customer receipt recorded: $entryId');
    return entryId;
  }

  // ─── تحديث رصيد المورد ──────────────────────────────────────────
  Future<void> updateSupplierBalance({
    required String companyId,
    required String supplierId,
    required double amount,
    bool isCredit = true,
  }) async {
    try {
      final supplierRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('vendors')
          .doc(supplierId);

      final increment = isCredit ? amount : -amount;
      await supplierRef.update({
        'balance': FieldValue.increment(increment),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      safeDebugPrint('Error updating supplier balance: $e');
    }
  }

  /// الحصول على معرف حساب المورد (الكود 2000)
  Future<String?> getSupplierAccountId(String companyId) async {
    try {
      final account = await getAccountByCode(
        companyId: companyId,
        code: '2000',
      );
      return account?.id;
    } catch (e) {
      safeDebugPrint('❌ Error getting supplier account ID: $e');
      return null;
    }
  }

  // داخل AccountingService
// ─── إنشاء فاتورة مبيعات (منتج تام) ──────────────────────────────
Future<String> createSalesInvoiceJournalEntry({
  required String companyId,
  required String customerId,
  required String customerName,
  required double totalAmount,
  required String description,
  required String paymentMethod, // 'cash', 'bank', 'credit'
  required String? bankAccountId,
  required List<Map<String, dynamic>> items, // [{productId, productName, quantity, unitPrice, total}]
  required String userId,
  required DateTime entryDate,
}) async {
  // 1. الحصول على حساب العميل (المستحقات - كود 3000)
  final receivableAccount = await getAccountByCode(companyId: companyId, code: '3000');
  if (receivableAccount == null) throw Exception('Receivable account not found');

  // 2. الحصول على حساب الإيرادات (المبيعات - كود 4000)
  final revenueAccount = await getAccountByCode(companyId: companyId, code: '4000');
  if (revenueAccount == null) throw Exception('Revenue account not found');

  // 3. تحديد حساب الدفع (نقدي أو بنك)
  String paymentAccountId;
  if (paymentMethod == 'cash') {
    final cashAcc = await getAccountByCode(companyId: companyId, code: '1000');
    if (cashAcc == null) throw Exception('Cash account not found');
    paymentAccountId = cashAcc.id;
  } else if (paymentMethod == 'bank') {
    if (bankAccountId == null || bankAccountId.isEmpty) {
      throw Exception('Bank account ID required');
    }
    paymentAccountId = bankAccountId;
  } else {
    // آجل (دين) -> لا يوجد حساب دفع فوري
    paymentAccountId = '';
  }

  // 4. إنشاء سطور القيد
  List<JournalEntryLine> lines = [];

  // السطر الأول: حساب العميل (مدين) أو حساب الخزينة (مدين) حسب طريقة الدفع
  if (paymentMethod == 'credit') {
    // بيع آجل: مدين حساب العميل
    lines.add(JournalEntryLine(
      accountId: receivableAccount.id,
      debit: totalAmount,
      credit: 0.0,
      description: 'فاتورة مبيعات آجلة للعميل: $customerName',
    ));
  } else {
    // بيع نقدي/بنكي: مدين حساب الخزينة أو البنك
    lines.add(JournalEntryLine(
      accountId: paymentAccountId,
      debit: totalAmount,
      credit: 0.0,
      description: 'تحصيل نقدي من العميل: $customerName',
    ));
  }

  // السطر الثاني: دائن حساب الإيرادات (المبيعات)
  lines.add(JournalEntryLine(
    accountId: revenueAccount.id,
    debit: 0.0,
    credit: totalAmount,
    description: 'مبيعات منتجات تامة للعميل: $customerName',
  ));

  // (اختياري) إضافة سطور للمخزون إذا أردت خفض المخزون تلقائياً
  // ولكن الأفضل ترك هذا لنظام إدارة المخزون المنفصل

  final entryId = 'JE-${DateTime.now().millisecondsSinceEpoch}';
  final entry = JournalEntry(
    id: entryId,
    companyId: companyId,
    entryDate: entryDate,
    description: description.isEmpty ? 'فاتورة مبيعات للعميل $customerName' : description,
    referenceId: customerId,
    referenceType: 'sales_invoice',
    lines: lines,
    createdAt: DateTime.now(),
    createdBy: userId,
  );

  final batch = _firestore.batch();
  
  // حفظ القيد مع بيانات إضافية (العميل، المنتجات، إلخ)
  batch.set(_firestore.collection('journal_entries').doc(entryId), {
    ...entry.toMap(),
    'customerId': customerId,
    'customerName': customerName,
    'paymentMethod': paymentMethod,
    'items': items, // حفظ قائمة المنتجات كـ JSON
    'totalAmount': totalAmount,
  });

  // تحديث أرصدة الحسابات
  for (var line in lines) {
    final balanceChange = line.debit - line.credit;
    final accountRef = _firestore.collection('accounts').doc(line.accountId);
    batch.update(accountRef, {
      'balance': FieldValue.increment(balanceChange),
    });
  }

  await batch.commit();
  safeDebugPrint('✅ Sales invoice recorded: $entryId');
  return entryId;
}
}
