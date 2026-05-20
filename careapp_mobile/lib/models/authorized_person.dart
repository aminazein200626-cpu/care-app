// lib/models/authorized_person.dart
class AuthorizedPerson {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String relationship;
  final bool canTrack;
  final bool canChat;
  final bool canViewLocation;
  final DateTime? invitedAt;

  AuthorizedPerson({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.relationship,
    this.canTrack = true,
    this.canChat = true,
    this.canViewLocation = true,
    this.invitedAt,
  });

  factory AuthorizedPerson.fromJson(Map<String, dynamic> json) {
    return AuthorizedPerson(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      relationship: json['relationship'] ?? '',
      canTrack: json['canTrack'] ?? true,
      canChat: json['canChat'] ?? true,
      canViewLocation: json['canViewLocation'] ?? true,
      invitedAt: json['invitedAt'] != null ? DateTime.parse(json['invitedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'canTrack': canTrack,
      'canChat': canChat,
      'canViewLocation': canViewLocation,
    };
  }
}