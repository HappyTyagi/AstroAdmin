class AdminPujaBooking {
  final int bookingId;
  final int userId;
  final String userName;
  final String mobileNumber;
  final String email;
  final int pujaId;
  final String pujaName;
  final String? pujaImage;
  final DateTime? slotTime;
  final DateTime? bookedAt;
  final String status;
  final String paymentMethod;
  final String transactionId;
  final String pujaOtp;
  final double totalPrice;
  final String? agoraChannel;

  const AdminPujaBooking({
    required this.bookingId,
    required this.userId,
    required this.userName,
    required this.mobileNumber,
    required this.email,
    required this.pujaId,
    required this.pujaName,
    required this.pujaImage,
    required this.slotTime,
    required this.bookedAt,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
    required this.pujaOtp,
    required this.totalPrice,
    required this.agoraChannel,
  });

  factory AdminPujaBooking.fromJson(Map<String, dynamic> json) {
    return AdminPujaBooking(
      bookingId: _readInt(json['bookingId']),
      userId: _readInt(json['userId']),
      userName: (json['userName'] ?? 'Unknown').toString(),
      mobileNumber: (json['mobileNumber'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      pujaId: _readInt(json['pujaId']),
      pujaName: (json['pujaName'] ?? '').toString(),
      pujaImage: json['pujaImage']?.toString(),
      slotTime: _readDate(json['slotTime']),
      bookedAt: _readDate(json['bookedAt']),
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
