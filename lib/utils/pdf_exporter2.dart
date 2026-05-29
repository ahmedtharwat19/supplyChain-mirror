/* 
import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const double _headerFontSize = 18;
  static const double _bodyFontSize = 14;
  static const double _smallFontSize = 12;
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
  }) async {
    final userName = await _getUserName();
    final pdf = pw.Document();
    final logoBytes = _decodeBase64Logo(base64Logo);
    
    final poNumber = orderData['poNumber']?.toString().isNotEmpty == true
        ? orderData['poNumber'].toString()
        : orderId;
        
    final qrData = _generateQrData(
        poNumber, orderData, supplierData, companyData, itemData, isArabic);
    
    final qrImage = await _generateRealQrImage(qrData, 600);

    final arabicFont = await _getArabicFont();
    final latinFont = await _getLatinFont();
    
    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          fontFallback: [latinFont],
        ),
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 30,
          marginBottom: 30,
          marginLeft: 30,
          marginRight: 30,
        ),
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(orderId, orderData, companyData, qrImage,
                    logoBytes, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildSupplierSection(supplierData, isArabic, arabicFont),
                pw.SizedBox(height: 20),
                _buildOrderItemsTable(orderData, arabicFont, isArabic),
                pw.SizedBox(height: 20),
                _buildOrderSummary(orderData, isArabic, arabicFont),
                pw.Spacer(),
                _buildFooter(companyData, isArabic, arabicFont, userName),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
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

      if (image == null) {
        throw Exception('Failed to generate QR image');
      }
      final qrImage = pw.MemoryImage(image.buffer.asUint8List());

      return pw.Container(
        width: size,
        height: size,
        child: pw.Image(qrImage),
      );
    } catch (e) {
      safeDebugPrint('Error generating QR: $e');
      return _generateQrPlaceholder();
    }
  }

  static pw.Widget _generateQrPlaceholder() {
    return pw.Container(
      width: 100,
      height: 100,
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Center(
        child: pw.Text('QR Code\nPlaceholder', textAlign: pw.TextAlign.center),
      ),
    );
  }

  static String _generateQrData(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    Map<String, dynamic> itemData,
    bool isArabic,
  ) {
    safeDebugPrint('itemData structure: ${itemData.toString()}');
    final poNumber = orderData['poNumber']?.toString().isNotEmpty == true
        ? orderData['poNumber'].toString()
        : orderId;

    final invoiceContent = '''
=== ${isArabic ? 'فاتورة شراء' : 'Purchase Order'} ===
${isArabic ? 'رقم الفاتورة' : 'Invoice No'}: $poNumber
${isArabic ? 'التاريخ' : 'Date'}: ${_formatOrderDate(orderData['orderDate'])}
${isArabic ? 'الشركة' : 'Company'}: ${isArabic ? companyData['nameAr'] : companyData['nameEn']}
${isArabic ? 'المورد' : 'Supplier'}: ${isArabic ? supplierData['nameAr'] : supplierData['nameEn']}

${isArabic ? 'المجموع النهائي' : 'Total'}: ${_formatCurrency(orderData['totalAmountAfterTax'])} ${orderData['currency'] ?? 'EGP'}
    =====xxx===xxx=====

''';
    return invoiceContent;
  }

  static Future<String> generatePdfDownloadUrl(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> supplierData,
    Map<String, dynamic> companyData,
    Map<String, dynamic> itemData,
    String? base64Logo,
    bool isArabic,
  ) async {
    final poNumber = orderData['poNumber']?.toString().isNotEmpty == true
        ? orderData['poNumber'].toString()
        : orderId;
    final pdf = await generatePurchaseOrderPdf(
      orderId: orderId,
      orderData: orderData,
      supplierData: supplierData,
      companyData: companyData,
      itemData: itemData,
      base64Logo: base64Logo,
      isArabic: isArabic,
    );

    final bytes = await pdf.save();
    final ref = FirebaseStorage.instance.ref('purchase_orders/$poNumber.pdf');
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  static Uint8List? _decodeBase64Logo(String? base64Logo) {
    if (base64Logo == null || base64Logo.isEmpty) return null;
    try {
      return base64.decode(base64Logo.split(',').last);
    } catch (e) {
      safeDebugPrint('Error decoding logo: $e');
      return null;
    }
  }

  static pw.Widget _buildHeader(
    String orderId,
    Map<String, dynamic> orderData,
    Map<String, dynamic> companyData,
    pw.Widget qrImage,
    Uint8List? logoBytes,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    final poNumber = orderData['poNumber']?.toString().isNotEmpty == true
        ? orderData['poNumber'].toString()
        : orderId;
    return pw.Column(
      crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoBytes != null)
              pw.Image(pw.MemoryImage(logoBytes), height: 200, width: 200),
            pw.Column(
              crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  isArabic ? companyData['nameAr'] : companyData['nameEn'],
                  style: pw.TextStyle(
                    fontSize: _headerFontSize + 2,
                    fontWeight: pw.FontWeight.bold,
                    font: arabicFont,
                  ),
                ),
                pw.Text(
                  '${'invoice'.tr()} #$poNumber',
                  style: pw.TextStyle(fontSize: _bodyFontSize, font: arabicFont),
                ),
                pw.Text(
                  '${'date'.tr()}: ${_formatOrderDate(orderData['orderDate'])}',
                  style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont),
                ),
              ],
            ),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'purchase_order'.tr(),
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, font: arabicFont),
            ),
            pw.Container(
              width: 150,
              height: 150,
              child: qrImage,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
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
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatter = NumberFormat("#,##0.00", "en_US");
    return formatter.format(numValue);
  }

  static pw.Widget _buildSupplierSection(
    Map<String, dynamic> supplierData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${'supplier'.tr()}: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: arabicFont),
        ),
        pw.Expanded(
          child: pw.Text(
            isArabic ? supplierData['nameAr'] : supplierData['nameEn'],
            style: pw.TextStyle(font: arabicFont),
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildOrderItemsTable(
    Map<String, dynamic> orderData,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    final items = orderData['items'] ?? [];
    final hasTaxExemptItems = items.any((item) => (item['isTaxable'] ?? true) == false);
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Directionality(
          textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          child: pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: isArabic
                ? {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                    4: const pw.FlexColumnWidth(3),
                  }
                : {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                    4: const pw.FlexColumnWidth(2),
                  },
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: isArabic
                    ? [
                        _buildTableHeaderCell('total'.tr(), arabicFont, isArabic),
                        _buildTableHeaderCell('tax'.tr(), arabicFont, isArabic),
                        _buildTableHeaderCell('price'.tr(), arabicFont, isArabic),
                        _buildTableHeaderCell('quantity'.tr(), arabicFont, isArabic),
                        _buildTableHeaderCell('item'.tr(), arabicFont, isArabic),
                      ]
                    : [
                        _buildTableHeaderCell('item'.tr(), arabicFont, isArabic),
                        _buildTableHeaderCell('quantity'.tr(), arabicFont, isArabic),
                        _buildTableHeaderCell('price'.tr(), arabicFont, isArabic),
                        _buildTableHeaderCell('tax'.tr(), arabicFont, isArabic),
                        _buildTableHeaderCell('total'.tr(), arabicFont, isArabic),
                      ],
              ),
              ..._buildOrderItemsRowsWithTax(items, arabicFont, isArabic),
            ],
          ),
        ),
        if (hasTaxExemptItems) ...[
          pw.SizedBox(height: 8),
          pw.Directionality(
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Text(
              isArabic 
                  ? '* الأصناف التي تحمل علامة * غير خاضعة للضريبة'
                  : '* Items marked with * are tax exempt',
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
                font: arabicFont,
              ),
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
            ),
          ),
        ],
      ],
    );
  }

  static List<pw.TableRow> _buildOrderItemsRowsWithTax(
    List<dynamic> items,
    pw.Font arabicFont,
    bool isArabic,
  ) {
    return items.map<pw.TableRow>((item) {
      final itemName = isArabic ? (item['nameAr'] ?? '') : (item['nameEn'] ?? '');
      final isTaxable = item['isTaxable'] ?? true;
      //final taxRate = item['taxRate'] ?? 14.0;
      final displayName = isTaxable ? itemName : '* $itemName';
      final taxText = isTaxable 
          ? _formatCurrency(item['taxAmount'])  //'${_formatCurrency(item['taxAmount'])} ($taxRate%)'
          : (isArabic ? 'معفى' : 'Exempt');
      
      if (isArabic) {
        return pw.TableRow(
          children: [
            _buildItemCell(_formatCurrency(item['totalAfterTaxAmount']), arabicFont, isArabic),
            _buildItemCell(taxText, arabicFont, isArabic),
            _buildItemCell(_formatCurrency(item['unitPrice']), arabicFont, isArabic),
            _buildItemCell(item['quantity']?.toString() ?? '', arabicFont, isArabic),
            _buildItemCell(displayName, arabicFont, isArabic),
          ],
        );
      } else {
        return pw.TableRow(
          children: [
            _buildItemCell(displayName, arabicFont, isArabic),
            _buildItemCell(item['quantity']?.toString() ?? '', arabicFont, isArabic),
            _buildItemCell(_formatCurrency(item['unitPrice']), arabicFont, isArabic),
            _buildItemCell(taxText, arabicFont, isArabic),
            _buildItemCell(_formatCurrency(item['totalAfterTaxAmount']), arabicFont, isArabic),
          ],
        );
      }
    }).toList();
  }

  static pw.Padding _buildTableHeaderCell(String text, pw.Font arabicFont, bool isArabic) {
    return pw.Padding(
      padding: _defaultPadding,
      child: pw.Text(
        text,
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: arabicFont),
      ),
    );
  }

  static pw.Widget _buildItemCell(String text, pw.Font font, bool isArabic) {
    return pw.Padding(
      padding: _defaultPadding,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font),
        textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  // ✅ دالة ملخص الطلب الرئيسية
  static pw.Widget _buildOrderSummary(
    Map<String, dynamic> orderData,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    final subtotal = (orderData['totalAmount'] ?? 0.0).toDouble();
    final tax = (orderData['totalTax'] ?? 0.0).toDouble();
    final totalBeforeWithholding = subtotal + tax;
    final withholdingAmount = (orderData['withholdingTaxAmount'] ?? 0.0).toDouble();
    final netPayable = totalBeforeWithholding - withholdingAmount;
    
    return pw.Container(
      alignment: isArabic ? pw.Alignment.topRight : pw.Alignment.topLeft,
      child: pw.Directionality(
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ✅ جدول الأرقام
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                bottom: pw.BorderSide(width: 1, color: PdfColors.grey600),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
              },
              children: [
                _buildSummaryRowCell('subtotal'.tr(), subtotal, isArabic, arabicFont),
                _buildSummaryRowCell('tax'.tr(), tax, isArabic, arabicFont),
                if (withholdingAmount > 0)
                  _buildSummaryRowCell(
                    isArabic ? 'ضريبة الخصم من المنبع' : 'Withholding Tax (WHT)',
                    withholdingAmount,
                    isArabic,
                    arabicFont,
                    valueColor: PdfColors.orange,
                  ),
                _buildSummaryRowCell('total'.tr(), netPayable, isArabic, arabicFont, isTotal: true),
              ],
            ),
            pw.SizedBox(height: 8),
            // ✅ صف التفقيط - يظهر في صندوق منفصل أسفل الجدول
            _buildAmountInWordsBox(netPayable, isArabic, arabicFont),
          ],
        ),
      ),
    );
  }

  // ✅ دالة لبناء صف واحد في الجدول
  static pw.TableRow _buildSummaryRowCell(
    String label,
    double value,
    bool isArabic,
    pw.Font arabicFont, {
    bool isTotal = false,
    PdfColor? valueColor,
  }) {
    final formattedValue = _formatCurrency(value);
    
    return pw.TableRow(
      decoration: isTotal ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
      children: [
        pw.Padding(
          padding: _defaultPadding,
          child: pw.Text(
            isArabic ? formattedValue : label,
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              font: arabicFont,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
            textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ),
        pw.Padding(
          padding: _defaultPadding,
          child: pw.Text(
            isArabic ? label : formattedValue,
            style: pw.TextStyle(
              fontSize: _bodyFontSize,
              font: arabicFont,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor,
            ),
            textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ),
      ],
    );
  }

  // ✅ دالة عرض التفقيط في صندوق منفصل (يبقى في سطر واحد)
  static pw.Widget _buildAmountInWordsBox(
    double value,
    bool isArabic,
    pw.Font arabicFont,
  ) {
    try {
      final intValue = value.toInt();
      const maxSupportedNumber = 999999999999;
      final safeValue = intValue.abs() > maxSupportedNumber
          ? (intValue.isNegative ? -maxSupportedNumber : maxSupportedNumber)
          : intValue;

      final amountInWords = isArabic
          ? _convertNumberToArabicWords(safeValue)
          : _convertNumberToEnglishWords(safeValue);

      final currencyText = getCurrencyText(safeValue, isArabic);
      
      final fullText = isArabic
          ? '$amountInWords $currencyText فقط لا غير'
          : '$amountInWords $currencyText only';

      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Text(
          fullText,
          style: pw.TextStyle(
            fontSize: _smallFontSize,
            font: arabicFont,
          ),
          textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      );
    } catch (e) {
      safeDebugPrint('Error converting number to words: $e');
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(
          isArabic ? 'تعذر تحويل المبلغ إلى كتابة' : 'Failed to convert amount to words',
          style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont, color: PdfColors.red),
        ),
      );
    }
  }

/*   static String _formatCurrencyWithSymbol(
      dynamic value, String? currencyCode, bool isArabic) {
    final formattedValue = _formatCurrency(value);
    final code = currencyCode?.toUpperCase() ?? 'EGP';
    return code == 'EGP'
        ? (isArabic ? '$formattedValue ج.م' : '$formattedValue EGP')
        : '$formattedValue $code';
  }
 */
  
  
  
  
  static pw.Widget _buildFooter(
    Map<String, dynamic> companyData,
    bool isArabic,
    pw.Font arabicFont,
    String userName,
  ) {
    return pw.Column(
      crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.Text(userName, style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)),
        pw.Text(companyData['address'] ?? '', style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)),
        pw.Text('${'phone'.tr()}: ${companyData['managerPhone'] ?? ''}', style: pw.TextStyle(fontSize: _smallFontSize, font: arabicFont)),
      ],
    );
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
      safeDebugPrint('Error loading Arabic font: $e');
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
      safeDebugPrint('Error loading Latin font: $e');
      return pw.Font.helvetica();
    }
  }

  static String getCurrencyText(int number, bool isArabic) {
    if (!isArabic) return 'Egyptian Pounds';
    int lastTwoDigits = number % 100;
    if (number == 1) return 'جنيه مصري';
    if (number == 2) return 'جنيهان مصريان';
    if (lastTwoDigits >= 3 && lastTwoDigits <= 10) return 'جنيهات مصرية';
    return 'جنيهاً مصرياً';
  }

  static String _convertNumberToArabicWords(int number) {
    if (number == 0) return 'صفر';
    final List<String> units = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
    final List<String> unitsAccusative = ['', 'واحد', 'اثنين', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
    final List<String> teens = ['عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'];
    final List<String> tens = ['', 'عشرة', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
    final List<String> hundreds = ['', 'مائة', 'مئتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'];
    final List<String> singularScales = ['', 'ألف', 'مليون', 'مليار', 'تريليون'];
    final List<String> dualScales = ['', 'ألفان', 'مليونان', 'ملياران', 'تريليونان'];
    final List<String> pluralScales = ['', 'آلاف', 'ملايين', 'مليارات', 'تريليونات'];
    final List<String> accusativeScales = ['', 'ألفًا', 'مليونًا', 'مليارًا', 'تريليونًا'];

    String convertLessThanOneThousand(int n, bool isAccusative) {
      if (n == 0) return '';
      if (n < 10) return isAccusative ? unitsAccusative[n] : units[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) {
        return n % 10 == 0 ? tens[n ~/ 10] : '${isAccusative ? unitsAccusative[n % 10] : units[n % 10]} و${tens[n ~/ 10]}';
      }
      return '${hundreds[n ~/ 100]}${n % 100 != 0 ? ' و${convertLessThanOneThousand(n % 100, isAccusative)}' : ''}';
    }

    if (number < 0) return 'سالب ${_convertNumberToArabicWords(-number)}';
    String result = '';
    int scaleIndex = 0;
    List<String> parts = [];
    int remainingNumber = number;
    while (remainingNumber > 0) {
      int chunk = remainingNumber % 1000;
      if (chunk != 0) {
        bool isLastChunk = (remainingNumber ~/ 1000 == 0);
        String chunkStr = convertLessThanOneThousand(chunk, isLastChunk && scaleIndex == 0);
        String scaleWord = '';
        if (scaleIndex > 0) {
          bool needsAccusative = (chunk >= 11 && chunk <= 99) || (scaleIndex == 1 && (chunk >= 11 || chunk == 0));
          if (chunk == 1) {
            scaleWord = needsAccusative ? accusativeScales[scaleIndex] : singularScales[scaleIndex];
            chunkStr = '';
          } else if (chunk == 2) {
            scaleWord = dualScales[scaleIndex];
            chunkStr = '';
          } else if (chunk >= 3 && chunk <= 10) {
            scaleWord = pluralScales[scaleIndex];
          } else {
            scaleWord = needsAccusative ? accusativeScales[scaleIndex] : singularScales[scaleIndex];
          }
          chunkStr = chunkStr.isEmpty ? scaleWord : '$chunkStr $scaleWord';
        }
        parts.insert(0, chunkStr.trim());
      }
      remainingNumber ~/= 1000;
      scaleIndex++;
      if (scaleIndex >= singularScales.length) break;
    }
    result = parts.join(' و');
    return result;
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
      if (n < 100) {
        return n % 10 == 0 ? tens[n ~/ 10] : '${tens[n ~/ 10]}-${units[n % 10]}';
      }
      return '${units[n ~/ 100]} hundred${n % 100 != 0 ? ' and ${convertLessThanOneThousand(n % 100)}' : ''}';
    }

    if (number < 0) return 'negative ${_convertNumberToEnglishWords(-number)}';
    String result = '';
    int scaleIndex = 0;
    while (number > 0) {
      int chunk = number % 1000;
      if (chunk != 0) {
        String chunkStr = convertLessThanOneThousand(chunk);
        if (scaleIndex > 0) chunkStr += ' ${scales[scaleIndex]}';
        result = '$chunkStr $result'.trim();
      }
      number ~/= 1000;
      scaleIndex++;
      if (scaleIndex >= scales.length) break;
    }
    return result.isEmpty ? 'zero' : result.trim();
  }
} */