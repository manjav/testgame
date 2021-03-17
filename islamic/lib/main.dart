import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:islamic/models.dart';
import 'package:islamic/utils.dart';
import 'package:islamic/waiting.dart';

import 'home.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  static int t;
  @override
  AppState createState() => AppState();
}

class AppState extends State<MyApp> {
  String locale;
  bool configured = false;
  WaitingPage waitingPage;

  @override
  void initState() {
    MyApp.t = DateTime.now().millisecondsSinceEpoch;
    super.initState();
    waitingPage = WaitingPage();
    Prefs.init(() {
      locale = Utils.getLocale();
      Configs.create(() {
        if (waitingPage.onLoop)
          waitingPage.finish(() {
            setState(() => configured = true);
          });
        else
          setState(() => configured = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // title: 'Title Example',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale("en", ""),
        const Locale("fa", ""),
      ],
      locale: Locale(locale, ""),
      // debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: configured ? HomePage() : waitingPage,
    );
  }
}
