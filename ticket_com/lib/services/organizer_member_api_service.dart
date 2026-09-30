import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';
import 'attendee_response_api_service.dart';
import 'event_question_api_service.dart';
import 'ticket_type_api_service.dart';

class OrganizerMemberModel {
  final int id;
  final int accountId;
  final int eventOrganizerId;
  final int teamRoleId;
  final int memberStatusId;

  OrganizerMemberModel({
    required this.id,
    required this.accountId,
    required this.eventOrganizerId,
    required this.teamRoleId,
    this.memberStatusId = 1,
  });

  factory OrganizerMemberModel.fromJson(Map<String, dynamic> json) {
    return OrganizerMemberModel(
      id: json['MemberID'] as int,
      accountId: json['AccountID'] as int,
      eventOrganizerId: json['EventOrganizerID'] as int,
      teamRoleId: json['TeamRoleID'] as int,
      memberStatusId: json['MemberStatusID'] as int? ?? 1,
    );
  }
}

class OrganizerMemberDetail {
  final int id;
  final int accountId;
  final int eventOrganizerId;
  final int teamRoleId;
  final int memberStatusId;
  final String firstName;
  final String lastName;
  final String email;
  final String roleName;
  final String statusName;
  final String organizerName;
  final String? organizerLogoPath;
  final String? organizerDescription;
  final int? createdByAccountId;

  OrganizerMemberDetail({
    required this.id,
    required this.accountId,
    required this.eventOrganizerId,
    required this.teamRoleId,
    required this.memberStatusId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.roleName,
    required this.statusName,
    required this.organizerName,
    this.organizerLogoPath,
    this.organizerDescription,
    this.createdByAccountId,
  });

  factory OrganizerMemberDetail.fromJson(Map<String, dynamic> json) {
    return OrganizerMemberDetail(
      id: json['MemberID'] as int,
      accountId: json['AccountID'] as int,
      eventOrganizerId: json['EventOrganizerID'] as int,
      teamRoleId: json['TeamRoleID'] as int,
      memberStatusId: json['MemberStatusID'] as int? ?? 1,
      firstName: (json['FirstName'] ?? '').toString(),
      lastName: (json['LastName'] ?? '').toString(),
      email: (json['Email'] ?? '').toString(),
      roleName: (json['TeamRoleName'] ?? json['RoleName'] ?? '').toString(),
      statusName: (json['StatusName'] ?? '').toString(),
      organizerName: (json['EventOrganizerName'] ?? '').toString(),
      organizerLogoPath: json['EventOrganizerLogoPath']?.toString(),
      organizerDescription:
          json['EventOrganizerDiscription']?.toString() ?? '',
      createdByAccountId: json['CreatedByAccountID'] as int?,
    );
  }

  String get fullName {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isEmpty && l.isEmpty) return email.isEmpty ? 'Member' : email;
    return '$f $l'.trim();
  }
}

class TeamRoleModel {
  final int id;
  final String name;

  TeamRoleModel({required this.id, required this.name});

  factory TeamRoleModel.fromJson(Map<String, dynamic> json) {
    return TeamRoleModel(
      id: json['TeamRoleID'] as int,
      name: json['TeamRoleName']?.toString() ?? '',
    );
  }
}

class TeamRole {
  static const int staff = 1;
  static const int volunteer = 2;
  static const int pageDesigner = 3;
  static const int orgAdmin = 4;
  static const int orgOwner = 5;

  static String name(int roleId) {
    switch (roleId) {
      case staff:
        return 'Staff / Employee';
      case volunteer:
        return 'Volunteer';
      case pageDesigner:
        return 'Page Designer';
      case orgAdmin:
        return 'Org Admin';
      case orgOwner:
        return 'Org Owner';
      default:
        return 'Member';
    }
  }
}

class TeamMembership {
  final int memberId;
  final int accountId;
  final int eventOrganizerId;
  final int teamRoleId;
  final int memberStatusId;
  final String teamRoleName;
  final String organizerName;
  final String? organizerLogoPath;
  final String? organizerDescription;
  final int createdByAccountId;

  TeamMembership({
    required this.memberId,
    required this.accountId,
    required this.eventOrganizerId,
    required this.teamRoleId,
    required this.memberStatusId,
    required this.teamRoleName,
    required this.organizerName,
    required this.createdByAccountId,
    this.organizerLogoPath,
    this.organizerDescription,
  });

  factory TeamMembership.fromJson(Map<String, dynamic> json) {
    return TeamMembership(
      memberId: json['MemberID'] as int,
      accountId: json['AccountID'] as int,
      eventOrganizerId: json['EventOrganizerID'] as int,
      teamRoleId: json['TeamRoleID'] as int,
      memberStatusId: json['MemberStatusID'] as int? ?? 2,
      teamRoleName:
          (json['TeamRoleName'] ?? TeamRole.name(json['TeamRoleID'] as int? ?? 0))
              .toString(),
      organizerName: (json['EventOrganizerName'] ?? '').toString(),
      organizerLogoPath: json['EventOrganizerLogoPath']?.toString(),
      organizerDescription:
          (json['EventOrganizerDiscription'] ?? '').toString(),
      createdByAccountId: json['CreatedByAccountID'] as int? ?? 0,
    );
  }

  bool get isManager => teamRoleId == TeamRole.orgAdmin || teamRoleId == TeamRole.orgOwner;
  bool get isOwner => createdByAccountId == accountId || teamRoleId == TeamRole.orgOwner;
  bool get isDesigner => teamRoleId == TeamRole.pageDesigner;
  bool get isStaff => teamRoleId == TeamRole.staff;
  bool get isVolunteer => teamRoleId == TeamRole.volunteer;
  bool get canManageTeam => isManager;
}

class MemberEvent {
  final int eventId;
  final String eventName;
  final DateTime start;
  final DateTime end;
  final String address;
  final String description;
  final int organizerId;
  final bool onePerPerson;
  final int eventStatusId;
  final bool eventVisible;
  final bool assigned;
  final String? eventRoleName;
  final int teamRoleId;
  final double latitude;
  final double longitude;

  MemberEvent({
    required this.eventId,
    required this.eventName,
    required this.start,
    required this.end,
    required this.address,
    required this.description,
    required this.organizerId,
    required this.onePerPerson,
    required this.eventStatusId,
    required this.eventVisible,
    required this.assigned,
    required this.teamRoleId,
    required this.latitude,
    required this.longitude,
    this.eventRoleName,
  });

  factory MemberEvent.fromJson(Map<String, dynamic> json) {
    final teamRoleId = json['TeamRoleID'] as int? ?? 0;
    final isManager =
        teamRoleId == TeamRole.orgAdmin || teamRoleId == TeamRole.orgOwner;
    final assigned = (json['assigned'] as bool?) ?? false;
    return MemberEvent(
      eventId: json['EventID'] as int,
      eventName: (json['EventName'] ?? '').toString(),
      start: DateTime.tryParse(json['EventStartingYMDT'].toString()) ??
          DateTime.now(),
      end: DateTime.tryParse(json['EventEndingYMDT'].toString()) ??
          DateTime.now(),
      address: (json['EventAddress'] ?? '').toString(),
      description: (json['EventDescription'] ?? '').toString(),
      organizerId: json['EventOrganizerID'] as int,
      onePerPerson: json['OnePerPerson'] == 1 || json['OnePerPerson'] == true,
      eventStatusId: (json['EventStatusID'] as int?) ?? 2,
      eventVisible: json['EventVisible'] == null ||
          json['EventVisible'] == 1 ||
          json['EventVisible'] == true,
      assigned: isManager || assigned,
      eventRoleName: json['EventRoleName']?.toString(),
      teamRoleId: teamRoleId,
      latitude: double.tryParse(json['Latitude'].toString()) ?? 0,
      longitude: double.tryParse(json['Longitude'].toString()) ?? 0,
    );
  }

  bool get canCheckIn => assigned;
}

class MyEventsResult {
  final TeamMembership org;
  final List<MemberEvent> events;

  MyEventsResult({required this.org, required this.events});
}

class AssignedEvent {
  final int eventId;
  final String eventName;

  AssignedEvent({required this.eventId, required this.eventName});

  factory AssignedEvent.fromJson(Map<String, dynamic> json) {
    return AssignedEvent(
      eventId: json['EventID'] as int,
      eventName: (json['EventName'] ?? '').toString(),
    );
  }
}

class OrgTeamMember {
  final int memberId;
  final int accountId;
  final String firstName;
  final String lastName;
  final String email;
  final int teamRoleId;
  final String teamRoleName;
  final int memberStatusId;
  final String statusName;
  final bool isOwner;
  final List<AssignedEvent> assignedEvents;

  OrgTeamMember({
    required this.memberId,
    required this.accountId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.teamRoleId,
    required this.teamRoleName,
    required this.memberStatusId,
    required this.statusName,
    required this.isOwner,
    required this.assignedEvents,
  });

  factory OrgTeamMember.fromJson(Map<String, dynamic> json) {
    final assignments = json['AssignedEvents'] as List<dynamic>? ?? [];
    return OrgTeamMember(
      memberId: json['MemberID'] as int,
      accountId: json['AccountID'] as int,
      firstName: (json['FirstName'] ?? '').toString(),
      lastName: (json['LastName'] ?? '').toString(),
      email: (json['Email'] ?? '').toString(),
      teamRoleId: json['TeamRoleID'] as int,
      teamRoleName: (json['TeamRoleName'] ?? '').toString(),
      memberStatusId: json['MemberStatusID'] as int? ?? 2,
      statusName: (json['StatusName'] ?? '').toString(),
      isOwner: (json['IsOwner'] as bool?) ?? false,
      assignedEvents: assignments
          .map((e) => AssignedEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get fullName {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isEmpty && l.isEmpty) return email.isEmpty ? 'Member' : email;
    return '$f $l'.trim();
  }
}

class EventAttendee {
  final int attendeeId;
  final int ticketTypeId;
  final int orderId;
  final String firstName;
  final String lastName;
  final String phoneNum;
  final String email;
  final String? nationalId;
  final bool isValid;
  final String ticketTypeName;
  final int ticketPrice;
  final int eventId;
  final String? paymentDate;
  final int? checkInId;
  final int? checkedInByMemberId;
  final String? checkedInAt;

  EventAttendee({
    required this.attendeeId,
    required this.ticketTypeId,
    required this.orderId,
    required this.firstName,
    required this.lastName,
    required this.phoneNum,
    required this.email,
    required this.isValid,
    required this.ticketTypeName,
    required this.ticketPrice,
    required this.eventId,
    this.nationalId,
    this.paymentDate,
    this.checkInId,
    this.checkedInByMemberId,
    this.checkedInAt,
  });

  factory EventAttendee.fromJson(Map<String, dynamic> json) {
    return EventAttendee(
      attendeeId: json['attendeeID'] as int,
      ticketTypeId: json['TicketTypeID'] as int,
      orderId: json['OrderID'] as int,
      firstName: (json['FirstName'] ?? '').toString(),
      lastName: (json['LastName'] ?? '').toString(),
      phoneNum: (json['PhoneNum'] ?? '').toString(),
      email: (json['Email'] ?? '').toString(),
      nationalId: json['NationalID']?.toString(),
      isValid: (json['IsValid'] ?? 1) == 1 || (json['IsValid'] ?? 1) == true,
      ticketTypeName: (json['TicketTypeName'] ?? '').toString(),
      ticketPrice: (json['TicketPrice'] as num?)?.toInt() ?? 0,
      eventId: json['EventID'] as int,
      paymentDate: json['PaymentDateYMDT']?.toString(),
      checkInId: json['CheckInID'] as int?,
      checkedInByMemberId: json['CheckedInByMemberID'] as int?,
      checkedInAt: json['CheckedInAtYMDT']?.toString(),
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  bool get checkedIn => checkInId != null;
}

class ResolvedAttendee {
  final int attendeeId;
  final String firstName;
  final String lastName;
  final bool isValid;
  final String ticketTypeName;
  final int? checkInId;
  final String? checkedInAt;

  ResolvedAttendee({
    required this.attendeeId,
    required this.firstName,
    required this.lastName,
    required this.isValid,
    required this.ticketTypeName,
    this.checkInId,
    this.checkedInAt,
  });

  factory ResolvedAttendee.fromJson(Map<String, dynamic> json) {
    final validity = json['IsValid'] ?? 1;
    return ResolvedAttendee(
      attendeeId: json['attendeeID'] as int,
      firstName: (json['FirstName'] ?? '').toString(),
      lastName: (json['LastName'] ?? '').toString(),
      isValid: validity == 1 || validity == true,
      ticketTypeName: (json['TicketTypeName'] ?? '').toString(),
      checkInId: json['CheckInID'] as int?,
      checkedInAt: json['CheckedInAtYMDT']?.toString(),
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  bool get checkedIn => checkInId != null;
}

class OrganizerMemberApiService {
  static String get baseUrl => ApiConfig.baseUrl;

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
    try {
      if (response.statusCode == 403) {
        final detail = jsonDecode(response.body)['detail']?.toString();
        return Exception(detail == null || detail.isEmpty
            ? 'You do not have permission for this action.'
            : detail);
      }
    } catch (_) {
      return Exception('You do not have permission for this action.');
    }
    try {
      final error = jsonDecode(response.body);
      return Exception(error['detail']?.toString() ?? fallbackMsg);
    } catch (_) {
      return Exception(fallbackMsg);
    }
  }


  static Future<List<OrganizerMemberModel>> getAllMembers() async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/all');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => OrganizerMemberModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load organizer members');
    }
  }

  static Future<Map<String, dynamic>> createMember({
    required int accountId,
    required int eventOrganizerId,
    required int teamRoleId,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/create');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'AccountID': accountId,
        'EventOrganizerID': eventOrganizerId,
        'TeamRoleID': teamRoleId,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to create organizer member');
    }
  }

  static Future<Map<String, dynamic>> inviteMember({
    required String email,
    required int eventOrganizerId,
    required int teamRoleId,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/invite');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'Email': email,
        'EventOrganizerID': eventOrganizerId,
        'TeamRoleID': teamRoleId,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to send invitation');
    }
  }

  static Future<List<OrganizerMemberDetail>> getMembersWithAccounts() async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/all-with-accounts');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => OrganizerMemberDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load team members');
    }
  }

  static Future<OrganizerMemberDetail> getMemberDetail(int memberId) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/$memberId');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      return OrganizerMemberDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw _handleError(response, 'Failed to load invitation');
    }
  }

  static Future<List<OrganizerMemberDetail>> getMyInvites() async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/my-invites');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => OrganizerMemberDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load your invitations');
    }
  }

  static Future<void> acceptInvite(int memberId) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/$memberId/accept');
    final response = await http.post(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to accept invitation');
    }
  }

  static Future<void> declineInvite(int memberId) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/$memberId/decline');
    final response = await http.post(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to decline invitation');
    }
  }

  static Future<void> updateMember({
    required int memberId,
    required int accountId,
    required int eventOrganizerId,
    required int teamRoleId,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/update');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'MemberID': memberId,
        'AccountID': accountId,
        'EventOrganizerID': eventOrganizerId,
        'TeamRoleID': teamRoleId,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update organizer member');
    }
  }

  static Future<void> deleteMember(int memberId) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/$memberId');
    final response = await http.delete(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to delete organizer member');
    }
  }


  static Future<List<TeamRoleModel>> getAllTeamRoles() async {
    final url = Uri.parse('$baseUrl/teamrole/role/all');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => TeamRoleModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load team roles');
    }
  }


  static Future<List<TeamMembership>> getMyMemberships() async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/my-memberships');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => TeamMembership.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load your memberships');
    }
  }

  static Future<MyEventsResult> getMyMemberEvents({int? orgId}) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/member-events')
        .replace(queryParameters: {if (orgId != null) 'org_id': '$orgId'});
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      final orgJson = data['org'];
      if (orgJson == null) {
        throw Exception('You are not part of an organization team yet.');
      }
      final List<dynamic> events = data['events'] as List<dynamic>? ?? [];
      return MyEventsResult(
        org: TeamMembership.fromJson(orgJson as Map<String, dynamic>),
        events: events
            .map((e) => MemberEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } else {
      throw _handleError(response, 'Failed to load your events');
    }
  }

  static Future<List<OrgTeamMember>> getOrgTeam(int orgId) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/team/$orgId');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => OrgTeamMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load the team');
    }
  }

  static Future<Map<String, dynamic>> changeMemberRole({
    required int memberId,
    required int teamRoleId,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/change-role');
    final response = await http.put(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'MemberID': memberId,
        'TeamRoleID': teamRoleId,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response, 'Failed to change the team role');
    }
  }

  static Future<void> transferOwnership({
    required int eventOrganizerId,
    required int newOwnerMemberId,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/transfer-ownership');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventOrganizerID': eventOrganizerId,
        'NewOwnerMemberID': newOwnerMemberId,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to transfer ownership');
    }
  }

  static Future<void> assignMemberEvent({
    required int memberId,
    required int eventId,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/assign-event');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'MemberID': memberId,
        'EventID': eventId,
        'EventRoleID': 1,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to assign member to the event');
    }
  }

  static Future<void> unassignMemberEvent({
    required int memberId,
    required int eventId,
  }) async {
    final url = Uri.parse('$baseUrl/eventorganizer/member/unassign-event');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'MemberID': memberId,
        'EventID': eventId,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to unassign member from the event');
    }
  }

  static Future<List<EventAttendee>> getEventAttendees(int eventId) async {
    final url = Uri.parse('$baseUrl/ticketattendence/attendee/event/$eventId');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => EventAttendee.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw _handleError(response, 'Failed to load attendee list');
    }
  }

  static Future<ResolvedAttendee> resolveAttendeeForCheckIn({
    required int eventId,
    required int attendeeId,
  }) async {
    final url = Uri.parse(
        '$baseUrl/ticketattendence/attendee/event/$eventId/resolve/$attendeeId');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode == 200) {
      return ResolvedAttendee.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 404) {
      throw Exception('This ticket is not valid for this event.');
    }
    throw _handleError(response, 'Failed to read the ticket');
  }

  static Future<void> checkInAttendee({
    required int eventId,
    required int attendeeId,
  }) async {
    final url = Uri.parse('$baseUrl/ticketattendence/attendee/checkin');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventID': eventId,
        'AttendeeID': attendeeId,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to check in the attendee');
    }
  }

  static Future<void> cancelCheckIn({
    required int eventId,
    required int attendeeId,
  }) async {
    final url = Uri.parse('$baseUrl/ticketattendence/attendee/cancel-checkin');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventID': eventId,
        'AttendeeID': attendeeId,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to cancel the check-in');
    }
  }

  static Future<void> revokeTicket({
    required int eventId,
    required int attendeeId,
    required bool isValid,
  }) async {
    final url = Uri.parse('$baseUrl/ticketattendence/attendee/revoke-ticket');
    final response = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode({
        'EventID': eventId,
        'AttendeeID': attendeeId,
        'IsValid': isValid,
      }),
    );
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to update the ticket');
    }
  }

  static Future<EventAnalyticsData> getEventAnalytics(int eventId) async {
    final url = Uri.parse(
        '$baseUrl/ticketattendence/attendee/event/$eventId/analytics');
    final response = await http.get(url, headers: _authHeaders());
    if (response.statusCode != 200) {
      throw _handleError(response, 'Failed to load event analytics');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) f) =>
        (data[key] as List<dynamic>? ?? [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return EventAnalyticsData(
      attendees: parse('attendees', EventAttendee.fromJson),
      ticketTypes: parse('tickettypes', TicketTypeModel.fromJson),
      questions: parse('questions', EventQuestionModel.fromJson),
      responses: parse('responses', AttendeeResponseModel.fromJson),
    );
  }
}

class EventAnalyticsData {
  EventAnalyticsData({
    required this.attendees,
    required this.ticketTypes,
    required this.questions,
    required this.responses,
  });

  final List<EventAttendee> attendees;
  final List<TicketTypeModel> ticketTypes;
  final List<EventQuestionModel> questions;
  final List<AttendeeResponseModel> responses;
}
