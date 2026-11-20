// Owner: WS3.
import 'package:url_launcher/url_launcher.dart';

import '../data/models/models.dart';
import 'api.dart';

/// [LauncherService] on url_launcher (external application, SPEC 4.6).
class UrlLauncherService implements LauncherService {
  const UrlLauncherService();

  /// The pinned video, else a YouTube search for "`<name>` proper form".
  static Uri videoUri(Exercise ex) {
    final pinned = ex.video?.url;
    if (pinned != null) return Uri.parse(pinned);
    return Uri.https('www.youtube.com', '/results', {'search_query': '${ex.name} proper form'});
  }

  @override
  Future<bool> openVideo(Exercise ex) async {
    try {
      return await launchUrl(videoUri(ex), mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> call(String number) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
    } on Exception {
      return false;
    }
  }
}
