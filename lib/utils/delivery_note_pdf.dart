// delivery_note_pdf.dart
import 'dart:io';
import 'dart:convert'; // ✅ لإستخدام base64.decode
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;

class DeliveryNotePdf {
  static pw.Font? _cachedArabicFont;
  static pw.Font? _cachedLatinFont;
  static pw.Font? _cachedSymbolFont;

  static Future<pw.Font> _getArabicFont() async {
    _cachedArabicFont ??= await _loadFont('assets/fonts/Cairo-Regular.ttf');
    return _cachedArabicFont!;
  }

  static Future<pw.Font> _getLatinFont() async {
    _cachedLatinFont ??= await _loadFont('assets/fonts/Roboto-Regular.ttf');
    return _cachedLatinFont!;
  }

  static Future<pw.Font> _getSymbolFont() async {
    _cachedSymbolFont ??= await _loadFont('assets/fonts/NotoSans-Regular.ttf');
    return _cachedSymbolFont!;
  }

  static Future<pw.Font> _loadFont(String path) async {
    try {
      ByteData fontData;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        fontData = ByteData.view(response.bodyBytes.buffer);
      } else {
        fontData = await rootBundle.load(path);
      }
      return pw.Font.ttf(fontData);
    } catch (e) {
      return pw.Font.helvetica();
    }
  }

  static Future<Uint8List> generateDeliveryNotePdf({
    required Map<String, dynamic> order,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> receiverData,
    required Map<String, dynamic> deliveryMeta,
    String? base64Logo,
    bool isArabic = true,
    required Map<String, String> translations,
  }) async {
    final arabicFont = await _getArabicFont();
    final latinFont = await _getLatinFont();
    final symbolFont = await _getSymbolFont();

    final pdf = pw.Document();
    final logoBytes = _decodeBase64Logo(base64Logo);

    // استخراج البيانات
    final companyName = isArabic
        ? (companyData['nameAr'] ?? 'شركة غير محددة')
        : (companyData['nameEn'] ?? 'Unknown Company');
    final companyNameEn = companyData['nameEn'] ?? 'UNKNOWN';
    final receiverName = isArabic
        ? (receiverData['nameAr'] ?? 'مصنع غير محدد')
        : (receiverData['nameEn'] ?? 'Unknown factory');
    final receiverNameEn = receiverData['nameEn'] ?? 'UNKNOWN';

    final items = order['items'] as List? ?? [];
    final poNumber = order['poNumber'] ?? 'N/A';
    final purpose = order['purpose'] ??
        translations['purposeDefault'] ??
        'توريد خامات ومواد تعبئة للتصنيع';
    final deliveryDate = deliveryMeta['deliveryDate'] ??
        DateFormat('dd-MM-yyyy').format(DateTime.now());
    final deliveryNumber = deliveryMeta['deliveryNumber'] ??
        'DN-${DateFormat('yyyyMMdd').format(DateTime.now())}-01';
    final notes = deliveryMeta['notes'] ?? '';

    // نصوص مترجمة - إزالة المتغيرات غير المستخدمة
    final title = translations['deliveryNoteTitle'] ?? 'إذن تسليم بضاعة';
    final deliveryNumberLabel =
        translations['deliveryNumberLabel'] ?? 'رقم إذن التسليم';
    final dateLabel = translations['dateLabel'] ?? 'التاريخ';
    final poLabel = translations['poLabel'] ?? 'رقم أمر الشراء (PO)';
    final methodLabel = translations['methodLabel'] ?? 'طريقة التسليم';
    final methodValue =
        translations['methodValue'] ?? 'تسليم أرض المصنع (Ex Works)';
    final purposeLabel = translations['purposeLabel'] ?? 'الغرض';
    final senderLabel = translations['senderLabel'] ?? 'الجهة المرسلة';
    final receiverLabel = translations['receiverLabel'] ?? 'الجهة المستلمة';
    final serialLabel = translations['serialLabel'] ?? 'م';
    final itemNameLabel = translations['itemNameLabel'] ?? 'الصنف';
    final unitLabel = translations['unitLabel'] ?? 'الوحدة';
    final qtyLabel = translations['qtyLabel'] ?? 'الكمية';
    final notesLabel = translations['notesLabel'] ?? 'ملاحظات';
    final totalItemsLabel = translations['totalItemsLabel'] ?? 'عدد الأصناف';
    final totalQtyLabel = translations['totalQtyLabel'] ?? 'إجمالي الكميات';
    final unitSuffix = translations['unitSuffix'] ?? 'وحدة';
    final notesSectionTitle = translations['notesSectionTitle'] ?? 'ملاحظات';
    final note1 = translations['note1'] ??
        'تم تسليم الأصناف طبقًا لأمر الشراء المشار إليه أعلاه.';
    final note2 = translations['note2'] ??
        'جميع الأصناف سليمة وخالية من التلف وقت التسليم.';
    final note3 = translations['note3'] ??
        'يلتزم المستلم بفحص الكميات والأصناف عند الاستلام وإبداء أي ملاحظات فورًا.';
    final acknowledgmentTitle =
        translations['acknowledgmentTitle'] ?? 'إقرار الاستلام';
    final acknowledgmentText = translations['acknowledgmentText']
            ?.replaceAll('{0}', receiverName) ??
        'أقر أنا الموقع أدناه، ممثل $receiverName  بأنني استلمت الأصناف الموضحة بهذا الإذن كاملة، وبحالة جيدة، ومطابقة للمواصفات والكميات الموضحة أعلاه، دون أي تحفظات إلا ما يتم تدوينه في خانة الملاحظات.';
    final storekeeper = translations['storekeeper'] ?? 'أمين المخزن';
    final nameLabelTr = translations['nameLabel'] ?? 'الاسم';
    final signatureLabel = translations['signatureLabel'] ?? 'التوقيع';
    final dateLabel2 = translations['dateLabel2'] ?? 'التاريخ';
    final delegate = translations['delegate'] ?? 'المندوب / السائق';
    final vehicleLabel = translations['vehicleLabel'] ?? 'رقم السيارة';
    final receiverOfficial =
        translations['receiverOfficial'] ?? 'مسؤول الاستلام';
    final stampLabel = translations['stampLabel'] ?? 'الختم الرسمي';
    final footerText =
        translations['footerText']?.replaceAll('{0}', deliveryNumber) ??
            'تم الإنشاء بواسطة نظام أوميكرون · $deliveryNumber';

    // حساب الإجماليات
    int totalItems = items.length;
    double totalQty = 0;
    for (var item in items) {
      totalQty += (item['quantity'] as num?)?.toDouble() ?? 0;
    }

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          fontFallback: [latinFont, symbolFont],
        ),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection:
                isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // رأس الصفحة
                _buildHeader(
                  title: title,
                  companyName: companyName,
                  companyNameEn: companyNameEn,
                  logoBytes: logoBytes,
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                ),
                pw.SizedBox(height: 8),

                // بيانات الإذن
                _buildInfoGrid(
                  data: [
                    [deliveryNumberLabel, deliveryNumber],
                    [dateLabel, deliveryDate],
                    [poLabel, poNumber],
                    [methodLabel, methodValue],
                    [purposeLabel, purpose],
                  ],
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                ),
                pw.SizedBox(height: 8),

                // الأطراف
                _buildParties(
                  sender: companyName,
                  senderEn: companyNameEn,
                  receiver: receiverName,
                  receiverEn: receiverNameEn,
                  senderLabel: senderLabel,
                  receiverLabel: receiverLabel,
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                ),
                pw.SizedBox(height: 8),

                // جدول الأصناف
                _buildItemsTable(
                  items: items,
                  serialLabel: serialLabel,
                  itemNameLabel: itemNameLabel,
                  unitLabel: unitLabel,
                  qtyLabel: qtyLabel,
                  notesLabel: notesLabel,
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                ),
                pw.SizedBox(height: 8),

                // الملخص
                _buildSummary(
                  totalItems: totalItems,
                  totalQty: totalQty,
                  unitSuffix: unitSuffix,
                  totalItemsLabel: totalItemsLabel,
                  totalQtyLabel: totalQtyLabel,
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                ),
                pw.SizedBox(height: 8),

                // الملاحظات
                _buildNotes(
                  notes: notes,
                  note1: note1,
                  note2: note2,
                  note3: note3,
                  notesSectionTitle: notesSectionTitle,
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                  symbolFont: symbolFont,
                ),
                pw.SizedBox(height: 8),

                // إقرار الاستلام
                _buildAcknowledgment(
                  title: acknowledgmentTitle,
                  text: acknowledgmentText,
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                ),
                pw.SizedBox(height: 8),

                // التوقيعات
                _buildSignatures(
                  storekeeper: storekeeper,
                  delegate: delegate,
                  receiverOfficial: receiverOfficial,
                  nameLabel: nameLabelTr,
                  signatureLabel: signatureLabel,
                  dateLabel: dateLabel2,
                  vehicleLabel: vehicleLabel,
                  stampLabel: stampLabel,
                  deliveryDate: deliveryDate,
                  isArabic: isArabic,
                  arabicFont: arabicFont,
                ),
                pw.SizedBox(height: 8),

                // التذييل
                _buildFooter(
                    footerText: footerText,
                    isArabic: isArabic,
                    arabicFont: arabicFont),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  // ===== دوال بناء العناصر =====

  static pw.Widget _buildHeader({
    required String title,
    required String companyName,
    required String companyNameEn,
    Uint8List? logoBytes,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (logoBytes != null)
          pw.Image(pw.MemoryImage(logoBytes), width: 100, height: 100)
        else
          pw.SizedBox(width: 100),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  font: arabicFont,
                )),
            pw.Text(companyName,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  font: arabicFont,
                )),
            pw.Text(companyNameEn,
                style: pw.TextStyle(
                  fontSize: 12,
                  font: arabicFont,
                )),
          ],
        ),
        pw.SizedBox(width: 100),
      ],
    );
  }

  static pw.Widget _buildInfoGrid({
    required List<List<String>> data,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: isArabic ? const pw.FlexColumnWidth(2) : const pw.FlexColumnWidth(1),
        1: isArabic ? const pw.FlexColumnWidth(1) : const pw.FlexColumnWidth(2),
      },
      children: data.map((row) {
        return pw.TableRow(
          children: isArabic
              ? [
                  _cell(row[1], arabicFont, isArabic,
                      align: pw.TextAlign.right),
                  _cell(row[0], arabicFont, isArabic,
                      align: pw.TextAlign.right,
                      fontWeight: pw.FontWeight.bold),
                ]
              : [
                  _cell(row[0], arabicFont, isArabic,
                      align: pw.TextAlign.left, fontWeight: pw.FontWeight.bold),
                  _cell(row[1], arabicFont, isArabic, align: pw.TextAlign.left),
                ],
        );
      }).toList(),
    );
  }

  static pw.Widget _buildParties({
    required String sender,
    required String senderEn,
    required String receiver,
    required String receiverEn,
    required String senderLabel,
    required String receiverLabel,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: isArabic
              ? [
                  _cell('$senderLabel: $sender', arabicFont, isArabic,
                      align: pw.TextAlign.right),
                  _cell('$receiverLabel: $receiver', arabicFont, isArabic,
                      align: pw.TextAlign.right),
                ]
              : [
                  _cell('$senderLabel: $senderEn', arabicFont, isArabic,
                      align: pw.TextAlign.left),
                  _cell('$receiverLabel: $receiverEn', arabicFont, isArabic,
                      align: pw.TextAlign.left),
                ],
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable({
    required List items,
    required String serialLabel,
    required String itemNameLabel,
    required String unitLabel,
    required String qtyLabel,
    required String notesLabel,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    final headers = isArabic
        ? [notesLabel, qtyLabel, unitLabel, itemNameLabel, serialLabel]
        : [serialLabel, itemNameLabel, unitLabel, qtyLabel, notesLabel];

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: isArabic
            ? const pw.FlexColumnWidth(1.5)
            : const pw.FlexColumnWidth(0.5),
        1: isArabic ? const pw.FlexColumnWidth(1) : const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1),
        3: isArabic ? const pw.FlexColumnWidth(3) : const pw.FlexColumnWidth(1),
        4: isArabic
            ? const pw.FlexColumnWidth(0.5)
            : const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map((h) => _cell(h, arabicFont, isArabic,
                  align: pw.TextAlign.center, fontWeight: pw.FontWeight.bold))
              .toList(),
        ),
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          final name = isArabic
              ? (item['nameAr'] ?? item['itemName'] ?? '')
              : (item['nameEn'] ?? item['itemName'] ?? '');
          final unit = item['unit'] ?? '--';
          final qty = (item['quantity'] as num?)?.toString() ?? '0';
          final notesItem = item['notes'] ?? '';

          final row = isArabic
              ? [
                  _cell(notesItem, arabicFont, isArabic,
                      align: pw.TextAlign.center),
                  _cell(qty, arabicFont, isArabic, align: pw.TextAlign.center),
                  _cell(unit, arabicFont, isArabic, align: pw.TextAlign.center),
                  _cell(name, arabicFont, isArabic, align: pw.TextAlign.right),
                  _cell('$index', arabicFont, isArabic,
                      align: pw.TextAlign.center),
                ]
              : [
                  _cell('$index', arabicFont, isArabic,
                      align: pw.TextAlign.center),
                  _cell(name, arabicFont, isArabic, align: pw.TextAlign.left),
                  _cell(unit, arabicFont, isArabic, align: pw.TextAlign.center),
                  _cell(qty, arabicFont, isArabic, align: pw.TextAlign.center),
                  _cell(notesItem, arabicFont, isArabic,
                      align: pw.TextAlign.center),
                ];
          return pw.TableRow(children: row);
        }),
      ],
    );
  }

  static pw.Widget _buildSummary({
    required int totalItems,
    required double totalQty,
    required String unitSuffix,
    required String totalItemsLabel,
    required String totalQtyLabel,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          children: isArabic
              ? [
                  _cell('$totalItems $unitSuffix', arabicFont, isArabic,
                      align: pw.TextAlign.right),
                  _cell(totalItemsLabel, arabicFont, isArabic,
                      align: pw.TextAlign.right,
                      fontWeight: pw.FontWeight.bold),
                ]
              : [
                  _cell(totalItemsLabel, arabicFont, isArabic,
                      align: pw.TextAlign.left, fontWeight: pw.FontWeight.bold),
                  _cell('$totalItems $unitSuffix', arabicFont, isArabic,
                      align: pw.TextAlign.left),
                ],
        ),
        pw.TableRow(
          children: isArabic
              ? [
                  _cell('${totalQty.toStringAsFixed(0)} $unitSuffix',
                      arabicFont, isArabic,
                      align: pw.TextAlign.right),
                  _cell(totalQtyLabel, arabicFont, isArabic,
                      align: pw.TextAlign.right,
                      fontWeight: pw.FontWeight.bold),
                ]
              : [
                  _cell(totalQtyLabel, arabicFont, isArabic,
                      align: pw.TextAlign.left, fontWeight: pw.FontWeight.bold),
                  _cell('${totalQty.toStringAsFixed(0)} $unitSuffix',
                      arabicFont, isArabic,
                      align: pw.TextAlign.left),
                ],
        ),
      ],
    );
  }

  static pw.Widget _buildNotes({
    required String notes,
    required String note1,
    required String note2,
    required String note3,
    required String notesSectionTitle,
    required bool isArabic,
    required pw.Font arabicFont,
    required pw.Font symbolFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(notesSectionTitle,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              font: arabicFont,
            )),
        pw.SizedBox(height: 2),
        _bulletPoint(note1, arabicFont, symbolFont),
        _bulletPoint(note2, arabicFont, symbolFont),
        _bulletPoint(note3, arabicFont, symbolFont),
        if (notes.isNotEmpty) _bulletPoint(notes, arabicFont, symbolFont),
      ],
    );
  }

  static pw.Widget _bulletPoint(
      String text, pw.Font arabicFont, pw.Font symbolFont) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(' • ', style: pw.TextStyle(font: symbolFont, fontSize: 10)),
        pw.Expanded(
          child: pw.Text(text,
              style: pw.TextStyle(font: arabicFont, fontSize: 10)),
        ),
      ],
    );
  }

  static pw.Widget _buildAcknowledgment({
    required String title,
    required String text,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              font: arabicFont,
            )),
        pw.SizedBox(height: 2),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            color: PdfColors.grey50,
          ),
          child: pw.Text(text,
              style: pw.TextStyle(font: arabicFont, fontSize: 10)),
        ),
      ],
    );
  }

/*   static pw.Widget _buildSignatures({
    required String storekeeper,
    required String delegate,
    required String receiverOfficial,
    required String nameLabel,
    required String signatureLabel,
    required String dateLabel,
    required String vehicleLabel,
    required String stampLabel,
    required String deliveryDate,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    // كل عمود يمثل دوراً مختلفاً
    final columns = [
      _signatureColumn(
        role: storekeeper,
        nameLabel: nameLabel,
        signatureLabel: signatureLabel,
        extra: dateLabel,
        extraValue: deliveryDate,
        arabicFont: arabicFont,
        isArabic: isArabic,
      ),
      _signatureColumn(
        role: delegate,
        nameLabel: nameLabel,
        signatureLabel: signatureLabel,
        extra: vehicleLabel,
        extraValue: '______________',
        arabicFont: arabicFont,
        isArabic: isArabic,
      ),
      _signatureColumn(
        role: receiverOfficial,
        nameLabel: nameLabel,
        signatureLabel: signatureLabel,
        extra: stampLabel,
        extraValue: '',
        arabicFont: arabicFont,
        isArabic: isArabic,
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(children: columns),
      ],
    );
  }  
 */

  static pw.Widget _buildSignatures({
    required String storekeeper,
    required String delegate,
    required String receiverOfficial,
    required String nameLabel,
    required String signatureLabel,
    required String dateLabel,
    required String vehicleLabel,
    required String stampLabel,
    required String deliveryDate,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    final columns = [
      _signatureColumn(
        role: storekeeper,
        nameLabel: nameLabel,
        signatureLabel: signatureLabel,
        extra: dateLabel,
        extraValue: deliveryDate,
        arabicFont: arabicFont,
        isArabic: isArabic,
      ),
      _signatureColumn(
        role: delegate,
        nameLabel: nameLabel,
        signatureLabel: signatureLabel,
        extra: vehicleLabel,
        extraValue: '______________',
        arabicFont: arabicFont,
        isArabic: isArabic,
      ),
      _signatureColumn(
        role: receiverOfficial,
        nameLabel: nameLabel,
        signatureLabel: signatureLabel,
        extra: stampLabel,
        extraValue: '',
        arabicFont: arabicFont,
        isArabic: isArabic,
      ),
    ];

    final orderedColumns = isArabic ? columns : columns.reversed.toList();

    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(children: orderedColumns),
        ],
      ),
    );
  }

  static pw.Widget _signatureColumn({
    required String role,
    required String nameLabel,
    required String signatureLabel,
    required String extra,
    required String extraValue,
    required pw.Font arabicFont,
    required bool isArabic,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(role,
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                font: arabicFont,
                fontSize: 10,
              )),
          pw.SizedBox(height: 2),
          pw.Text('$nameLabel: __________________',
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(font: arabicFont, fontSize: 9)),
          pw.Text('$signatureLabel: ________________',
              textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(font: arabicFont, fontSize: 9)),
          if (extra.isNotEmpty)
            pw.Text('$extra: $extraValue',
                textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(font: arabicFont, fontSize: 9)),
        ],
      ),
    );
  }

/*   static pw.Widget _signatureColumn({
    required String role,
    required String nameLabel,
    required String signatureLabel,
    required String extra,
    required String extraValue,
    required pw.Font arabicFont,
    required bool isArabic,
  }) {
    return pw.Directionality(
      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(
          crossAxisAlignment: isArabic
              ? pw.CrossAxisAlignment.start
              : pw.CrossAxisAlignment.end,
          children: [
            pw.Text(role,
                textAlign:isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  font: arabicFont,
                  fontSize: 10,
                )),
            pw.SizedBox(height: 2),
            pw.Text('$nameLabel: __________________',
                textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(font: arabicFont, fontSize: 9)),
            pw.Text('$signatureLabel: ________________',
                textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                style: pw.TextStyle(font: arabicFont, fontSize: 9)),
            if (extra.isNotEmpty)
              pw.Text('$extra: $extraValue',
                  textAlign: isArabic ? pw.TextAlign.right : pw.TextAlign.left,
                  style: pw.TextStyle(font: arabicFont, fontSize: 9)),
          ],
        ),
      ),
    );
  }
 */

  static pw.Widget _buildFooter({
    required String footerText,
    required bool isArabic,
    required pw.Font arabicFont,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Text(footerText,
          style: pw.TextStyle(
            font: arabicFont,
            fontSize: 8,
            color: PdfColors.grey600,
          ),
          textAlign: pw.TextAlign.center),
    );
  }

  static pw.Widget _cell(
    String text,
    pw.Font font,
    bool isArabic, {
    pw.TextAlign align = pw.TextAlign.left,
    pw.FontWeight fontWeight = pw.FontWeight.normal,
    double fontSize = 10,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text,
          style: pw.TextStyle(
            font: font,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
          textAlign: align),
    );
  }

  static Uint8List? _decodeBase64Logo(String? base64Logo) {
    if (base64Logo == null || base64Logo.isEmpty) return null;
    try {
      // ✅ استخدم base64.decode من dart:convert
      return base64.decode(base64Logo.split(',').last);
    } catch (_) {
      return null;
    }
  }

  // ===== دالة المشاركة الرئيسية =====
  static Future<void> generateAndShare({
    required Map<String, dynamic> order,
    required Map<String, dynamic> companyData,
    required Map<String, dynamic> receiverData,
    required Map<String, dynamic> deliveryMeta,
    String? base64Logo,
    bool isArabic = true,
    required Map<String, String> translations,
  }) async {
    final pdfBytes = await generateDeliveryNotePdf(
      order: order,
      companyData: companyData,
      receiverData: receiverData,
      deliveryMeta: deliveryMeta,
      base64Logo: base64Logo,
      isArabic: isArabic,
      translations: translations,
    );

    final fileName = 'delivery_note_${deliveryMeta['deliveryNumber']}.pdf';

    if (kIsWeb) {
      // ✅ على الويب: استخدام html مباشرة (تم استيراده أعلى الملف)
      // ignore: avoid_dynamic_calls
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..download = fileName
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    } else {
      // على الهواتف: حفظ ومشاركة
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    }
  }
}
