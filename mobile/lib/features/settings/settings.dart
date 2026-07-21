class Settings {
  Settings({
    required this.fcMax,
    required this.pr5kSec,
    required this.pr10kSec,
    required this.prSemiSec,
    required this.prMarathonSec,
  });

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      fcMax: json['fc_max'] as int?,
      pr5kSec: json['pr_5k_sec'] as int?,
      pr10kSec: json['pr_10k_sec'] as int?,
      prSemiSec: json['pr_semi_sec'] as int?,
      prMarathonSec: json['pr_marathon_sec'] as int?,
    );
  }

  final int? fcMax;
  final int? pr5kSec;
  final int? pr10kSec;
  final int? prSemiSec;
  final int? prMarathonSec;

  Map<String, dynamic> toJson() => {
        'fc_max': fcMax,
        'pr_5k_sec': pr5kSec,
        'pr_10k_sec': pr10kSec,
        'pr_semi_sec': prSemiSec,
        'pr_marathon_sec': prMarathonSec,
      };
}
