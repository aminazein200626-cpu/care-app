class Dependent {
  final String id;
  final String fullName;
  final String relationship;
  final DateTime? dateOfBirth;
  final String? nationalId;
  final String? healthNotes;
  final String? specialNotes;
  
  Dependent({
    required this.id,
    required this.fullName,
    required this.relationship,
    this.dateOfBirth,
    this.nationalId,
    this.healthNotes,
    this.specialNotes,
  });
  
  factory Dependent.fromJson(Map<String, dynamic> json) {
    return Dependent(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      relationship: json['relationship'] ?? '',
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.parse(json['dateOfBirth']) : null,
      nationalId: json['nationalId'],
      healthNotes: json['healthNotes'],
      specialNotes: json['specialNotes'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'relationship': relationship,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'nationalId': nationalId,
      'healthNotes': healthNotes,
      'specialNotes': specialNotes,
    };
  }
  
  int get age {
    if (dateOfBirth == null) return 0;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
}