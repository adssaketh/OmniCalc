import 'package:url_launcher/url_launcher.dart';

/// Opens a web address outside the app (the `<a href target="_blank">` rows of Settings > About and the privacy sheet).
abstract class LinkService {
  Future<void> open(String url);
}

/// Hands the address to the system browser; the app stays open, as it does for the web app's links.
class PlatformLinkService implements LinkService {
  const PlatformLinkService();

  @override
  Future<void> open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // no browser available: nothing happens, as for a link that cannot be opened
    }
  }
}

/// Records the addresses instead of opening them. For tests and previews.
class RecordingLinkService implements LinkService {
  final List<String> opened = <String>[];

  @override
  Future<void> open(String url) async => opened.add(url);
}
