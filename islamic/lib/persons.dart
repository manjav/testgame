import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:islamic/models.dart';
import 'package:simple_speed_dial/simple_speed_dial.dart';

class PersonPage extends StatefulWidget {
  String title = "";
  @override
  PersonPageState createState() => PersonPageState();
}

class PersonPageState extends State<PersonPage>
    with SingleTickerProviderStateMixin {
  AnimationController fabAnimController;

  List<String> items;

  @override
  void initState() {
    super.initState();
    // widget.title = AppLocalizations.of(context).fab_tafsir;
    fabAnimController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 450));
    items = <String>[];
    items.addAll(Prefs.reciters);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: Icon(Icons.arrow_forward),
                onPressed: () => Navigator.pop(context),
              )
            ],
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: Text(AppLocalizations.of(context).translation_title),
          ),
          body: ReorderableListView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              children: <Widget>[
                for (int index = 0; index < items.length; index++)
                  ListTile(
                    key: Key('$index'),
                    // tileColor: items[index].isOdd ? oddItemColor : evenItemColor,
                    title: Text('Item ${items[index]}'),
                  ),
              ],
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = items.removeAt(oldIndex);
                  items.insert(newIndex, item);
                  Prefs.reciters = items;
                });
              }),
          floatingActionButton: SpeedDial(
            child: AnimatedIcon(
              icon: AnimatedIcons.add_event,
              progress: fabAnimController,
            ),
            openBackgroundColor: Colors.redAccent,
            closedBackgroundColor: Colors.redAccent,
            // closedForegroundColor: Colors.black,
            // labelsStyle: /* Your label TextStyle goes here */,
            // controller: /* Your custom animation controller goes here */,
            onPressed: handleOnPressed,
            speedDialChildren: <SpeedDialChild>[
              SpeedDialChild(
                child: Icon(
                  Icons.arrow_back,
                ),
                foregroundColor: Colors.black,
                // backgroundColor: Colors.red,
                label: AppLocalizations.of(context).fab_quran,
                onPressed: () => speedChildPressed(0),
              ),
              SpeedDialChild(
                child: Icon(Icons.arrow_back),
                foregroundColor: Colors.black,
                // backgroundColor: Colors.yellow,
                label: AppLocalizations.of(context).fab_translate,
                onPressed: () => speedChildPressed(1),
              ),
              SpeedDialChild(
                child: Icon(Icons.arrow_back),
                foregroundColor: Colors.black,
                // backgroundColor: Colors.green,
                label: AppLocalizations.of(context).fab_tafsir,
                onPressed: () => speedChildPressed(2),
              ),
              //  Your other SpeeDialChildren go here.
            ],
          ),
        ));
  }

  void handleOnPressed(bool isOpen) {
    setState(() {
      isOpen ? fabAnimController.forward() : fabAnimController.reverse();
    });
  }

  void speedChildPressed(int i) {}
}
