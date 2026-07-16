// models/journal_entry.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntryLine {
  final String accountId;
  final double debit;
  final double credit;
  final String? description;

  JournalEntryLine({
    required this.accountId,
    required this.debit,
    required this.credit,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'debit': debit,
      'credit': credit,
      'description': description,
    };
  }

  factory JournalEntryLine.fromMap(Map<String, dynamic> map) {
    return JournalEntryLine(
      accountId: map['accountId'] ?? '',
      debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      description: map['description'],
    );
  }
}

class JournalEntry {
  final String id;
  final String companyId;
  final DateTime entryDate;
  final String description;
  final String referenceId;
  final String referenceType;
  final List<JournalEntryLine> lines;
  final DateTime createdAt;
  final String createdBy;

  JournalEntry({
    required this.id,
    required this.companyId,
    required this.entryDate,
    required this.description,
    required this.referenceId,
    required this.referenceType,
    required this.lines,
    required this.createdAt,
    required this.createdBy,
  });

  double get totalDebit => lines.fold(0, (total, line) => total + line.debit);
  double get totalCredit => lines.fold(0, (total, line) => total + line.credit);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'entryDate': Timestamp.fromDate(entryDate),
      'description': description,
      'referenceId': referenceId,
      'referenceType': referenceType,
      'lines': lines.map((l) => l.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map, String id) {
    return JournalEntry(
      id: id,
      companyId: map['companyId'] ?? '',
      entryDate: (map['entryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] ?? '',
      referenceId: map['referenceId'] ?? '',
      referenceType: map['referenceType'] ?? '',
      lines: (map['lines'] as List?)
              ?.map((l) => JournalEntryLine.fromMap(l))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }
}