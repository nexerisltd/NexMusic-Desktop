import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../services/ytmusic_auth.dart';
import '../../../themes/text_styles.dart';
import '../../../utils/adaptive_widgets/adaptive_widgets.dart';

class YTMusicSignInPage extends StatefulWidget {
  const YTMusicSignInPage({super.key});

  @override
  State<YTMusicSignInPage> createState() => _YTMusicSignInPageState();
}

class _YTMusicSignInPageState extends State<YTMusicSignInPage> {
  InAppWebViewController? _controller;
  WebViewEnvironment? _webViewEnvironment;
  bool _envReady = false;
  bool _capturing = false;
  String _statusText =
      "Sign in to your Google account below, then press \"I've signed in\".";

  @override
  void initState() {
    super.initState();
    createWritableWebViewEnvironment().then((env) {
      if (!mounted) return;
      setState(() {
        _webViewEnvironment = env;
        _envReady = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: Text("Sign in to YouTube Music", style: appBarTitleStyle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(
              children: [
                if (_capturing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_capturing) const SizedBox(width: 12),
                Expanded(child: Text(_statusText)),
                FilledButton(
                  onPressed: _capturing ? null : _onDoneTapped,
                  child: const Text("I've signed in"),
                ),
              ],
            ),
          ),
          Expanded(
            child: !_envReady
                ? const Center(child: CircularProgressIndicator())
                : InAppWebView(
              webViewEnvironment: _webViewEnvironment,
              initialUrlRequest: URLRequest(
                url: WebUri('https://music.youtube.com'),
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDoneTapped() async {
    setState(() {
      _capturing = true;
      _statusText = "Checking your session...";
    });

    final auth = GetIt.I<YTMusicAuthService>();
    final success = await auth.captureSessionFromWebview();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signed in to YouTube Music!")),
      );
      context.pop();
    } else {
      setState(() {
        _capturing = false;
        _statusText =
            "Couldn't find a signed-in session yet. Make sure you're fully "
            "signed in above, then try again.";
      });
    }
  }
}
