import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../services/google_auth_service.dart';
import '../../../services/ytmusic_auth.dart';
import '../../../themes/text_styles.dart';
import '../../../utils/adaptive_widgets/adaptive_widgets.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: Text("Account", style: appBarTitleStyle()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(24),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: GetIt.I<GoogleAuthService>()),
              ChangeNotifierProvider.value(value: GetIt.I<YTMusicAuthService>()),
            ],
            child: Consumer<GoogleAuthService>(
              builder: (context, google, _) {
                return google.isSignedIn
                    ? const _SignedInView()
                    : const _SignedOutView();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SignedInView extends StatelessWidget {
  const _SignedInView();

  @override
  Widget build(BuildContext context) {
    final google = context.watch<GoogleAuthService>();
    final ytMusic = context.watch<YTMusicAuthService>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: google.photoUrl != null
              ? NetworkImage(google.photoUrl!)
              : null,
          child: google.photoUrl == null
              ? const Icon(Icons.person, size: 40)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          google.displayName ?? "Signed in",
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (google.email != null) ...[
          const SizedBox(height: 2),
          Text(
            google.email!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: Icon(
              ytMusic.isSignedIn
                  ? Icons.check_circle
                  : Icons.error_outline,
              color: ytMusic.isSignedIn
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
            ),
            title: const Text('YouTube Music'),
            subtitle: Text(
              ytMusic.isSignedIn
                  ? 'Home feed and library connected'
                  : 'Not connected — tap to connect',
            ),
            onTap: ytMusic.isSignedIn
                ? null
                : () => context.push('/settings/account/ytmusic-signin'),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await google.signOut();
            if (ytMusic.isSignedIn) await ytMusic.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text("Sign out"),
        ),
      ],
    );
  }
}

class _SignedOutView extends StatefulWidget {
  const _SignedOutView();

  @override
  State<_SignedOutView> createState() => _SignedOutViewState();
}

class _SignedOutViewState extends State<_SignedOutView> {
  String? _error;

  Future<void> _signIn() async {
    setState(() => _error = null);
    final google = GetIt.I<GoogleAuthService>();
    final error = await google.signIn();

    if (!mounted) return;

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    // Google Sign-In only gives us profile identity — it can't reach YT
    // Music's internal API. Follow it straight up with the existing
    // cookie-based YT Music connection so the account actually works,
    // feeling like one continuous "sign in" from the user's side.
    final ytMusic = GetIt.I<YTMusicAuthService>();
    if (!ytMusic.isSignedIn && mounted) {
      context.push('/settings/account/ytmusic-signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final google = context.watch<GoogleAuthService>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.account_circle_outlined, size: 56),
        const SizedBox(height: 12),
        Text(
          "Not signed in",
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Sign in with Google to sync your YouTube Music home feed and library.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: google.isSigningIn ? null : _signIn,
          icon: google.isSigningIn
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: Text(
            google.isSigningIn ? "Waiting for browser…" : "Sign in with Google",
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
