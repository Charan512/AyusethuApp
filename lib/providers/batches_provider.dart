import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/farmer_service.dart';

class BatchesState {
  final bool isLoading;
  final List<Map<String, dynamic>> batches;
  final String? error;

  const BatchesState({
    this.isLoading = false,
    this.batches = const [],
    this.error,
  });

  BatchesState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? batches,
    String? error,
  }) =>
      BatchesState(
        isLoading: isLoading ?? this.isLoading,
        batches: batches ?? this.batches,
        error: error,
      );
}

class BatchesNotifier extends StateNotifier<BatchesState> {
  final FarmerService _service = FarmerService();

  BatchesNotifier() : super(const BatchesState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final batches = await _service.getMyBatches();
      state = state.copyWith(isLoading: false, batches: batches);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final batchesProvider =
    StateNotifierProvider<BatchesNotifier, BatchesState>((ref) {
  return BatchesNotifier();
});
