import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  static const privacyAsset = 'assets/legal/privacy_policy.txt';
  static const termsAsset = 'assets/legal/terms_of_use.txt';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load document.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              snapshot.data ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          );
        },
      ),
    );
  }
}
