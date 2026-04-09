import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/farmer_service.dart';

class DashboardState {
  final bool isLoading;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> statusDistribution;
  final Map<String, dynamic> speciesDistribution;
  final Map<String, dynamic>? weatherNews;
  final String? errorMessage;

  const DashboardState({
    this.isLoading = true,
    this.summary = const {},
    this.statusDistribution = const {},
    this.speciesDistribution = const {},
    this.weatherNews,
    this.errorMessage,
  });

  DashboardState copyWith({
    bool? isLoading,
    Map<String, dynamic>? summary,
    Map<String, dynamic>? statusDistribution,
    Map<String, dynamic>? speciesDistribution,
    Map<String, dynamic>? weatherNews,
    String? errorMessage,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      statusDistribution: statusDistribution ?? this.statusDistribution,
      speciesDistribution: speciesDistribution ?? this.speciesDistribution,
      weatherNews: weatherNews ?? this.weatherNews,
      errorMessage: errorMessage ?? this.errorMessage, // fix error message copy
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final FarmerService _farmerService = FarmerService();

  DashboardNotifier() : super(const DashboardState());

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      double? lat;
      double? lon;

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 4),
            );
            lat = position.latitude;
            lon = position.longitude;
          }
        }
      } catch (locErr) {
        // Silently gracefully fallback to profile string if location fails
      }

      final data = await _farmerService.getDashboard(lat: lat, lon: lon);
      state = state.copyWith(
        isLoading: false,
        summary: Map<String, dynamic>.from(data['summary'] ?? {}),
        statusDistribution:
            Map<String, dynamic>.from(data['statusDistribution'] ?? {}),
        speciesDistribution:
            Map<String, dynamic>.from(data['speciesDistribution'] ?? {}),
        weatherNews: data['weatherNews'] != null ? Map<String, dynamic>.from(data['weatherNews']) : null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dashboard',
      );
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});
