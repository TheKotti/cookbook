import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'src/images/image_store.dart';
import 'src/providers.dart';
import 'src/share/share_intent_handler.dart';
import 'src/ui/import_screen.dart';
import 'src/ui/recipe_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final documentsDir = await getApplicationDocumentsDirectory();
  runApp(ProviderScope(
    overrides: [imageStoreProvider.overrideWithValue(ImageStore(documentsDir))],
    child: const CookbookApp(),
  ));
}

class CookbookApp extends StatefulWidget {
  const CookbookApp({super.key});

  @override
  State<CookbookApp> createState() => _CookbookAppState();
}

class _CookbookAppState extends State<CookbookApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    ShareIntentHandler.listen(_openImport);
    ShareIntentHandler.getInitialSharedText().then((text) {
      if (text != null) _openImport(text);
    });
  }

  void _openImport(String sharedText) {
    _navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => ImportScreen(initialSharedText: sharedText)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cookbook',
      navigatorKey: _navigatorKey,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const RecipeListScreen(),
    );
  }
}
