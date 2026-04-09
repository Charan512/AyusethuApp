class FarmerProfile {
  final String farmSize;
  final String location;
  final String soilType;
  final String irrigationType;
  final List<String> crops;

  FarmerProfile({
    this.farmSize = '',
    this.location = '',
    this.soilType = '',
    this.irrigationType = '',
    this.crops = const [],
  });

  factory FarmerProfile.fromJson(Map<String, dynamic> json) {
    return FarmerProfile(
      farmSize: json['farmSize'] ?? '',
      location: json['location'] ?? '',
      soilType: json['soilType'] ?? '',
      irrigationType: json['irrigationType'] ?? '',
      crops: json['crops'] != null
          ? List<String>.from(json['crops'])
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'farmSize': farmSize,
        'location': location,
        'soilType': soilType,
        'irrigationType': irrigationType,
        'crops': crops,
      };
}

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role;
  final String preferredLanguage;
  final FarmerProfile? farmerProfile;
  final bool isOnboardingComplete;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.preferredLanguage = 'en',
    this.farmerProfile,
    this.isOnboardingComplete = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'FARMER',
      preferredLanguage: json['preferredLanguage'] ?? 'en',
      farmerProfile: json['farmerProfile'] != null
          ? FarmerProfile.fromJson(json['farmerProfile'])
          : null,
      isOnboardingComplete: json['isOnboardingComplete'] ?? false,
    );
  }

  UserModel copyWith({
    String? phone,
    String? email,
    FarmerProfile? farmerProfile,
  }) {
    return UserModel(
      id: id,
      name: name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role,
      preferredLanguage: preferredLanguage,
      farmerProfile: farmerProfile ?? this.farmerProfile,
      isOnboardingComplete: isOnboardingComplete,
    );
  }
}
