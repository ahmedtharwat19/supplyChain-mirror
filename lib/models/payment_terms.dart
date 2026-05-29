// lib/models/payment_terms.dart

class PaymentTerm {
  final String code;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final int days; // عدد الأيام للدفع

  const PaymentTerm({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.days,
  });

  String getName(bool isArabic) => isArabic ? nameAr : nameEn;
  String getDescription(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  // قائمة شروط الدفع المحددة مسبقاً
  static const List<PaymentTerm> paymentTerms = [
    PaymentTerm(
      code: 'CASH',
      nameAr: 'دفع نقدي',
      nameEn: 'Cash',
      descriptionAr: 'الدفع عند الاستلام نقداً',
      descriptionEn: 'Cash on delivery',
      days: 0,
    ),
    PaymentTerm(
      code: 'NET_30',
      nameAr: 'صافي 30 يوم',
      nameEn: 'Net 30',
      descriptionAr: 'السداد خلال 30 يوماً من تاريخ الفاتورة',
      descriptionEn: 'Payment due within 30 days of invoice date',
      days: 30,
    ),
    PaymentTerm(
      code: 'NET_45',
      nameAr: 'صافي 45 يوم',
      nameEn: 'Net 45',
      descriptionAr: 'السداد خلال 45 يوماً من تاريخ الفاتورة',
      descriptionEn: 'Payment due within 45 days of invoice date',
      days: 45,
    ),
    PaymentTerm(
      code: 'NET_60',
      nameAr: 'صافي 60 يوم',
      nameEn: 'Net 60',
      descriptionAr: 'السداد خلال 60 يوماً من تاريخ الفاتورة',
      descriptionEn: 'Payment due within 60 days of invoice date',
      days: 60,
    ),
    PaymentTerm(
      code: 'ADVANCE',
      nameAr: 'دفعة مقدمة',
      nameEn: 'Advance Payment',
      descriptionAr: 'دفعة مقدمة بنسبة 30% والباقي عند التسليم',
      descriptionEn: '30% advance payment, balance upon delivery',
      days: 0,
    ),
    PaymentTerm(
      code: 'LETTER_OF_CREDIT',
      nameAr: 'خطاب اعتماد',
      nameEn: 'Letter of Credit',
      descriptionAr: 'خطاب اعتماد بنكي',
      descriptionEn: 'Letter of Credit (L/C)',
      days: 0,
    ),
  ];
}

class DeliveryTerm {
  final String code;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;

  const DeliveryTerm({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.descriptionAr,
    required this.descriptionEn,
  });

  String getName(bool isArabic) => isArabic ? nameAr : nameEn;
  String getDescription(bool isArabic) => isArabic ? descriptionAr : descriptionEn;

  // قائمة شروط التسليم المحددة مسبقاً (Incoterms)
  static const List<DeliveryTerm> deliveryTerms = [
    DeliveryTerm(
      code: 'EXW',
      nameAr: 'تسليم من المصنع',
      nameEn: 'Ex Works (EXW)',
      descriptionAr: 'يستلم المشتري البضاعة من مقر البائع',
      descriptionEn: 'Buyer picks up goods at seller\'s premises',
    ),
    DeliveryTerm(
      code: 'FOB',
      nameAr: 'تسليم ظهر السفينة',
      nameEn: 'Free On Board (FOB)',
      descriptionAr: 'البائع يسلم البضاعة على ظهر السفينة',
      descriptionEn: 'Seller delivers goods onto the vessel',
    ),
    DeliveryTerm(
      code: 'CIF',
      nameAr: 'تسليم شامل التكاليف',
      nameEn: 'Cost, Insurance & Freight (CIF)',
      descriptionAr: 'البائع يتحمل التكاليف والتأمين والشحن',
      descriptionEn: 'Seller covers cost, insurance, and freight',
    ),
    DeliveryTerm(
      code: 'DDP',
      nameAr: 'تسليم شامل الرسوم',
      nameEn: 'Delivered Duty Paid (DDP)',
      descriptionAr: 'البائع يتحمل جميع التكاليف والرسوم حتى وصول البضاعة',
      descriptionEn: 'Seller bears all costs and risks until delivery',
    ),
    DeliveryTerm(
      code: 'FCA',
      nameAr: 'تسليم إلى الناقل',
      nameEn: 'Free Carrier (FCA)',
      descriptionAr: 'البائع يسلم البضاعة إلى الناقل المعين',
      descriptionEn: 'Seller delivers goods to nominated carrier',
    ),
  ];
}