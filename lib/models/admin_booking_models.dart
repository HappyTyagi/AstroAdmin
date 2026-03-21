class AdminPujaBooking {
  final int bookingId;
  final int userId;
  final String pujaNumber;
  final String userName;
  final String mobileNumber;
  final String email;
  final int pujaId;
  final String pujaName;
  final String? pujaImage;
  final DateTime? slotTime;
  final DateTime? bookedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String status;
  final String paymentMethod;
  final String transactionId;
  final String pujaOtp;
  final double totalPrice;
  final String? agoraChannel;

  const AdminPujaBooking({
    required this.bookingId,
    required this.userId,
    required this.pujaNumber,
    required this.userName,
    required this.mobileNumber,
    required this.email,
    required this.pujaId,
    required this.pujaName,
    required this.pujaImage,
    required this.slotTime,
    required this.bookedAt,
    required this.startedAt,
    required this.completedAt,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
    required this.pujaOtp,
    required this.totalPrice,
    required this.agoraChannel,
  });

  factory AdminPujaBooking.fromJson(Map<String, dynamic> json) {
    final int bookingId = _readInt(json['bookingId'] ?? json['id']);
    final int userId = _readInt(json['userId']);
    return AdminPujaBooking(
      bookingId: bookingId,
      userId: userId,
      pujaNumber: _readPujaNumber(json, userId: userId, bookingId: bookingId),
      userName: (json['userName'] ?? 'Unknown').toString(),
      mobileNumber: (json['mobileNumber'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      pujaId: _readInt(json['pujaId']),
      pujaName: (json['pujaName'] ?? '').toString(),
      pujaImage: json['pujaImage']?.toString(),
      slotTime: _readDate(json['slotTime']),
      bookedAt: _readDate(json['bookedAt']),
      startedAt: _readDate(json['startedAt']),
      completedAt: _readDate(json['completedAt']),
      status: (json['bookingStatus'] ?? '').toString(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      transactionId: (json['transactionId'] ?? '').toString(),
      pujaOtp: (json['pujaOtp'] ?? '').toString(),
      totalPrice: _readDouble(json['totalPrice']),
      agoraChannel: json['agoraChannel']?.toString(),
    );
  }
}

class AdminRemedyBooking {
  final String orderId;
  final int userId;
  final String userName;
  final String mobileNumber;
  final String email;
  final DateTime? purchasedAt;
  final String status;
  final String paymentMethod;
  final String transactionId;
  final int totalItems;
  final double totalAmount;
  final double fullAmount;
  final String address;
  final List<String> titles;

  const AdminRemedyBooking({
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.mobileNumber,
    required this.email,
    required this.purchasedAt,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
    required this.totalItems,
    required this.totalAmount,
    required this.fullAmount,
    required this.address,
    required this.titles,
  });

  factory AdminRemedyBooking.fromJson(Map<String, dynamic> json) {
    return AdminRemedyBooking(
      orderId: (json['orderId'] ?? '').toString(),
      userId: _readInt(json['userId']),
      userName: (json['userName'] ?? 'Unknown').toString(),
      mobileNumber: (json['mobileNumber'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      purchasedAt: _readDate(json['purchasedAt']),
      status: (json['status'] ?? '').toString(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      transactionId: (json['transactionId'] ?? '').toString(),
      totalItems: _readInt(json['totalItems']),
      totalAmount: _readDouble(json['totalAmount']),
      fullAmount: _readDouble(json['fullAmount']),
      address: (json['address'] ?? '').toString(),
      titles: (json['titles'] is List)
          ? (json['titles'] as List<dynamic>)
                .map((dynamic value) => value.toString())
                .toList()
          : <String>[],
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

double _readDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse((value ?? '0').toString()) ?? 0.0;
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String _readPujaNumber(
  Map<String, dynamic> json, {
  required int userId,
  required int bookingId,
}) {
  final List<dynamic> candidates = <dynamic>[
    json['pujaNumber'],
    json['bookingNumber'],
    json['bookingCode'],
    json['bookingDisplayId'],
    json['displayBookingId'],
    json['orderCode'],
    json['orderId'],
    json['invoiceNumber'],
  ];

  for (final dynamic candidate in candidates) {
    final String raw = (candidate ?? '').toString().trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') continue;
    return _normalizePujaNumber(raw, userId: userId, bookingId: bookingId);
  }
  return _buildPujaOrderId(userId: userId, bookingId: bookingId);
}

String _normalizePujaNumber(
  String raw, {
  required int userId,
  required int bookingId,
}) {
  final String normalized = raw.trim().toUpperCase();
  if (normalized.isEmpty) {
    return _buildPujaOrderId(userId: userId, bookingId: bookingId);
  }
  if (normalized.startsWith('PUJA-U') && normalized.contains('-B')) {
    return normalized;
  }
  if (normalized.startsWith('PUJA-')) {
    final int? numericId = int.tryParse(
      normalized.replaceFirst('PUJA-', '').trim(),
    );
    if (numericId != null) {
      return _buildPujaOrderId(userId: userId, bookingId: numericId);
    }
  }
  final int? standaloneNumericId = int.tryParse(normalized);
  if (standaloneNumericId != null) {
    return _buildPujaOrderId(userId: userId, bookingId: standaloneNumericId);
  }
  return raw.trim();
}

String _buildPujaOrderId({required int userId, required int bookingId}) {
  final String userCode = (userId < 0 ? 0 : userId).toString().padLeft(5, '0');
  final String bookingCode = (bookingId < 0 ? 0 : bookingId).toString().padLeft(
    6,
    '0',
  );
  return 'PUJA-U$userCode-B$bookingCode';
}
