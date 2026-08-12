import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
          child: ChangeNotifierProvider.value(
            value: GetIt.I<YTMusicAuthService>(),
            child: Consumer<YTMusicAuthService>(
              builder: (context, auth, _) {
                return auth.isSignedIn
                    ? _SignedInView(auth: auth)
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
  final YTMusicAuthService auth;
  const _SignedInView({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
        const SizedBox(height: 16),
        Text(
          "Signed in with Google",
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          "Your YouTube Music library and home feed are connected.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async => await auth.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text("Sign out"),
        ),
      ],
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => context.push('/settings/account/ytmusic-signin'),
          icon: const Icon(Icons.login),
          label: const Text("Sign in with Google"),
        ),
      ],
    );
  }
}
