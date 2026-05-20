                    class User {
                      final String id;
                      final String fullName;
                      final String email;
                      final String phoneNumber;
                      final String role;
                      final String? profilePicture;
                      
                      const User({
                        required this.id,
                        required this.fullName,
                        required this.email,
                        required this.phoneNumber,
                        required this.role,
                        this.profilePicture,
                      });
                      
                      factory User.fromJson(Map<String, dynamic> json) {
                        return User(
                          id: json['_id']?.toString() ?? json['userId']?.toString() ?? '',
                          fullName: json['fullName']?.toString() ?? json['name']?.toString() ?? '',
                          email: json['email']?.toString() ?? '',
                          phoneNumber: json['phoneNumber']?.toString() ?? '',
                          role: json['role']?.toString() ?? 'Client',
                          profilePicture: json['profilePicture']?.toString(),
                        );
                      }
                      
                      Map<String, dynamic> toJson() {
                        return {
                          'fullName': fullName,
                          'email': email,
                          'phoneNumber': phoneNumber,
                          'role': role,
                          'profilePicture': profilePicture,
                        };
                      }
                    }