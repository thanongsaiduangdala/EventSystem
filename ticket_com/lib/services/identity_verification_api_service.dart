import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'event_organizer_api_service.dart';
import '../config/api_config.dart';

class VerificationTypeModel {
  final int id;
  final String idType;

  VerificationTypeModel({required this.id, required this.idType});

  factory VerificationTypeModel.fromJson(Map<String, dynamic> json) {
    return VerificationTypeModel(
      id: json['VerificationTypeID'] as int,
      idType: json['IDType'] as String,
    );
  }
}

class VerificationStatusModel {
  final int id;
  final String statusName;

  VerificationStatusModel({required this.id, required this.statusName});

  factory VerificationStatusModel.fromJson(Map<String, dynamic> json) {
    return VerificationStatusModel(
      id: json['VerificationStatusID'] as int,
      statusName: json['StatusName'] as String,
    );
  }
}

/// Row shape returned by GET /identityverification/verification/verified-accounts
class VerifiedAccountModel {
  final int accountId;
  final String firstName;
  final String lastName;
  final String email;

  VerifiedAccountModel({
    required this.accountId,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory VerifiedAccountModel.fromJson(Map<String, dynamic> json) {
    return VerifiedAccountModel(
      accountId: json['AccountID'] as int,
      firstName: json['FirstName']?.toString() ?? '',
      lastName: json['LastName']?.toString() ?? '',
      email: json['Email']?.toString() ?? '',
    );
  }
}

class IdentityVerificationModel {
  final int id;
  final int accountId;
  final int verificationTypeId;
  final String idNumberEncrypted;
  final String fullNameOnId;
  final String dateOfBirth; // yyyy-MM-dd
  final String documentImagePath;
  final int verificationStatusId;
  final int? reviewedByAccountId;
  final String submittedAtYmdt;
  final String? reviewedAtYmdt;

  IdentityVerificationModel({
    required this.id,
    required this.accountId,
    required this.verificationTypeId,
    required this.idNumberEncrypted,
    required this.fullNameOnId,
    required this.dateOfBirth,
    required this.documentImagePath,
    required this.verificationStatusId,
    required this.reviewedByAccountId,
    required this.submittedAtYmdt,
    required this.reviewedAtYmdt,
  });

  factory IdentityVerificationModel.fromJson(Map<String, dynamic> json) {
    return IdentityVerificationModel(
      id: json['VerificationID'] as int,
      accountId: json['AccountID'] as int,
      verificationTypeId: json['VerificationTypeID'] as int,
      idNumberEncrypted: json['IDNumberEncrypted']?.toString() ?? '',
      fullNameOnId: json['FullNameOnID']?.toString() ?? '',
      dateOfBirth: json['DateOfBirth']?.toString() ?? '',
      documentImagePath: json['DocumentImageRedPath']?.toString() ?? '',
      verificationStatusId: json['VerificationStatusID'] as int,
      reviewedByAccountId: json['ReviewedByAccountID'] as int?,
      submittedAtYmdt: json['SubmittedAtYMDT']?.toString() ?? '',
      reviewedAtYmdt: json['ReviewedAtYMDT']?.toString(),
    );
  }
}

/// Verification row enriched with the applicant's account details, returned
/// by GET /identityverification/verification/with-details (Employee Dashboard).
class IdentityVerificationDetailModel {
  final IdentityVerificationModel verification;
  final String accountFirstName;
  final String accountLastName;
  final String accountEmail;
  final String accountPhone;
  final int accountStatusId;
  final List<EventOrganizer> organizers;

  IdentityVerificationDetailModel({
    required this.verification,
    required this.accountFirstName,
    required this.accountLastName,
    required this.accountEmail,
    required this.accountPhone,
    required this.accountStatusId,
    this.organizers = const [],
  });

  String get accountFullName => '$accountFirstName $accountLastName';

  factory IdentityVerificationDetailModel.fromJson(Map<String, dynamic> json) {
    return IdentityVerificationDetailModel(
      verification: IdentityVerificationModel.fromJson(json),
      accountFirstName: json['FirstName']?.toString() ?? '',
      accountLastName: json['LastName']?.toString() ?? '',
      accountEmail: json['Email']?.toString() ?? '',
      accountPhone: json['PhoneNum']?.toString() ?? '',
      accountStatusId: json['AccountStatusID'] as int? ?? 0,
      organizers: (json['Organizers'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((o) => EventOrganizer.fromJson(o))
          .toList(),
    );
  }
}

class IdentityVerificationApiService {
  static String get baseUrl => ApiConfig.baseUrl;
  static const _prefix = '/identityverification';

  static Map<String, String> _authHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (AuthService.currentToken != null) {
      headers['Authorization'] = 'Bearer ${AuthService.currentToken}';
    }
    return headers;
  }

  static Exception _handleError(http.Response response, String fallbackMsg) {
    if (response.statusCode == 401) {
      return Exception('Session expired. Please log in again.');
    }
    if (response.statusCode == 403) {
      return Exception('Developer access required.');
    }
    try {
      final error = jsonDecode(response.body);
      return Exception(error['detail']?.toString() ?? fallbackMsg);
    } catch (_) {
      return Exception(fallbackMsg);
    }
  }

  static Uri _u(String path) => Uri.parse('$baseUrl$_prefix$path');

  /// Mirrors CategoryApiService.fullImageUrl -- the backend stores/returns a
  /// path relative to the static file mount (e.g. "identity_documents/xyz.jpg").
  static String fullImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl/static/$path';
  }

  /// Uploads a photo (camera capture or gallery pick) for a verification
  /// record's DocumentImageRedPath field. Returns the relative path to store
  /// on the record, e.g. "identity_documents/<uuid>.jpg".
  ///
  /// Takes raw bytes (not a dart:io File/path) so this works on Flutter Web
  /// as well as mobile/desktop -- MultipartFile.fromPath needs dart:io,
  /// which isn't available on web.
  static Future<String> uploadDocumentImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final uri = _u('/verification/upload-document');
    final request = http.MultipartRequest('POST', uri);
    if (AuthService.currentToken != null) {
      request.headers['Authorization'] = 'Bearer ${AuthService.currentToken}';
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['path'] as String;
    }
    throw _handleError(response, 'Failed to upload document image');
  }

  // ---------------- identity verification records ----------------

  static Future<List<IdentityVerificationModel>> getAllVerifications() async {
    final res = await http.get(_u('/verification/all'), headers: _authHeaders());
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((e) => IdentityVerificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _handleError(res, 'Failed to load identity verifications');
  }

  /// Employee Dashboard data: pending reviews first, with applicant account
  /// details attached. Requires SUPERADMIN or EMPLOYEE.
  static Future<List<IdentityVerificationDetailModel>>
      getAllVerificationsWithAccounts() async {
    final res = await http.get(
      _u('/verification/with-details'),
      headers: _authHeaders(),
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((e) => IdentityVerificationDetailModel.fromJson(
              e as Map<String, dynamic>))
          .toList();
    }
    throw _handleError(res, 'Failed to load identity verifications');
  }

  /// Superadmin/Employee action: accept the request (status 2) AND grant the
  /// applicant account ORGANIZER status so they can create events.
  static Future<String> approveVerification(int verificationId) async {
    final res = await http.post(
      _u('/verification/$verificationId/approve'),
      headers: _authHeaders(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['msg']?.toString() ?? 'Identity verification approved';
    }
    throw _handleError(res, 'Failed to approve identity verification');
  }

  /// Superadmin/Employee action: reject the request (status 3). The account
  /// status is untouched.
  static Future<String> denyVerification(int verificationId) async {
    final res = await http.post(
      _u('/verification/$verificationId/deny'),
      headers: _authHeaders(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['msg']?.toString() ?? 'Identity verification denied';
    }
    throw _handleError(res, 'Failed to deny identity verification');
  }

  static Future<IdentityVerificationModel> getVerificationById(int id) async {
    final res = await http.get(_u('/verification/$id'), headers: _authHeaders());
    if (res.statusCode == 200) {
      return IdentityVerificationModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }
    throw _handleError(res, 'Failed to load identity verification');
  }

  static Future<List<IdentityVerificationModel>> getVerificationsByAccount(
    int accountId,
  ) async {
    final res = await http.get(
      _u('/verification/by-account/$accountId'),
      headers: _authHeaders(),
    );
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((e) => IdentityVerificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (res.statusCode == 404) {
      return [];
    }
    throw _handleError(res, 'Failed to load verifications for account');
  }

  /// Accounts with at least one Accepted (VerificationStatusID == 2) record.
  static Future<List<VerifiedAccountModel>> getVerifiedAccountsForOrganizer() async {
    final res = await http.get(_u('/verification/verified-accounts'), headers: _authHeaders());
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((e) => VerifiedAccountModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _handleError(res, 'Failed to load verified accounts');
  }

  static Future<Map<String, dynamic>> createVerification({
    required int accountId,
    required int verificationTypeId,
    required String idNumberEncrypted,
    required String fullNameOnId,
    required String dateOfBirth,
    required String documentImagePath,
    required int verificationStatusId,
    int? reviewedByAccountId,
    required String submittedAtYmdt,
    String? reviewedAtYmdt,
  }) async {
    final res = await http.post(
      _u('/verification/create'),
      headers: _authHeaders(),
      body: jsonEncode({
        'AccountID': accountId,
        'VerificationTypeID': verificationTypeId,
        'IDNumberEncrypted': idNumberEncrypted,
        'FullNameOnID': fullNameOnId,
        'DateOfBirth': dateOfBirth,
        'DocumentImageRedPath': documentImagePath,
        'VerificationStatusID': verificationStatusId,
        'ReviewedByAccountID': reviewedByAccountId,
        'SubmittedAtYMDT': submittedAtYmdt,
        'ReviewedAtYMDT': reviewedAtYmdt,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _handleError(res, 'Failed to create identity verification');
  }

  static Future<void> updateVerification({
    required int verificationId,
    required int accountId,
    required int verificationTypeId,
    required String idNumberEncrypted,
    required String fullNameOnId,
    required String dateOfBirth,
    required String documentImagePath,
    required int verificationStatusId,
    int? reviewedByAccountId,
    required String submittedAtYmdt,
    String? reviewedAtYmdt,
  }) async {
    final res = await http.put(
      _u('/verification/update'),
      headers: _authHeaders(),
      body: jsonEncode({
        'VerificationID': verificationId,
        'AccountID': accountId,
        'VerificationTypeID': verificationTypeId,
        'IDNumberEncrypted': idNumberEncrypted,
        'FullNameOnID': fullNameOnId,
        'DateOfBirth': dateOfBirth,
        'DocumentImageRedPath': documentImagePath,
        'VerificationStatusID': verificationStatusId,
        'ReviewedByAccountID': reviewedByAccountId,
        'SubmittedAtYMDT': submittedAtYmdt,
        'ReviewedAtYMDT': reviewedAtYmdt,
      }),
    );
    if (res.statusCode != 200) {
      throw _handleError(res, 'Failed to update identity verification');
    }
  }

  static Future<void> deleteVerification(int verificationId) async {
    final res = await http.delete(
      _u('/verification/$verificationId'),
      headers: _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw _handleError(res, 'Failed to delete identity verification');
    }
  }

  // ---------------- verification types ----------------

  static Future<List<VerificationTypeModel>> getAllTypes() async {
    final res = await http.get(_u('/type/all'), headers: _authHeaders());
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((e) => VerificationTypeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _handleError(res, 'Failed to load verification types');
  }

  static Future<Map<String, dynamic>> createType(String idType) async {
    final res = await http.post(
      _u('/type/create'),
      headers: _authHeaders(),
      body: jsonEncode({'IDType': idType}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _handleError(res, 'Failed to create verification type');
  }

  static Future<void> updateType({
    required int verificationTypeId,
    required String idType,
  }) async {
    final res = await http.put(
      _u('/type/update'),
      headers: _authHeaders(),
      body: jsonEncode({
        'VerificationTypeID': verificationTypeId,
        'IDType': idType,
      }),
    );
    if (res.statusCode != 200) {
      throw _handleError(res, 'Failed to update verification type');
    }
  }

  static Future<void> deleteType(int verificationTypeId) async {
    final res = await http.delete(_u('/type/$verificationTypeId'), headers: _authHeaders());
    if (res.statusCode != 200) {
      throw _handleError(res, 'Failed to delete verification type');
    }
  }

  // ---------------- verification statuses ----------------

  static Future<List<VerificationStatusModel>> getAllStatuses() async {
    final res = await http.get(_u('/status/all'), headers: _authHeaders());
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((e) => VerificationStatusModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw _handleError(res, 'Failed to load verification statuses');
  }

  static Future<Map<String, dynamic>> createStatus(String statusName) async {
    final res = await http.post(
      _u('/status/create'),
      headers: _authHeaders(),
      body: jsonEncode({'StatusName': statusName}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw _handleError(res, 'Failed to create verification status');
  }

  static Future<void> updateStatus({
    required int verificationStatusId,
    required String statusName,
  }) async {
    final res = await http.put(
      _u('/status/update'),
      headers: _authHeaders(),
      body: jsonEncode({
        'VerificationStatusID': verificationStatusId,
        'StatusName': statusName,
      }),
    );
    if (res.statusCode != 200) {
      throw _handleError(res, 'Failed to update verification status');
    }
  }

  static Future<void> deleteStatus(int verificationStatusId) async {
    final res = await http.delete(_u('/status/$verificationStatusId'), headers: _authHeaders());
    if (res.statusCode != 200) {
      throw _handleError(res, 'Failed to delete verification status');
    }
  }
}
