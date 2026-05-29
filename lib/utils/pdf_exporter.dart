import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:puresip_purchasing/debug_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:number_to_word_arabic/number_to_word_arabic.dart';
import 'package:number_to_words_english/number_to_words_english.dart';

class PdfExporter {
  static const double _headerFontSize = 16;
  static const double _mediumFontSize = 12;
  static const double _bodyFontSize = 10;
  static const double _smallFontSize = 8;
  static const pw.EdgeInsets _cellPadding =
      pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3);

  static pw.Font? _cachedArabicFont;
  static pw.Font? _cachedLatinFont;

  static Future<String> _getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('displayName') ?? 'no_name'.tr();
  }

  static Future<pw.Document> generatePurchaseOrderPdf({
    required String orderId,
    required Map<String, dynamic> orderData,
    required Map<String, dynamic> supplierData,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> itemData,
    String? base64Logo,
    bool isArabic = true,
    Map<String, List<Map<String, dynamic>>>? additionalItems,
  }) async {
    final userName = await _getUserName();
    final pdf = pw.Document();
    final logoBytes = _decodeBase64Logo(base64Logo);

    final poNumber = orderData['poNumber']?.toString().isNotEmpty == true
        ? orderData['poNumber'].toString()
        : orderId;

    final qrData = _generateDetailedQrData(
        poNumber, orderData, supplierData, companyData, isArabic);
    final qrImage = await _generateRealQrImage(qrData, 150);

    final arabicFont = await _getArabicFont();
    final latinFont = await _getLatinFont();

    final additionalItemsWidget = await _getAdditionalItemsWidget(
      orderData,
      additionalItems,
      isArabic,
      arabicFont,
    );

    pdf.addPage(
      pw.Page(
        theme:
            pw.ThemeData.withFont(base: arabicFont, fontFallback: [latinFont]),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(orderData, companyData, qrImage, logoBytes,
                    isArabic, arabicFont),
                pw.SizedBox(height: 10),
                _buildSupplierSection(supplierData, isArabic, arabicFont),
                pw.SizedBox(height: 10),
                _buildOrderItemsTable(orderData, arabicFont, isArabic),
                pw.SizedBox(height: 8),
                _buildTaxExemptNote(orderData, isArabic, arabicFont),
                pw.SizedBox(height: 8),
                _buildOrderSummary(orderData, arabicFont, isArabic),
                pw.SizedBox(height: 8),
                _buildTermsTable(orderData, arabicFont, isArabic),
                pw.SizedBox(height: 8),
                additionalItemsWidget,
                pw.Expanded(child: pw.SizedBox()),
                _buildFooter(companyData, isArabic, arabicFont, userName),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  // ==================== العناصر الإضافية ====================
  static Future<pw.Widget> _getAdditionalItemsWidget(
    Map<String, dynamic> orderData,
    Map<String, List<Map<String, dynamic>>>? additionalItems,
    bool isArabic,
    pw.Font arabicFont,
  ) async {
    if (additionalItems != null) {
      return _buildAdditionalItemsList(additionalItems, isArabic, arabicFont);
    }

    final conditionsIds = List<String>.from(orderData['conditionsIds'] ?? []);
    final documentsIds = List<String>.from(orderData['documentsIds'] ?? []);
    final notesIds = List<String>.from(orderData['notesIds'] ?? []);

    if (conditionsIds.isEmpty && documentsIds.isEmpty && notesIds.isEmpty) {
      return pw.SizedBox();
    }

    final firestore = FirebaseFirestore.instance;
    final Map<String, List<Map<String, dynamic>>> loadedItems = {
      'conditions': [],
      'documents': [],
      'notes': [],
    };

    final allIds = [...conditionsIds, ...documentsIds, ...notesIds];

    if (allIds.isNotEmpty) {
      List<Map<String, dynamic>> allItems = [];

      for (int i = 0; i < allIds.length; i += 10) {
        final end = (i + 10 < allIds.length) ? i + 10 : allIds.length;
        final batchIds = allIds.sublist(i, end);

        final snapshot = await firestore
            .collection('additional_items')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          allItems.add({
            'id': doc.id,
            'titleAr': data['titleAr'] ?? '',
            'titleEn': data['titleEn'] ?? '',
          });
        }
      }

      for (var item in allItems) {
        final id = item['id'] as String;
        if (conditionsIds.contains(id)) {
          loadedItems['conditions']!.add(item);
        } else if (documentsIds.contains(id)) {
          loadedItems['documents']!.add(item);
        } else if (notesIds.contains(id)) {
          loadedItems['notes']!.add(item);
        }
      }
    }

    return _buildAdditionalItemsList(loadedItems, isArabic, arabicFont);
  }

  static pw.Widget _buildAdditionalItemsList(
    Map<String, List<Map<String, dynamic>>> additionalItems,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    final conditions = additionalItems['conditions'] ?? [];
    final documents = additionalItems['documents'] ?? [];
    final notes = additionalItems['notes'] ?? [];

    if (conditions.isEmpty && documents.isEmpty && notes.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (conditions.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
            ),
            child: pw.Text(
              isArabic ? 'الشروط الإضافية' : 'Additional Conditions',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          ...conditions.map((c) => pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: pw.TextStyle(font: arabicFont)),
                    pw.Expanded(
                      child: pw.Text(
                        isArabic ? c['titleAr'] : c['titleEn'],
                        style: pw.TextStyle(
                          fontSize: _smallFontSize,
                          font: arabicFont,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
        if (documents.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
            ),
            child: pw.Text(
              isArabic ? 'المستندات المطلوبة' : 'Required Documents',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          ...documents.map((d) => pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: pw.TextStyle(font: arabicFont)),
                    pw.Expanded(
                      child: pw.Text(
                        isArabic ? d['titleAr'] : d['titleEn'],
                        style: pw.TextStyle(
                          fontSize: _smallFontSize,
                          font: arabicFont,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
        if (notes.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
            ),
            child: pw.Text(
              isArabic ? 'ملاحظات' : 'Notes',
              style: pw.TextStyle(
                fontSize: _bodyFontSize,
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          ...notes.map((n) => pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: pw.TextStyle(font: arabicFont)),
                    pw.Expanded(
                      child: pw.Text(
                        isArabic ? n['titleAr'] : n['titleEn'],
                        style: pw.TextStyle(
                          fontSize: _smallFontSize,
                          font: arabicFont,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  // ==================== QR Code ====================
  static String _generateDetailedQrData(
    String poNumber,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    bool isArabic,
  ) {
    final total = (orderData['netPayable'] ?? 0.0).toDouble();

    final qrContent = {
      'po': poNumber,
      'date': _formatOrderDate(orderData['orderDate']),
      'company': isArabic ? companyData['nameAr'] : companyData['nameEn'],
      'supplier': isArabic ? supplierData['nameAr'] : supplierData['nameEn'],
      'total': total,
    };

    return jsonEncode(qrContent);
  }

  static Future<pw.Widget> _generateRealQrImage(
      String data, double size) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        gapless: false,
      );
      final image = await qrPainter.toImageData(size.toDouble());
      if (image == null) throw Exception('Failed to generate QR image');
      return pw.Container(
        width: size,
        height: size,
        child: pw.Image(pw.MemoryImage(image.buffer.asUint8List())),
      );
    } catch (e) {
      safeDebugPrint('Error generating QR: $e');
      return pw.Container(
        width: size,
        height: size,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Center(
          child: pw.Text(
            'QR',
            style: pw.TextStyle(
                fontSize: size * 0.2, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
    }
  }

  // ==================== جدول الأصناف ====================
  static pw.Widget _buildOrderItemsTable(
      Map<String, dynamic> orderData, pw.Font arabicFont, bool isArabic) {
    final items = orderData['items'] ?? [];

    final columnWidths = {
      0: isArabic ? const pw.FlexColumnWidth(1) : const pw.FlexColumnWidth(3),
      1: const pw.FlexColumnWidth(1),
      2: const pw.FlexColumnWidth(1),
      3: const pw.FlexColumnWidth(1),
      4: isArabic ? const pw.FlexColumnWidth(3) : const pw.FlexColumnWidth(1),
    };

    final headers = isArabic
        ? ['الإجمالي', 'الضريبة', 'السعر', 'الكمية', 'الصنف']
        : ['Item', 'Qty', 'Price', 'Tax', 'Total'];

    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: columnWidths,
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: headers
                .map((header) => _buildHeaderCell(header, arabicFont, isArabic))
                .toList(),
          ),
          ...items.map((item) {
            final itemName =
                isArabic ? (item['nameAr'] ?? '') : (item['nameEn'] ?? '');
            final isTaxable = item['isTaxable'] ?? true;
            final displayName = isTaxable ? itemName : '* $itemName';
            final taxText = isTaxable
                ? _formatCurrency(item['taxAmount'])
                : (isArabic ? 'معفى' : 'Exempt');

            final cells = isArabic
                ? [
                    _buildCell(_formatCurrency(item['totalAfterTaxAmount']),
                        arabicFont, isArabic,
                        align: pw.TextAlign.center),
                    _buildCell(taxText, arabicFont, isArabic,
                        align: pw.TextAlign.center),
                    _buildCell(_formatCurrency(item['unitPrice']), arabicFont,
                        isArabic,
                        align: pw.TextAlign.center),
                    _buildCell(item['quantity']?.toString() ?? '', arabicFont,
                        isArabic,
                        align: pw.TextAlign.center),
                    _buildCell(displayName, arabicFont, isArabic,
                        align: pw.TextAlign.right),
                  ]
                : [
                    _buildCell(displayName, arabicFont, isArabic,
                        align: pw.TextAlign.left),
                    _buildCell(item['quantity']?.toString() ?? '', arabicFont,
                        isArabic,
                        align: pw.TextAlign.center),
                    _buildCell(_formatCurrency(item['unitPrice']), arabicFont,
                        isArabic,
                        align: pw.TextAlign.center),
                    _buildCell(taxText, arabicFont, isArabic,
                        align: pw.TextAlign.center),
                    _buildCell(_formatCurrency(item['totalAfterTaxAmount']),
                        arabicFont, isArabic,
                        align: pw.TextAlign.center),
                  ];

            return pw.TableRow(children: cells);
          }),
        ],
      ),
    );
  }

  // ==================== جدول الملخص ====================
  static pw.Widget _buildOrderSummary(
      Map<String, dynamic> orderData, pw.Font arabicFont, bool isArabic) {
    final subtotal = (orderData['totalAmount'] ?? 0.0).toDouble();
    final tax = (orderData['totalTax'] ?? 0.0).toDouble();
    final withholdingAmount =
        (orderData['withholdingTaxAmount'] ?? 0.0).toDouble();
    final total = subtotal + tax - withholdingAmount;
    final currency = orderData['currency'] ?? 'EGP';

    final columnWidths = isArabic
        ? {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(2)}
        : {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1)};

    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Column(
        children: [
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: columnWidths,
            children: [
              _buildSummaryRow(
                label: isArabic ? 'الإجمالي الفرعي' : 'Subtotal',
                value: _formatCurrency(subtotal),
                isArabic: isArabic,
                arabicFont: arabicFont,
              ),
              _buildSummaryRow(
                label: isArabic ? 'الضريبة' : 'Tax',
                value: _formatCurrency(tax),
                isArabic: isArabic,
                arabicFont: arabicFont,
              ),
              if (withholdingAmount > 0)
                _buildSummaryRow(
                  label: isArabic ? 'ضريبة الخصم من المنبع' : 'Withholding Tax',
                  value: '-${_formatCurrency(withholdingAmount)}',
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                ),
              _buildSummaryRow(
                label: isArabic ? 'الإجمالي' : 'Total',
                value: _formatCurrency(total),
                isArabic: isArabic,
                arabicFont: arabicFont,
                isTotal: true,
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          _buildAmountInWordsRow(total, currency, isArabic, arabicFont),
        ],
      ),
    );
  }

  static pw.TableRow _buildSummaryRow({
    required String label,
    required String value,
    required bool isArabic,
    required pw.Font arabicFont,
    bool isTotal = false,
  }) {
    return pw.TableRow(
      decoration:
          isTotal ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
      children: isArabic
          ? [
              _buildCell(value, arabicFont, isArabic,
                  align: pw.TextAlign.right, isBold: isTotal),
              _buildCell(label, arabicFont, isArabic,
                  align: pw.TextAlign.right, isBold: isTotal),
            ]
          : [
              _buildCell(label, arabicFont, isArabic,
                  align: pw.TextAlign.left, isBold: isTotal),
              _buildCell(value, arabicFont, isArabic,
                  align: pw.TextAlign.right, isBold: isTotal),
            ],
    );
  }

  // ==================== شروط الدفع والتسليم ====================
  static pw.Widget _buildTermsTable(
      Map<String, dynamic> orderData, pw.Font arabicFont, bool isArabic) {
    final paymentTermText = orderData['paymentTermText']?.toString();
    final deliveryTermText = orderData['deliveryTermText']?.toString();

    String paymentText = '';
    String deliveryText = '';

    if (paymentTermText != null && paymentTermText.isNotEmpty) {
      paymentText = paymentTermText;
    } else {
      final paymentTermCode = orderData['paymentTermCode']?.toString();
      paymentText = _getPaymentTermText(paymentTermCode, isArabic);
    }

    if (deliveryTermText != null && deliveryTermText.isNotEmpty) {
      deliveryText = deliveryTermText;
    } else {
      final deliveryTermCode = orderData['deliveryTermCode']?.toString();
      deliveryText = _getDeliveryTermText(deliveryTermCode, isArabic);
    }

    if ((paymentText.isEmpty) && (deliveryText.isEmpty)) {
      return pw.SizedBox();
    }

    final columnWidths = isArabic
        ? {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)}
        : {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(3)};

    final List<Map<String, String>> rows = [];
    if (paymentText.isNotEmpty) {
      rows.add({
        'label': isArabic ? 'شروط الدفع' : 'Payment Terms',
        'value': paymentText,
      });
    }
    if (deliveryText.isNotEmpty) {
      rows.add({
        'label': isArabic ? 'شروط التسليم' : 'Delivery Terms',
        'value': deliveryText,
      });
    }

    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: columnWidths,
        children: rows.map((row) {
          return pw.TableRow(
            children: isArabic
                ? [
                    _buildCell(row['value']!, arabicFont, isArabic,
                        align: pw.TextAlign.right),
                    _buildCell(row['label']!, arabicFont, isArabic,
                        align: pw.TextAlign.right),
                  ]
                : [
                    _buildCell(row['label']!, arabicFont, isArabic,
                        align: pw.TextAlign.left),
                    _buildCell(row['value']!, arabicFont, isArabic,
                        align: pw.TextAlign.left),
                  ],
          );
        }).toList(),
      ),
    );
  }

  static String _getPaymentTermText(String? code, bool isArabic) {
    switch (code) {
      case 'CASH':
        return isArabic ? 'دفع نقدي' : 'Cash';
      case 'NET_30':
        return isArabic ? 'صافي 30 يوم' : 'Net 30';
      case 'NET_45':
        return isArabic ? 'صافي 45 يوم' : 'Net 45';
      case 'NET_60':
        return isArabic ? 'صافي 60 يوم' : 'Net 60';
      case 'ADVANCE':
        return isArabic ? 'دفعة مقدمة' : 'Advance Payment';
      case 'LETTER_OF_CREDIT':
        return isArabic ? 'خطاب اعتماد' : 'Letter of Credit';
      default:
        return code ?? '';
    }
  }

  static String _getDeliveryTermText(String? code, bool isArabic) {
    switch (code) {
      case 'EXW':
        return isArabic ? 'تسليم من المصنع' : 'Ex Works';
      case 'FOB':
        return isArabic ? 'تسليم ظهر السفينة' : 'Free On Board';
      case 'CIF':
        return isArabic ? 'تسليم شامل التكاليف' : 'CIF';
      case 'DDP':
        return isArabic ? 'تسليم شامل الرسوم' : 'DDP';
      case 'FCA':
        return isArabic ? 'تسليم إلى الناقل' : 'Free Carrier';
      default:
        return code ?? '';
    }
  }

  // ==================== التفقيط ====================
  static pw.Widget _buildAmountInWordsRow(
      double total, String currency, bool isArabic, pw.Font arabicFont) {
    final totalWords = isArabic
        ? _convertNumberToArabicWords(total, currency)
        : _convertNumberToEnglishWords(total, currency);

    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        color: PdfColors.grey50,
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        totalWords,
        style: pw.TextStyle(
          fontSize: _mediumFontSize,
          font: arabicFont,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static String _convertNumberToArabicWords(double number, String currency) {
    int integerPart = number.toInt();
    int fractionalPart = ((number - integerPart) * 100).round();

    String currencyName;
    String fractionalName;

    if (currency == 'EGP') {
      currencyName = 'جنيهاً مصرياً';
      fractionalName = 'قرشاً';
    } else if (currency == 'USD') {
      currencyName = 'دولار أمريكي';
      fractionalName = 'سنتاً';
    } else if (currency == 'EUR') {
      currencyName = 'يورو';
      fractionalName = 'سنتاً';
    } else {
      currencyName = currency;
      fractionalName = 'جزءاً';
    }

    String result = Tafqeet.convert(integerPart.toString());
    result += ' $currencyName';

    if (fractionalPart > 0) {
      result +=
          ' و ${Tafqeet.convert(fractionalPart.toString())} $fractionalName';
    }

    result += ' فقط لا غير';
    return result;
  }

  static String _convertNumberToEnglishWords(double number, String currency) {
    int integerPart = number.toInt();
    int fractionalPart = ((number - integerPart) * 100).round();

    String currencyName;
    String fractionalName;

    if (currency == 'EGP') {
      currencyName = 'Egyptian Pounds';
      fractionalName = 'piasters';
    } else if (currency == 'USD') {
      currencyName = 'US Dollars';
      fractionalName = 'cents';
    } else if (currency == 'EUR') {
      currencyName = 'Euros';
      fractionalName = 'cents';
    } else {
      currencyName = currency;
      fractionalName = 'hundredths';
    }

    String result = NumberToWordsEnglish.convert(integerPart);
    result += ' $currencyName';

    if (fractionalPart > 0) {
      result +=
          ' and ${NumberToWordsEnglish.convert(fractionalPart)} $fractionalName';
    }

    result += ' only';
    return result;
  }

  // ==================== بقية الدوال ====================
  static pw.Widget _buildHeader(
      Map<String, dynamic> orderData,
      Map<String, dynamic> companyData,
      pw.Widget qrImage,
      Uint8List? logoBytes,
      bool isArabic,
      pw.Font arabicFont) {
    final poNumber = orderData['poNumber']?.toString().isNotEmpty == true
        ? orderData['poNumber'].toString()
        : '';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoBytes != null)
          pw.Image(pw.MemoryImage(logoBytes), width: 200, height: 200),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(isArabic ? companyData['nameAr'] : companyData['nameEn'],
                style: pw.TextStyle(
                    fontSize: _headerFontSize + 2,
                    fontWeight: pw.FontWeight.bold,
                    font: arabicFont)),
            pw.Text('${'invoice'.tr()} $poNumber',
                style: pw.TextStyle(
                    fontSize: _bodyFontSize + 2, font: arabicFont)),
            pw.Text(
                '${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
                style: pw.TextStyle(
                    fontSize: _smallFontSize + 1, font: arabicFont)),
          ],
        ),
        qrImage,
      ],
    );
  }

  static pw.Widget _buildSupplierSection(
      Map<String, dynamic> supplierData, bool isArabic, pw.Font arabicFont) {
    return pw.Row(
      children: [
        pw.Text('${'supplier'.tr()}: ',
            style:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, font: arabicFont)),
        pw.Text(isArabic ? supplierData['nameAr'] : supplierData['nameEn'],
            style: pw.TextStyle(font: arabicFont)),
      ],
    );
  }

  static pw.Widget _buildTaxExemptNote(
      Map<String, dynamic> orderData, bool isArabic, pw.Font arabicFont) {
    final items = orderData['items'] ?? [];
    final hasTaxExemptItems =
        items.any((item) => (item['isTaxable'] ?? true) == false);

    if (!hasTaxExemptItems) return pw.SizedBox();

    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Text(
        isArabic
            ? '* الأصناف التي تحمل علامة * غير خاضعة للضريبة'
            : '* Items marked with * are tax exempt',
        style: pw.TextStyle(
            fontSize: 8,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey600,
            font: arabicFont),
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildFooter(Map<String, dynamic> companyData, bool isArabic,
      pw.Font arabicFont, String userName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 2),
        pw.Text(userName,
            style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)),
        pw.Text(companyData['address'] ?? '',
            style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)),
        pw.Text('${'phone'.tr()}: ${companyData['managerPhone'] ?? ''}',
            style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)),
      ],
    );
  }

  static pw.Padding _buildHeaderCell(
      String text, pw.Font arabicFont, bool isArabic) {
    return pw.Padding(
      padding: _cellPadding,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, font: arabicFont)),
    );
  }

  static pw.Widget _buildCell(String text, pw.Font font, bool isArabic,
      {pw.TextAlign align = pw.TextAlign.left,
      bool isBold = false,
      double fontSize = _mediumFontSize}) {
    return pw.Padding(
      padding: _cellPadding,
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              font: font),
          textAlign: align),
    );
  }

  static String _formatOrderDate(dynamic orderDate) {
    if (orderDate is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(orderDate.toDate());
    }
    return orderDate?.toString() ?? '';
  }

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final numValue =
        value is num ? value : double.tryParse(value.toString()) ?? 0;
    return NumberFormat("#,##0.00", "en_US").format(numValue);
  }

  static Uint8List? _decodeBase64Logo(String? base64Logo) {
    if (base64Logo == null || base64Logo.isEmpty) return null;
    try {
      return base64.decode(base64Logo.split(',').last);
    } catch (e) {
      return null;
    }
  }

  static Future<pw.Font> _getArabicFont() async {
    _cachedArabicFont ??= await _loadArabicFont();
    return _cachedArabicFont!;
  }

  static Future<pw.Font> _getLatinFont() async {
    _cachedLatinFont ??= await _loadLatinFont();
    return _cachedLatinFont!;
  }

  static Future<pw.Font> _loadArabicFont() async {
    try {
      final ByteData fontData = kIsWeb
          ? ByteData.view(
              (await http.get(Uri.parse('assets/fonts/Tajawal-Regular.ttf')))
                  .bodyBytes
                  .buffer)
          : await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      return pw.Font.courier();
    }
  }

  static Future<pw.Font> _loadLatinFont() async {
    try {
      final ByteData fontData = kIsWeb
          ? ByteData.view(
              (await http.get(Uri.parse('assets/fonts/Roboto-Regular.ttf')))
                  .bodyBytes
                  .buffer)
          : await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      return pw.Font.helvetica();
    }
  }
}
