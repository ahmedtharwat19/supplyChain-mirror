/* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

class PdfExporter {
  static const double _headerFontSize = 16;
  static const double _bodyFontSize = 10;
  static const double _smallFontSize = 8;
  static const pw.EdgeInsets _cellPadding = pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3);
  static const pw.EdgeInsets _defaultPadding = pw.EdgeInsets.all(8);

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

    final qrData = _generateDetailedQrData(poNumber, orderData, supplierData, companyData, isArabic);
    final qrImage = await _generateRealQrImage(qrData, 200);

    final arabicFont = await _getArabicFont();
    final latinFont = await _getLatinFont();

    final additionalItemsWidget = _buildAdditionalItemsSection(additionalItems, isArabic, arabicFont);

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: arabicFont, fontFallback: [latinFont]),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(orderData, companyData, qrImage, logoBytes, isArabic, arabicFont),
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

  // ==================== QR Code ====================
  static String _generateDetailedQrData(
    String poNumber,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    bool isArabic,
  ) {
    final qrContent = {
      'po': poNumber,
      'date': _formatOrderDate(orderData['orderDate']),
      'company': isArabic ? companyData['nameAr'] : companyData['nameEn'],
      'supplier': isArabic ? supplierData['nameAr'] : supplierData['nameEn'],
      'total': orderData['totalAmountAfterTax'],
      'currency': orderData['currency'] ?? 'EGP',
      'items_count': (orderData['items'] as List?)?.length ?? 0,
    };
    return jsonEncode(qrContent);
  }

  static Future<pw.Widget> _generateRealQrImage(String data, double size) async {
    try {
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        gapless: false,
      );
      final image = await qrPainter.toImageData(size);
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
        decoration: pw.BoxDecoration(border: pw.Border.all()),
        child: pw.Center(child: pw.Text('QR', style: const pw.TextStyle(fontSize: 10))),
      );
    }
  }

  // ==================== جدول الأصناف (5 أعمدة) ====================
  static pw.Widget _buildOrderItemsTable(Map<String, dynamic> orderData, pw.Font arabicFont, bool isArabic) {
    final items = orderData['items'] ?? [];
    
    // عرض الأعمدة حسب اللغة
    final columnWidths = {
      0: const pw.FlexColumnWidth(3),  // الصنف/Item
      1: const pw.FlexColumnWidth(1),  // الكمية/Qty
      2: const pw.FlexColumnWidth(1),  // السعر/Price
      3: const pw.FlexColumnWidth(1),  // الضريبة/Tax
      4: const pw.FlexColumnWidth(2),  // الإجمالي/Total
    };

    // ترتيب الرؤوس حسب اللغة
    final headers = isArabic
        ? ['الصنف', 'الكمية', 'السعر', 'الضريبة', 'الإجمالي']
        : ['Item', 'Qty', 'Price', 'Tax', 'Total'];

    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: columnWidths,
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: headers.map((header) => _buildHeaderCell(header, arabicFont, isArabic)).toList(),
          ),
          ...items.map((item) {
            final itemName = isArabic ? (item['nameAr'] ?? '') : (item['nameEn'] ?? '');
            final isTaxable = item['isTaxable'] ?? true;
            final displayName = isTaxable ? itemName : '* $itemName';
            final taxText = isTaxable ? _formatCurrency(item['taxAmount']) : (isArabic ? 'معفى' : 'Exempt');
            
            // ترتيب الخلايا حسب اللغة
            final cells = isArabic
                ? [
                    _buildCell(displayName, arabicFont, isArabic, align: pw.TextAlign.right),
                    _buildCell(item['quantity']?.toString() ?? '', arabicFont, isArabic, align: pw.TextAlign.center),
                    _buildCell(_formatCurrency(item['unitPrice']), arabicFont, isArabic, align: pw.TextAlign.right),
                    _buildCell(taxText, arabicFont, isArabic, align: pw.TextAlign.right),
                    _buildCell(_formatCurrency(item['totalAfterTaxAmount']), arabicFont, isArabic, align: pw.TextAlign.right),
                  ]
                : [
                    _buildCell(displayName, arabicFont, isArabic, align: pw.TextAlign.left),
                    _buildCell(item['quantity']?.toString() ?? '', arabicFont, isArabic, align: pw.TextAlign.center),
                    _buildCell(_formatCurrency(item['unitPrice']), arabicFont, isArabic, align: pw.TextAlign.right),
                    _buildCell(taxText, arabicFont, isArabic, align: pw.TextAlign.right),
                    _buildCell(_formatCurrency(item['totalAfterTaxAmount']), arabicFont, isArabic, align: pw.TextAlign.right),
                  ];
            
            return pw.TableRow(children: cells);
          }),
        ],
      ),
    );
  }

  // ==================== جدول الملخص (عمودين مع RTL/LTR) ====================
  static pw.Widget _buildOrderSummary(Map<String, dynamic> orderData, pw.Font arabicFont, bool isArabic) {
    final subtotal = (orderData['totalAmount'] ?? 0.0).toDouble();
    final tax = (orderData['totalTax'] ?? 0.0).toDouble();
    final withholdingAmount = (orderData['withholdingTaxAmount'] ?? 0.0).toDouble();
    final total = subtotal + tax - withholdingAmount;

    // عرض الأعمدة حسب اللغة (معكوسة في العربي)
    final columnWidths = isArabic
        ? {
            0: const pw.FlexColumnWidth(1),  // القيمة (على اليمين في العربي)
            1: const pw.FlexColumnWidth(2),  // التسمية (على اليسار في العربي)
          }
        : {
            0: const pw.FlexColumnWidth(2),  // التسمية (على اليمين في الإنجليزي)
            1: const pw.FlexColumnWidth(1),  // القيمة (على اليسار في الإنجليزي)
          };

    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Column(
        children: [
          // جدول الأرقام
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: columnWidths,
            children: [
              // صف الإجمالي الفرعي
              _buildSummaryRow(
                label: isArabic ? 'الإجمالي الفرعي' : 'Subtotal',
                value: _formatCurrency(subtotal),
                isArabic: isArabic,
                arabicFont: arabicFont,
              ),
              // صف الضريبة
              _buildSummaryRow(
                label: isArabic ? 'الضريبة' : 'Tax',
                value: _formatCurrency(tax),
                isArabic: isArabic,
                arabicFont: arabicFont,
              ),
              // صف ضريبة الخصم (إذا موجود)
              if (withholdingAmount > 0)
                _buildSummaryRow(
                  label: isArabic ? 'ضريبة الخصم من المنبع' : 'Withholding Tax',
                  value: '-${_formatCurrency(withholdingAmount)}',
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                ),
              // صف الإجمالي (بخط عريض)
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
          // صف المبلغ كتابة (كامل العرض بدون كلمة المبلغ كتابة)
          _buildAmountInWordsRow(total, isArabic, arabicFont),
        ],
      ),
    );
  }

  // دالة مساعدة لبناء صف في جدول الملخص
  static pw.TableRow _buildSummaryRow({
    required String label,
    required String value,
    required bool isArabic,
    required pw.Font arabicFont,
    bool isTotal = false,
  }) {
    return pw.TableRow(
      decoration: isTotal ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
      children: isArabic
          ? [
              // في العربي: القيمة على اليمين، التسمية على اليسار
              _buildCell(value, arabicFont, isArabic, align: pw.TextAlign.right, isBold: isTotal),
              _buildCell(label, arabicFont, isArabic, align: pw.TextAlign.right, isBold: isTotal),
            ]
          : [
              // في الإنجليزي: التسمية على اليمين، القيمة على اليسار
              _buildCell(label, arabicFont, isArabic, align: pw.TextAlign.left, isBold: isTotal),
              _buildCell(value, arabicFont, isArabic, align: pw.TextAlign.right, isBold: isTotal),
            ],
    );
  }

  // صف المبلغ كتابة (كامل العرض)
  static pw.Widget _buildAmountInWordsRow(double total, bool isArabic, pw.Font arabicFont) {
    final totalWords = isArabic 
        ? _convertNumberToArabicWords(total.toInt()) 
        : _convertNumberToEnglishWords(total.toInt());
    final currencyText = isArabic ? 'جنيهاً مصرياً' : 'Egyptian Pounds';
    final fullText = '$totalWords $currencyText ${isArabic ? 'فقط لا غير' : 'only'}';

    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        color: PdfColors.grey50,
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        fullText,
        style: pw.TextStyle(
          fontSize: _smallFontSize,
          font: arabicFont,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: isArabic ? pw.TextAlign.center : pw.TextAlign.center,
      ),
    );
  }

  // ==================== جدول الشروط (عمودين مع RTL/LTR) ====================
  static pw.Widget _buildTermsTable(Map<String, dynamic> orderData, pw.Font arabicFont, bool isArabic) {
    final paymentTermCode = orderData['paymentTermCode'];
    final deliveryTermCode = orderData['deliveryTermCode'];
    
    if ((paymentTermCode == null || paymentTermCode.toString().isEmpty) &&
        (deliveryTermCode == null || deliveryTermCode.toString().isEmpty)) {
      return pw.SizedBox();
    }
    
    final paymentTerms = {
      'CASH': isArabic ? 'دفع نقدي' : 'Cash',
      'NET_30': isArabic ? 'صافي 30 يوم' : 'Net 30',
      'NET_45': isArabic ? 'صافي 45 يوم' : 'Net 45',
      'NET_60': isArabic ? 'صافي 60 يوم' : 'Net 60',
      'ADVANCE': isArabic ? 'دفعة مقدمة' : 'Advance Payment',
      'LETTER_OF_CREDIT': isArabic ? 'خطاب اعتماد' : 'Letter of Credit',
    };
    
    final deliveryTerms = {
      'EXW': isArabic ? 'تسليم من المصنع' : 'Ex Works',
      'FOB': isArabic ? 'تسليم ظهر السفينة' : 'Free On Board',
      'CIF': isArabic ? 'تسليم شامل التكاليف' : 'CIF',
      'DDP': isArabic ? 'تسليم شامل الرسوم' : 'DDP',
      'FCA': isArabic ? 'تسليم إلى الناقل' : 'Free Carrier',
    };

    // عرض الأعمدة حسب اللغة (معكوسة في العربي)
    final columnWidths = isArabic
        ? {
            0: const pw.FlexColumnWidth(1),  // القيمة (على اليمين)
            1: const pw.FlexColumnWidth(2),  // التسمية (على اليسار)
          }
        : {
            0: const pw.FlexColumnWidth(2),  // التسمية (على اليمين)
            1: const pw.FlexColumnWidth(1),  // القيمة (على اليسار)
          };

    final List<Map<String, String>> rows = [];
    if (paymentTermCode != null && paymentTermCode.toString().isNotEmpty) {
      rows.add({
        'label': isArabic ? 'شروط الدفع' : 'Payment Terms',
        'value': paymentTerms[paymentTermCode] ?? paymentTermCode,
      });
    }
    if (deliveryTermCode != null && deliveryTermCode.toString().isNotEmpty) {
      rows.add({
        'label': isArabic ? 'شروط التسليم' : 'Delivery Terms',
        'value': deliveryTerms[deliveryTermCode] ?? deliveryTermCode,
      });
    }

    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(),
        columnWidths: columnWidths,
        children: rows.map((row) {
          return pw.TableRow(
            children: isArabic
                ? [
                    // في العربي: القيمة على اليمين، التسمية على اليسار
                    _buildCell(row['value']!, arabicFont, isArabic),
                    _buildCell(row['label']!, arabicFont, isArabic),
                  ]
                : [
                    // في الإنجليزي: التسمية على اليمين، القيمة على اليسار
                    _buildCell(row['label']!, arabicFont, isArabic),
                    _buildCell(row['value']!, arabicFont, isArabic),
                  ],
          );
        }).toList(),
      ),
    );
  }

  // ==================== بقية الدوال ====================
  
  static pw.Widget _buildAdditionalItemsSection(
    Map<String, List<Map<String, dynamic>>>? additionalItems,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    if (additionalItems == null) return pw.SizedBox();
    
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
          pw.Text(isArabic ? 'الشروط الإضافية' : 'Additional Conditions',
              style: pw.TextStyle(fontSize: _bodyFontSize, fontWeight: pw.FontWeight.bold, font: arabicFont)),
          pw.SizedBox(height: 2),
          ...conditions.map((c) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6, bottom: 1),
              child: pw.Text('• ${isArabic ? c['titleAr'] : c['titleEn']}', 
                  style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)))),
          pw.SizedBox(height: 4),
        ],
        if (documents.isNotEmpty) ...[
          pw.Text(isArabic ? 'المستندات المطلوبة' : 'Required Documents',
              style: pw.TextStyle(fontSize: _bodyFontSize, fontWeight: pw.FontWeight.bold, font: arabicFont)),
          pw.SizedBox(height: 2),
          ...documents.map((d) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6, bottom: 1),
              child: pw.Text('• ${isArabic ? d['titleAr'] : d['titleEn']}', 
                  style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)))),
          pw.SizedBox(height: 4),
        ],
        if (notes.isNotEmpty) ...[
          pw.Text(isArabic ? 'ملاحظات' : 'Notes',
              style: pw.TextStyle(fontSize: _bodyFontSize, fontWeight: pw.FontWeight.bold, font: arabicFont)),
          pw.SizedBox(height: 2),
          ...notes.map((n) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6, bottom: 1),
              child: pw.Text('• ${isArabic ? n['titleAr'] : n['titleEn']}', 
                  style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)))),
          pw.SizedBox(height: 4),
        ],
      ],
    );
  }

  static pw.Widget _buildHeader(Map<String, dynamic> orderData, Map<String, dynamic> companyData,
      pw.Widget qrImage, Uint8List? logoBytes, bool isArabic, pw.Font arabicFont) {
    final poNumber = orderData['poNumber']?.toString().isNotEmpty == true 
        ? orderData['poNumber'].toString() 
        : '';
    
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoBytes != null) 
          pw.Image(pw.MemoryImage(logoBytes), width: 70, height: 70),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(isArabic ? companyData['nameAr'] : companyData['nameEn'],
                style: pw.TextStyle(fontSize: _headerFontSize + 2, fontWeight: pw.FontWeight.bold, font: arabicFont)),
            pw.Text('${'invoice'.tr()} $poNumber',
                style: pw.TextStyle(fontSize: _bodyFontSize + 2, font: arabicFont)),
            pw.Text('${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
                style: pw.TextStyle(fontSize: _smallFontSize + 1, font: arabicFont)),
          ],
        ),
        qrImage,
      ],
    );
  }

  static pw.Widget _buildSupplierSection(Map<String, dynamic> supplierData, bool isArabic, pw.Font arabicFont) {
    return pw.Row(
      children: [
        pw.Text('${'supplier'.tr()}: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: arabicFont)),
        pw.Text(isArabic ? supplierData['nameAr'] : supplierData['nameEn'], 
            style: pw.TextStyle(font: arabicFont)),
      ],
    );
  }

  static pw.Widget _buildTaxExemptNote(Map<String, dynamic> orderData, bool isArabic, pw.Font arabicFont) {
    final items = orderData['items'] ?? [];
    final hasTaxExemptItems = items.any((item) => (item['isTaxable'] ?? true) == false);
    
    if (!hasTaxExemptItems) return pw.SizedBox();
    
    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Text(
        isArabic ? '* الأصناف التي تحمل علامة * غير خاضعة للضريبة' : '* Items marked with * are tax exempt',
        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600, font: arabicFont),
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildFooter(Map<String, dynamic> companyData, bool isArabic, pw.Font arabicFont, String userName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 2),
        pw.Text(userName, style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)),
        pw.Text(companyData['address'] ?? '', style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)),
        pw.Text('${'phone'.tr()}: ${companyData['managerPhone'] ?? ''}', 
            style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)),
      ],
    );
  }

  static pw.Padding _buildHeaderCell(String text, pw.Font arabicFont, bool isArabic) {
    return pw.Padding(
      padding: _cellPadding,
      child: pw.Text(text, 
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: arabicFont)),
    );
  }

  static pw.Widget _buildCell(String text, pw.Font font, bool isArabic,
      {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Padding(
      padding: _cellPadding,
      child: pw.Text(text, 
          style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, font: font),
          textAlign: align),
    );
  }

  static String _formatOrderDate(dynamic orderDate) {
    if (orderDate is Timestamp) return DateFormat('yyyy-MM-dd').format(orderDate.toDate());
    return orderDate?.toString() ?? '';
  }

  static String _formatCurrency(dynamic value) {
    if (value == null) return '0.00';
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0;
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
          ? ByteData.view((await http.get(Uri.parse('assets/fonts/Tajawal-Regular.ttf'))).bodyBytes.buffer)
          : await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      return pw.Font.courier();
    }
  }

  static Future<pw.Font> _loadLatinFont() async {
    try {
      final ByteData fontData = kIsWeb
          ? ByteData.view((await http.get(Uri.parse('assets/fonts/Roboto-Regular.ttf'))).bodyBytes.buffer)
          : await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      return pw.Font.helvetica();
    }
  }

  static String _convertNumberToArabicWords(int number) {
    if (number == 0) return 'صفر';
    final List<String> units = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
    final List<String> teens = ['عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'];
    final List<String> tens = ['', 'عشرة', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
    final List<String> hundreds = ['', 'مائة', 'مئتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'];
    final List<String> scales = ['', 'ألف', 'مليون', 'مليار', 'تريليون'];

    String convertLessThanOneThousand(int n) {
      if (n == 0) return '';
      if (n < 10) return units[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) return n % 10 == 0 ? tens[n ~/ 10] : '${tens[n ~/ 10]} و${units[n % 10]}';
      return '${hundreds[n ~/ 100]}${n % 100 != 0 ? ' و${convertLessThanOneThousand(n % 100)}' : ''}';
    }

    if (number < 0) return 'سالب ${_convertNumberToArabicWords(-number)}';
    String result = '';
    int scaleIndex = 0;
    int remainingNumber = number;
    while (remainingNumber > 0) {
      int chunk = remainingNumber % 1000;
      if (chunk != 0) {
        String chunkStr = convertLessThanOneThousand(chunk);
        if (scaleIndex > 0) chunkStr += ' ${scales[scaleIndex]}';
        result = '$chunkStr $result'.trim();
      }
      remainingNumber ~/= 1000;
      scaleIndex++;
    }
    return result.trim();
  }

  static String _convertNumberToEnglishWords(int number) {
    if (number == 0) return 'zero';
    final List<String> units = ['', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'];
    final List<String> teens = ['ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
    final List<String> tens = ['', 'ten', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
    final List<String> scales = ['', 'thousand', 'million', 'billion', 'trillion'];

    String convertLessThanOneThousand(int n) {
      if (n == 0) return '';
      if (n < 10) return units[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) return n % 10 == 0 ? tens[n ~/ 10] : '${tens[n ~/ 10]}-${units[n % 10]}';
      return '${units[n ~/ 100]} hundred${n % 100 != 0 ? ' and ${convertLessThanOneThousand(n % 100)}' : ''}';
    }

    if (number < 0) return 'negative ${_convertNumberToEnglishWords(-number)}';
    String result = '';
    int scaleIndex = 0;
    int remainingNumber = number;
    while (remainingNumber > 0) {
      int chunk = remainingNumber % 1000;
      if (chunk != 0) {
        String chunkStr = convertLessThanOneThousand(chunk);
        if (scaleIndex > 0) chunkStr += ' ${scales[scaleIndex]}';
        result = '$chunkStr $result'.trim();
      }
      remainingNumber ~/= 1000;
      scaleIndex++;
    }
    return result.trim();
  }
} */