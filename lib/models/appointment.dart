// Gerekli paketleri import ediyoruz.

// Randevular için veri modeli (Appointment)
class Appointment {
  final int? appointmentId;
  // Supabase uuid için ek alan (mevcut int id korunur)
  final String? randevuId; // uuid
  final int? calisanId; // çalışan id
  final String customerName;
  final String employeeName;
  final String serviceName;
  final String process;
  final double totalPrice;
  final DateTime appointmentDateTime;
  String approvalStatus;
  // Puanlama alanları
  final int? rating; // 1..5
  final String? ratingComment;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final String? customerPhone;
  final String? customerEmail;

  Appointment({
    this.appointmentId,
    this.randevuId,
    this.calisanId,
    required this.customerName,
    required this.employeeName,
    required this.serviceName,
    required this.process,
    required this.totalPrice,
    required this.appointmentDateTime,
    required this.approvalStatus,
    this.rating,
    this.ratingComment,
    this.createdAt,
    this.updatedAt,
    this.notes,
    this.customerPhone,
    this.customerEmail,
  });

  Map<String, dynamic> toJson() {
    return {
      'appointmentId': appointmentId,
      'randevu_id': randevuId,
      'calisan_id': calisanId,
      'customerName': customerName,
      'employeeName': employeeName,
      'serviceName': serviceName,
      'process': process,
      'totalPrice': totalPrice,
      'appointmentDateTime': appointmentDateTime.toIso8601String(),
      'approvalStatus': approvalStatus,
      'rating': rating,
      'rating_comment': ratingComment,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notes': notes,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      appointmentId: json['appointmentId'],
      randevuId: json['randevu_id'],
      calisanId: json['calisan_id'],
      customerName: json['customerName'],
      employeeName: json['employeeName'],
      serviceName: json['serviceName'],
      process: json['process'],
      totalPrice: (json['totalPrice'] as num).toDouble(),
      appointmentDateTime: DateTime.parse(json['appointmentDateTime']),
      approvalStatus: json['approvalStatus'],
      rating: json['rating'] as int?,
      ratingComment: json['rating_comment'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      notes: json['notes'],
      customerPhone: json['customerPhone'],
      customerEmail: json['customerEmail'],
    );
  }

  Appointment copyWith({
    int? appointmentId,
    String? randevuId,
    int? calisanId,
    String? customerName,
    String? employeeName,
    String? serviceName,
    String? process,
    double? totalPrice,
    DateTime? appointmentDateTime,
    String? approvalStatus,
    int? rating,
    String? ratingComment,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? customerPhone,
    String? customerEmail,
  }) {
    return Appointment(
      appointmentId: appointmentId ?? this.appointmentId,
      randevuId: randevuId ?? this.randevuId,
      calisanId: calisanId ?? this.calisanId,
      customerName: customerName ?? this.customerName,
      employeeName: employeeName ?? this.employeeName,
      serviceName: serviceName ?? this.serviceName,
      process: process ?? this.process,
      totalPrice: totalPrice ?? this.totalPrice,
      appointmentDateTime: appointmentDateTime ?? this.appointmentDateTime,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
    );
  }
}
