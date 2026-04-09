import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';

/// One stage descriptor, unlocked after [unlockDate]
class _StageInfo {
  final int number;
  final String title;
  final String description;
  final IconData icon;
  final DateTime unlockDate;
  final DateTime? completedAt;
  final String? photoIpfsCid;

  bool get isCompleted => completedAt != null;
  bool get isUnlocked => DateTime.now().isAfter(unlockDate);

  const _StageInfo({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlockDate,
    this.completedAt,
    this.photoIpfsCid,
  });
}

class CropTimelineScreen extends StatefulWidget {
  final Map<String, dynamic> batch;
  const CropTimelineScreen({super.key, required this.batch});

  @override
  State<CropTimelineScreen> createState() => _CropTimelineScreenState();
}

class _CropTimelineScreenState extends State<CropTimelineScreen>
    with TickerProviderStateMixin {
  static const int _totalDays = 240;
  static const int _totalStages = 5;
  static const int _daysPerStage = _totalDays ~/ _totalStages; // 48 days

  bool _uploading = false;
  int? _uploadingStage;

  late List<_StageInfo> _stages;
  late AnimationController _pulseCtrl;

  static const _stageMeta = [
    ('Seed Planting', 'Capture your planting site and seed placement', Icons.grass_rounded),
    ('Sprouting', 'Document early growth and sprout health', Icons.eco_rounded),
    ('Vegetative Growth', 'Show full leaf development stage', Icons.park_rounded),
    ('Flowering / Fruiting', 'Capture blossoming or fruit formation', Icons.local_florist_rounded),
    ('Harvest Ready', 'Final stage — crop ready for collection', Icons.agriculture_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _buildStages();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  DateTime _createdAt() {
    try {
      return DateTime.parse(widget.batch['createdAt']);
    } catch (_) {
      return DateTime.now().subtract(const Duration(days: 5));
    }
  }

  DateTime? _completedAt(int stageNum) {
    final stages = widget.batch['stages'] as List? ?? [];
    for (final s in stages) {
      if ((s['stageNumber'] as int?) == stageNum && s['completedAt'] != null) {
        try {
          return DateTime.parse(s['completedAt']);
        } catch (_) {}
      }
    }
    return null;
  }

  String? _photoCid(int stageNum) {
    final stages = widget.batch['stages'] as List? ?? [];
    for (final s in stages) {
      if ((s['stageNumber'] as int?) == stageNum) {
        return s['photoIpfsCid'] as String?;
      }
    }
    return null;
  }

  void _buildStages() {
    final created = _createdAt();
    _stages = List.generate(_totalStages, (i) {
      final stageNum = i + 1;
      // Stage 1 is always unlocked immediately (batch was created)
      final unlock = stageNum == 1
          ? created
          : created.add(Duration(days: _daysPerStage * i));
      return _StageInfo(
        number: stageNum,
        title: _stageMeta[i].$1,
        description: _stageMeta[i].$2,
        icon: _stageMeta[i].$3,
        unlockDate: unlock,
        completedAt: _completedAt(stageNum),
        photoIpfsCid: _photoCid(stageNum),
      );
    });
  }

  double _overallProgress() {
    final completed = _stages.where((s) => s.isCompleted).length;
    return completed / _totalStages;
  }

  String _daysUntilUnlock(_StageInfo s) {
    final diff = s.unlockDate.difference(DateTime.now()).inDays;
    if (diff <= 0) return '';
    return 'Unlocks in $diff day${diff == 1 ? '' : 's'}';
  }

  Future<void> _captureAndUpload(_StageInfo stage) async {
    // 1. Request camera
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xfile == null) return;

    // 2. Get GPS
    late Position pos;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      pos = Position(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    setState(() {
      _uploading = true;
      _uploadingStage = stage.number;
    });

    try {
      // 3. POST multipart to backend
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');

      final formData = FormData.fromMap({
        'lat': pos.latitude.toString(),
        'lng': pos.longitude.toString(),
        'photo': await MultipartFile.fromFile(
          xfile.path,
          filename: 'stage${stage.number}.jpg',
        ),
      });

      final dio = Dio();
      await dio.post(
        ApiConfig.completeStageUrl(
          widget.batch['batchId'] as String,
          stage.number,
        ),
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (mounted) {
        // Rebuild stage list with the newly completed stage
        final stages = (widget.batch['stages'] as List?) ?? [];
        final idx = stages.indexWhere((s) => s['stageNumber'] == stage.number);
        final now = DateTime.now().toIso8601String();
        if (idx > -1) {
          stages[idx]['completedAt'] = now;
        } else {
          stages.add({
            'stageNumber': stage.number,
            'completedAt': now,
            'photoIpfsCid': 'uploading...',
          });
        }
        widget.batch['stages'] = stages;
        _buildStages();
        setState(() {
          _uploading = false;
          _uploadingStage = null;
        });
        _showSuccess('Stage ${stage.number} recorded successfully!');
      }
    } catch (e) {
      setState(() {
        _uploading = false;
        _uploadingStage = null;
      });
      if (mounted) {
        _showError('Upload failed. Please try again.');
      }
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Text(msg),
        ]),
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchId = widget.batch['batchId'] ?? '—';
    final species = widget.batch['speciesName'] ?? 'Crop';
    final progress = _overallProgress();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              species,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
            Text(
              batchId,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Progress Header ──────────────────────────
            _ProgressHeader(
              species: species,
              progress: progress,
              completedStages: _stages.where((s) => s.isCompleted).length,
              totalStages: _totalStages,
              daysPerStage: _daysPerStage,
            ),
            const SizedBox(height: 28),

            // ── Stage Timeline ───────────────────────────
            Text(
              'Growth Timeline',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a stage to upload your progress photo',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Timeline stages
            ...List.generate(_stages.length, (i) {
              final s = _stages[i];
              final isLast = i == _stages.length - 1;
              return _StageCard(
                stage: s,
                isLast: isLast,
                isUploading: _uploading && _uploadingStage == s.number,
                pulseCtrl: _pulseCtrl,
                daysUntil: _daysUntilUnlock(s),
                onTap: s.isUnlocked && !s.isCompleted && !_uploading
                    ? () => _captureAndUpload(s)
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Progress Header Widget ───────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final String species;
  final double progress;
  final int completedStages;
  final int totalStages;
  final int daysPerStage;

  const _ProgressHeader({
    required this.species,
    required this.progress,
    required this.completedStages,
    required this.totalStages,
    required this.daysPerStage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                '$completedStages / $totalStages Stages Done',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  color: Colors.white.withValues(alpha: 0.8), size: 15),
              const SizedBox(width: 5),
              Text(
                'New stage unlocks every $daysPerStage days',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stage Card Widget ────────────────────────────────────────────────────────

class _StageCard extends StatelessWidget {
  final _StageInfo stage;
  final bool isLast;
  final bool isUploading;
  final AnimationController pulseCtrl;
  final String daysUntil;
  final VoidCallback? onTap;

  const _StageCard({
    required this.stage,
    required this.isLast,
    required this.isUploading,
    required this.pulseCtrl,
    required this.daysUntil,
    required this.onTap,
  });

  Color _nodeColor() {
    if (stage.isCompleted) return AppColors.success;
    if (stage.isUnlocked) return AppColors.primary;
    return AppColors.textSecondary.withValues(alpha: 0.4);
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: connector + node ──
          SizedBox(
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: pulseCtrl,
                  builder: (_, __) {
                    final scale = stage.isUnlocked && !stage.isCompleted
                        ? 1.0 + pulseCtrl.value * 0.12
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _nodeColor(),
                          shape: BoxShape.circle,
                          boxShadow: stage.isUnlocked && !stage.isCompleted
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                        child: Icon(
                          stage.isCompleted
                              ? Icons.check_rounded
                              : stage.icon,
                          color: Colors.white,
                          size: stage.isCompleted ? 22 : 20,
                        ),
                      ),
                    );
                  },
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _nodeColor(),
                            stage.isCompleted
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.surface,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── Right: card ──
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: stage.isCompleted
                        ? AppColors.success.withValues(alpha: 0.3)
                        : stage.isUnlocked
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.surface,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _nodeColor().withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Stage ${stage.number}',
                            style: TextStyle(
                              color: _nodeColor(),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (stage.isCompleted)
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  color: AppColors.success, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Completed',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        else if (!stage.isUnlocked)
                          Row(
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  color: AppColors.textSecondary, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Locked',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.camera_alt_rounded,
                                    color: AppColors.primary, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  'Tap to upload',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stage.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.description,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    if (daysUntil.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.hourglass_empty_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            daysUntil,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (stage.isCompleted && stage.completedAt != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(stage.completedAt!),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (stage.photoIpfsCid != null &&
                              stage.photoIpfsCid!.isNotEmpty &&
                              stage.photoIpfsCid != 'uploading...') ...[
                            const Spacer(),
                            Icon(Icons.cloud_done_rounded,
                                size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(
                              'IPFS',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ],
                    if (isUploading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 4),
                      Text(
                        'Uploading to IPFS...',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
