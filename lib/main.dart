import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:collection/collection.dart' show lowerBound;
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:fortuity/CustomDieButton.dart';
import 'package:fortuity/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      theme: new ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
        accentColor: Colors.green,
        toggleableActiveColor: Colors.green,
        iconTheme: new IconThemeData(
          color: Colors.grey.shade50,
        ),
      ),
      home: new MyHomePage(),
    );
  }
}

enum PageType {
  roller, customRoller, settings, history, favorites
}

class _Page {
  _Page(this.type, { this.label });

  final PageType type;
  final String label;
}

final List<_Page> _allPages = <_Page>[
  new _Page(PageType.roller, label: 'Standard Roller'),
  new _Page(PageType.customRoller, label: 'Custom Roller'),
  new _Page(PageType.settings, label: 'Settings'),
];

final List<_Page> _histories = <_Page>[
  new _Page(PageType.history, label: "Roll History"),
  new _Page(PageType.favorites, label: "Favorites"),
];

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  static final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  TabController _controller;
  TabController _listsController;
  _Page _selectedPage;

  ScrollController _settingScrollController = ScrollController();

  TextStyle diceStyle = new TextStyle(color: Colors.grey.shade50);
  TextStyle otherStyle = new TextStyle(color: Colors.grey.shade50, fontSize: 28.0);
  List<String> _diceVals = ["4", "6", "8", "10", "12", "20", "%"];
  List<Image> _diceImages = new List<Image>();
  int rollerSum = 0;
  bool modifierNegative = false;

  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  bool onlyShowCount = false;
  bool individualDice = false;

  List<DiceHistoryModel> diceHistory = new List<DiceHistoryModel>();
  List<FavoriteModel> favorites = new List<FavoriteModel>();

  List<_DiceHistoryItemState> diceHistoryListItemState = new List<_DiceHistoryItemState>();

  int minIndex = 0;

  final TextEditingController _modifierInputController = new TextEditingController();

  int getAvailableIndex() {
    int returnable = minIndex;
    minIndex++;
    return returnable;
  }

  DiceHistoryModel prevHistory;
  int historyTotal;

  FavoriteModel activeFavorite;
  int favoriteTotal;

  List<Image> d20Images = new List<Image>();
  List<AnimationController> diceAnimControllers = new List<AnimationController>();
  List<Animation<int>> frameAnimations = new List<Animation<int>>();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _diceHistoryFile async {
    final path = await _localPath;
    try {
      return File('$path/diceHistory.json');
    } catch (e) {
      print(e);
    }
    return null;
  }

  Future<File> get _favoritesFile async {
    final path = await _localPath;
    try {
      return File('$path/favorites.json');
    } catch (e) {
      print(e);
    }
    return null;
  }

  Future<File> writeHistory() async {
    final file = await _diceHistoryFile;

    String _diceList = json.encode(diceHistory);

//    print(_diceList);

    return file.writeAsString(_diceList);
  }

  Future<File> writeFavorites() async {
    final file = await _favoritesFile;

    String _favoritesList = json.encode(favorites);

//    print(_favoritesList);

    return file.writeAsString(_favoritesList);
  }

  Future<List<FavoriteModel>> readFavorites() async {
    try {
      final file = await _favoritesFile;

      // Read the file
      String contents = await file.readAsString();

      print("Contents: $contents");

      List<dynamic> favoritesDecoded = json.decode(contents);

      List<FavoriteModel> favoritesDecodedList = new List<FavoriteModel>();

      Iterator i = favoritesDecoded.iterator;
      while (i.moveNext()) {
        favoritesDecodedList.add(FavoriteModel.fromJson(i.current));
      }

      return favoritesDecodedList;
    } catch (e) {
      print(e);
      return new List<FavoriteModel>();
    }
  }

  Future<List<DiceHistoryModel>> readDiceHistory() async {
    try {
      final file = await _diceHistoryFile;

      // Read the file
      String contents = await file.readAsString();

      //print("Contents: $contents");

      List<dynamic> diceHistoryDecoded = json.decode(contents);

      List<DiceHistoryModel> diceHistoryDecodedList = new List<DiceHistoryModel>();

      int curI = 0;

      Iterator i = diceHistoryDecoded.iterator;
      while (i.moveNext()) {
        diceHistoryDecodedList.add(DiceHistoryModel.fromJson(i.current, curI, showIndividual: individualDice));
        curI++;
      }

      return diceHistoryDecodedList;
    } catch (e) {
      print(e);
      return new List<DiceHistoryModel>();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = new TabController(length: _allPages.length, vsync: this);
    _controller.addListener(_handleTabSelection);
    _selectedPage = _allPages[0];

    _listsController = new TabController(length: _histories.length, vsync: this);
    _listsController.addListener(_handleTabSelection);

    readDiceHistory().then((val) {
      setState(() {
        diceHistory = val;
      });
      updateDHIndices();
    });

    readFavorites().then((val) {
      setState(() {
        favorites = val;
      });
      updateFIndices();
    });

    for(int i = 0; i < _diceVals.length; i++) {
      String _name = _diceVals[i];
      if (i >= 5) {
        _name = _diceVals[5];
      }
      Image image = new Image(image: new AssetImage("assets/d$_name.png"));
      _diceImages.add(image);
    }


    for(int i = 0; i < 7; i++) {
      AnimationController diceAnimController = AnimationController(
          duration: const Duration(milliseconds: 500),
          vsync: this);
      Animation frameAnimation = IntTween(begin: 0, end: 11).animate(diceAnimController)
        ..addListener(() {
          setState(() {});
        });

      diceAnimControllers.add(diceAnimController);
      frameAnimations.add(frameAnimation);
    }

    _prefs.then((SharedPreferences prefs) {
      onlyShowCount = prefs.getBool('onlyShowCount') ?? false;
      individualDice = prefs.getBool('individualDice') ?? false;
    });

    _modifierInputController.addListener(_onModifierChanged);
  }


  @override
  void dispose() {
    _controller.dispose();
    _listsController.dispose();
    _modifierInputController.removeListener(_onModifierChanged);
    _modifierInputController.dispose();
    diceAnimControllers.forEach((controller) { controller.dispose(); });
    super.dispose();
  }

  void _handleTabSelection() {
    setState(() {
      _selectedPage = _allPages[_controller.index];
    });
  }

  Container getButtonContainer() {
    return new Container(
      width: 60.0,
      height: 60.0,
    );
  }

  void updateDHIndices() {
    for(int i = 0; i < diceHistory.length; i++) {
      diceHistory[i].index = i;
    }
  }

  void updateFIndices() {
    for(int i = 0; i < favorites.length; i++) {
      favorites[i].index = i;
    }
  }

  void handleDiceClicked(int numSides) {
    if(diceHistory.isEmpty || prevHistory == null) {
      addHistory(addRoll(numSides));
      prevHistory = diceHistory.first;
    } else {
      addRoll(numSides, modelOpt: diceHistory.first);
    }
  }

  void handleDiceLongPress(int numSides) {
    addHistory(addRoll(numSides));
    finalizeRoll();
  }

  void handleReroll(int index) {
    DiceHistoryModel model = diceHistory[index];
    DiceHistoryModel newRoll = new DiceHistoryModel(name: model.name, color: model.color,
        highlighting: model.highlighting, dice: new Map<String, List<int>>(), showIndividual: individualDice);

    if(model.favoriteOrigin != null) {
      newRoll.favoriteOrigin = model.favoriteOrigin;
    }

    model.dice.keys.forEach((key) {
      if(key == "1") {
        model.dice[key].forEach((modVal) {
          newRoll = addRoll(int.parse(key), modelOpt: newRoll, randRoll: modVal);
        });
      } else {
        for(int i = model.dice[key].length; i > 0; i--) {
          newRoll = addRoll(int.parse(key), modelOpt: newRoll);
        }
      }
    });

    if(model.favoriteOrigin != null) {
      applyRules(newRoll, model.favoriteOrigin);
    }

    addHistory(newRoll);
    finalizeRoll();
  }

  DiceHistoryModel addRoll(int numSides, {DiceHistoryModel modelOpt, int randRoll}) {
    int randRes = randRoll != null ? randRoll : getRandomRoll(numSides);

//    print("Random roll was: $randRes");

    DiceHistoryModel model;

    if(modelOpt != null) { model = modelOpt; }
    else { model = new DiceHistoryModel(dice: new Map<String, List<int>>(), showIndividual: individualDice ); }

    List<int> rolls;

    if(model.dice.containsKey(numSides.toString())) {
      rolls = model.dice[numSides.toString()];
    } else {
      rolls = new List<int>();
      model.dice.addAll({numSides.toString(): rolls});
    }

    setState(() {
      rolls.add(randRes);
    });

    return model;
  }

  void setModifier(int value) {
    if(value == 0) {
      return removeModifier();
    }

    if(prevHistory != null) {
      setState(() {
        prevHistory.dice["1"] = [value];
      });
    } else {
      prevHistory = addRoll(1, modelOpt: prevHistory, randRoll: value);
    }
  }

  void removeModifier() {
    if(prevHistory != null) {
      if(prevHistory.dice.containsKey("1")) {
        setState(() {
          prevHistory.dice.remove("1");
        });
      }
    }
  }

  void _onModifierChanged() {
    if(_modifierInputController.text.isNotEmpty) {
      int modUnsigned = int.parse(_modifierInputController.text);
      if(modifierNegative) {
        modUnsigned *= -1;
      }
      setModifier(modUnsigned);
    } else {
      setModifier(0);
    }
  }

  void toggleModifierSign() {
    setState(() {
      modifierNegative = !modifierNegative;
    });
    _onModifierChanged();
  }

  int getRandomRoll(int numSides) {
    return Random(Random().nextInt(1000000000)).nextInt(numSides) + 1;
  }

  void addHistory(DiceHistoryModel model) {
    setState(() {
      diceHistory.insert(0, model);
    });

    updateDHIndices();

    writeHistory();
  }
  
  void removeHistory(int index) {
//    print("removeHistory: " + index.toString());
    DiceHistoryModel historyModel = diceHistory[index];
    setState(() {
      diceHistory.removeAt(index);
    });

    updateDHIndices();

    writeHistory();

    _scaffoldKey.currentState.hideCurrentSnackBar();

    _scaffoldKey.currentState.showSnackBar(new SnackBar(
        content: new Text('You deleted item ${historyModel.index}'),
        action: new SnackBarAction(
          label: 'UNDO',
          onPressed: () { handleUndo(historyModel); }
      )
    ));
  }

  void handleUndo(DiceHistoryModel item) {
//    print("Undoing item ${item.getDiceToString()} with index ${item.index}");
//    print("checking all histories");
//    diceHistory.forEach(((element) {
//      print("history:  ${element.index}");
//    }));
    final int insertionIndex = lowerBound(diceHistory, item);
    setState(() {
      diceHistory.insert(insertionIndex, item);
    });

    writeHistory();
  }

  void handleFavoriteUndo(FavoriteModel item) {
    final int insertionIndex = lowerBound(favorites, item);
    setState(() {
      favorites.insert(insertionIndex, item);
    });

    writeFavorites();
  }

  void addToFavs(DiceHistoryModel model) {
    Map<String, int> dice = historyDiceToFav(model.dice);
    setState(() {
      favorites.insert(0, new FavoriteModel(name: "favorite ${favorites.length}", dice: dice));
    });

    writeFavorites();
  }

  void addActiveFavorite() {
    addFavorite(activeFavorite);
  }

  void addFavorite(FavoriteModel favorite) {
    if(favorite == null) {
      _showFavoriteAlert();
    }

    if(favorites.contains(favorite)) {
      FavoriteModel newFavorite = new FavoriteModel (
        name: favorite.name,
        color: new Map.from(favorite.color),
        highlighting: new Map.from(favorite.highlighting),
        dice: new Map.from(favorite.dice)
      );

      setState(() {
        favorites.insert(0, newFavorite);
      });
    } else {
      setState(() {
        favorites.insert(0, favorite);
      });
    }

    updateFIndices();

    writeFavorites();
  }

  Future<Null> _showFavoriteAlert() async {
    return showDialog<Null>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return new AlertDialog(
          title: new Text('No dice entered'),
          content: new Text("Click on a \"...\" box to create a die."),
          actions: <Widget>[
            new FlatButton(
              child: new Text('Okay'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void uploadFavorite(int index) {
    setState(() {
      activeFavorite = favorites[index];
    });
  }

  void removeFavorite(int index) {
    FavoriteModel favoriteModel = favorites[index];
    setState(() {
      favorites.removeAt(index);
    });

    updateFIndices();

    writeFavorites();

    _scaffoldKey.currentState.hideCurrentSnackBar();

    _scaffoldKey.currentState.showSnackBar(new SnackBar(
        content: new Text('You deleted item ${favoriteModel.index}'),
        action: new SnackBarAction(
            label: 'UNDO',
            onPressed: () { handleFavoriteUndo(favoriteModel); }
        )
    ));
  }

  void finalizeRoll() {
    setState(() {
      prevHistory = null;
    });
    _modifierInputController.text = "";
  }

  void handleLongPressFavorite(int index) {
    rollFavorite(favorites[index]);
  }

  void rollActiveFavorite() {
    rollFavorite(activeFavorite);

    setState(() {
      favoriteTotal = diceHistory[0].getTotal();
    });
  }

  void rollFavorite(FavoriteModel model) {
    DiceHistoryModel newRoll = new DiceHistoryModel(name: model.name,
        color: model.color, highlighting: model.highlighting, dice: new Map<String, List<int>>(),
        showIndividual: individualDice, favoriteOrigin: model);

    model.dice.keys.forEach((key) {
      if(key == "1") {
        newRoll = addRoll(int.parse(key), modelOpt: newRoll, randRoll: model.dice[key]);
      } else {
        for(int i = model.dice[key]; i > 0; i--) {
          newRoll = addRoll(int.parse(key), modelOpt: newRoll);
        }
      }
    });

    applyRules(newRoll, model);

    addHistory(newRoll);
    finalizeRoll();
  }

  DiceHistoryModel applyRules(DiceHistoryModel newRoll, FavoriteModel model) {
    // Handle rules
    if(model.rules["rerollOnes"]) {
      newRoll.dice = DiceUtility.rerollOnes(newRoll.dice);
    }

    if(model.rules["rerollLowest"]) {
      newRoll.dice = DiceUtility.rerollAllLowest(newRoll.dice);
    }

    if(model.rules["removeLowest"]) {
      newRoll.dice = DiceUtility.removeLowest(newRoll.dice);
    }

    return newRoll;
  }

  Map<String, int> historyDiceToFav(Map<String, List<int>> dice) {
    return dice.map((key, value) => new MapEntry(key, value.length));
  }

  String getDiceCount(int position, int numSides) {
    String returnable = "";
    if(prevHistory != null) {
      if(prevHistory.dice.containsKey(numSides.toString())) {
        returnable += prevHistory.dice[numSides.toString()].length.toString();
      }
    } else {
      if(onlyShowCount) {
        returnable += "d" + _diceVals[position];
      }
    }

    if(!onlyShowCount) {
      returnable += "d" + _diceVals[position];
    }

    return returnable;
  }

  Widget getDiceIcon(int position) {
    if(diceAnimControllers[position].isAnimating) {
      if(position >= 6) position = 5;
      return new Image(image: new AssetImage("assets/d${_diceVals[position]}.gif"));
    } else {
      return _diceImages[position];
    }
  }


  Widget getStandardDice(int position, int numSides) {
    return new Container(
      width: 60.0,
      height: 60.0,
      child: new GestureDetector(
        onTap: () {
          handleDiceClicked(numSides);
          diceAnimControllers[position].forward(from: 0.0);
        },
        onLongPress: () {
          handleDiceLongPress(numSides);
        },
        child: new Stack(
          children: <Widget>[
            Center(child: getDiceIcon(position)),
            Center(
              child: new Text(
                  getDiceCount(position, numSides),
                  style: diceStyle,
                  textAlign: TextAlign.center,
              )
            )
          ],
        )
      )
    );
  }

  Text getSumText() {
    if(prevHistory != null) {
      rollerSum = prevHistory.getTotal();
    } else {
      rollerSum = 0;
    }

    return new Text(rollerSum.toString(), style: otherStyle,);
  }

  Widget getModifierField() {
    return new TextField(
      controller: _modifierInputController,
      keyboardType: TextInputType.numberWithOptions(signed: true, decimal: false),
      style: otherStyle,
      inputFormatters: [WhitelistingTextInputFormatter(new RegExp(r'[\d]'))],
    );
  }

  String getModifierNegative() {
    print("Getting modifier negative: $modifierNegative");
    return modifierNegative ? "-" : "+";
  }

  void _removeCustomDie(int dicePos) {
    if(dicePos >= activeFavorite.dice.keys.length) return;

    setState(() {
      activeFavorite.dice.remove(
          activeFavorite.dice.keys.toList(growable: false)[dicePos]);
    });
  }

  Future<Null> _addCustomDie(int) async {
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return new SimpleDialog(
          title: new Text("Add a die or modifier"),
          children: <Widget>[
            new CustomDieDialog(addFavoriteDie)
          ],
        );
      }
    );
  }

  Future<Null> _warnNumDiceRestriction() async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return new AlertDialog(
            title: new Text("Number of dice restricted"),
            content: new Text("Please keep the number of dice less than 100 per die type."),
            actions: <Widget>[
              new FlatButton(onPressed: () { Navigator.pop(context); }, child: new Text("Okay"))
            ],
          );
        }
    );
  }

  void addFavoriteDie(int numDice, int numSides) {
    if(activeFavorite == null) {
      activeFavorite = new FavoriteModel(dice: new Map<String, int>());
    }

    if(activeFavorite.dice.containsKey(numSides.toString())) {
      // Don't let user add more than 100 dice to a single side
      if (activeFavorite.dice[numSides.toString()] + numDice > 100) {
        //_warnNumDiceRestriction();
      } else {
        setState(() {
          activeFavorite.dice[numSides.toString()] += numDice;
        });
      }
    } else {
      setState(() {
        activeFavorite.dice[numSides.toString()] = numDice;
      });
    }
  }

  Widget getCustomDice(int dicePos, {String boxVal = "..."}) {
    if(activeFavorite != null) {
      //print("getting custom dice for dicePos $dicePos : ${activeFavorite.dice.keys.length}");
      if(dicePos < activeFavorite.dice.keys.length) {
        String numSides = activeFavorite.dice.keys.toList()[dicePos];
        int numDice = activeFavorite.dice[activeFavorite.dice.keys.toList()[dicePos]];
        if(numSides == "1") {
          if(numDice >= 0) {
            boxVal = "+$numDice";
          } else {
            boxVal = "$numDice";
          }
        } else {
          boxVal = numDice.toString() + "d" + numSides;
        }
      }
    }

    return new CustomDieButton(dicePos, text: boxVal, onTap: _addCustomDie, onLongPress: () { _removeCustomDie(dicePos); },);
  }

  Widget getCRTotalField() {
    String favoriteTotalString = favoriteTotal != null ? favoriteTotal.toString() : "0";

    return new Container(
        decoration: new BoxDecoration(
          border: Border.all(color: Colors.grey.shade50),
        ),
        width: 60.0,
        height: 60.0,
        child: new InkWell(
          onTap: () {
            setState(() {
              activeFavorite = null;
              favoriteTotal = null;
            });
          },
          child: Center(child: new Text("= $favoriteTotalString"),)),
    );
  }

  Widget getCRRollDiceButton() {

    Function() onPressed = activeFavorite != null && activeFavorite.dice.isNotEmpty ? rollActiveFavorite : null;

    return new Container(
        decoration: new BoxDecoration(
          border: Border.all(color: Colors.grey.shade50),
        ),
        width: 100.0,
        height: 60.0,
        child: new FlatButton(
          onPressed: onPressed,
          child: Center(child: new Text("Roll dice", textAlign: TextAlign.center,)),
        )
    );
  }

  Widget getCRAddToFavoriteButton() {

    Function() onPressed = activeFavorite != null && activeFavorite.dice.isNotEmpty ? addActiveFavorite : null;

    return new Container(
      decoration: new BoxDecoration(
        border: Border.all(color: Colors.grey.shade50),
      ),
      width: 100.0,
      height: 60.0,
      child: new FlatButton(
          onPressed: onPressed,
          child: Center(child: new Text("Add to favorites", textAlign: TextAlign.center,))),
    );
  }

  void handleSettingsDeleteHistory() {
    deleteAllHistory().then((delete) {
      if(!delete) return;
      setState(() {
        diceHistory.clear();
      });
    });
  }

  Future<bool> deleteAllHistory() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return new AlertDialog(
          title: new Text("Delete dice history?"),
          content: new Text("You cannot undo this deletion."),
          actions: <Widget>[
            new FlatButton(
                onPressed: () { Navigator.of(context).pop(false); },
                child: new Text("Cancel"),
              textColor: Colors.grey.shade50,
            ),
            new FlatButton(
                onPressed: () { Navigator.of(context).pop(true); },
                child: new Text("Delete"),
              textColor: Colors.red,
            ),
          ],
        );
      }
    );
  }

  void handleSettingsDeleteFavorites() {
    deleteAllFavorites().then((delete) {
      if(!delete) return;
      setState(() {
        favorites.clear();
      });
    });
  }

  Future<bool> deleteAllFavorites() async {
    return showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return new AlertDialog(
            title: new Text("Delete favorites?"),
            content: new Text("You cannot undo this deletion."),
            actions: <Widget>[
              new FlatButton(
                onPressed: () { Navigator.of(context).pop(false); },
                child: new Text("Cancel"),
                textColor: Colors.grey.shade50,
              ),
              new FlatButton(
                onPressed: () { Navigator.of(context).pop(true); },
                child: new Text("Delete"),
                textColor: Colors.red,
              ),
            ],
          );
        }
    );
  }

  void toggleIndividualDice(bool val) async {
    final SharedPreferences prefs = await _prefs;

    prefs.setBool('individualDice', val);

    setState(() {
      individualDice = val;
    });
  }

  void toggleOnlyShowCount(bool val) async {
    final SharedPreferences prefs = await _prefs;

    prefs.setBool('onlyShowCount', val);

    setState(() {
      onlyShowCount = val;
    });
  }

  List<Widget> fakeBottomButtons = <Widget>[
    new Container(height: 50.0),
  ];

  //----------- Pages ------------//

  Widget getStandardRollerPage() {
    return new Column(
      children: <Widget>[
        new Expanded(
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              getStandardDice(0, 4),
              getStandardDice(1, 6),
              getStandardDice(2, 8),
              getStandardDice(3, 10),
              getStandardDice(4, 12),
            ],
          ),
        ),
        new Expanded(
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              getStandardDice(5, 20),
              getStandardDice(6, 100),
              new Container(
                width: 40.0,
                height: 60.0,
                child: new FlatButton(
                  onPressed: toggleModifierSign,
                  child: Center(child: new Text(
                    modifierNegative ? "-" : "+",
                    style: otherStyle,
                  textAlign: TextAlign.center,)),
                )),
              new Container(
                width: 60.0,
                child: Center(child: getModifierField()),
              ),
              new Container(
                width: 20.0,
                height: 60.0,
                child: Center(child: new Text("=", style: otherStyle,))),
              new FlatButton(
                onPressed: finalizeRoll,
                child: new Container(
                  child: Center(child: getSumText(),),
                )
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget getCustomRollerPage() {
    return new Column(
      children: <Widget>[
        new Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              getCustomDice(0),
              getCustomDice(1),
              getCustomDice(2),
              getCustomDice(3),
              getCRRollDiceButton(),
            ],
          ),
        ),
        new Padding(
          padding: EdgeInsets.only(bottom: 20.0),
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              getCustomDice(4),
              getCustomDice(5),
              getCustomDice(6),
              getCRTotalField(),
              getCRAddToFavoriteButton(),
            ],
          ),
        )
      ],
    );
  }

  Widget getDiceHistory() {
    return new Container(
      child: ListView.builder(
        itemBuilder: (BuildContext context, int index) {
        DiceHistoryItem historyItem = new DiceHistoryItem(diceHistory, removeHistory, index, addToFavs, handleReroll, writeHistory);

          Widget item;
          if (index.isOdd) {
            item = new Container(
              child: new Column(
                children: <Widget>[
                  new Divider(),
                  historyItem,
                  new Divider(),
                ],
              ),
            );
          } else {
            item = new Column(
             children: <Widget>[
              item = historyItem,
             ],
            );
          }

          return item;
        },
        itemCount: diceHistory.length,
      ),
//      child: ListView(
//        children: diceHistory.map((DiceHistoryModel model) {
//          model.index =
//          DiceHistoryItem listItem = new DiceHistoryItem(
//            model,
//            removeHistory,
//          );
//          return listItem;
//        }).toList(),
//      ),
//      child: ListView(
//        children: diceHistoryListItems,
//      ),
    );
  }

  Widget getFavorites() {
    return new Container(
      child: ListView.builder(
        itemBuilder: (BuildContext context, int index) {
          FavoriteItem favoriteItem = new FavoriteItem(index, favorites, uploadFavorite, removeFavorite,
              handleLongPressFavorite, writeFavorites);

          Widget item;
          if (index.isOdd) {
            item = new Container(
              child: new Column(
                children: <Widget>[
                  new Divider(),
                  favoriteItem,
                  new Divider(),
                ],
              ),
            );
          } else {
            item = favoriteItem;
          }
//          print("getState: " + item.createState().history.dice.toString());
          return item;

        },
        itemCount: favorites.length,
      )
    );
  }

  Widget getSettings() {
    return new Container(
//      child: DraggableScrollbar(
//        controller: _settingScrollController,
//        heightScrollThumb: 48.0,
//        backgroundColor: Colors.green,
//        scrollThumbBuilder: (
//          Color backgroundColor,
//            Animation<double> thumbAnimation,
//            Animation<double> labelAnimation,
//            double height,
//            { Text labelText, BoxConstraints labelConstraints,})
//          {
//            return Padding(
//              padding: const EdgeInsets.all(4.0),
//              child: new Container(
//                decoration: BoxDecoration(
//                  borderRadius: BorderRadius.circular(2.0),
//                  color: backgroundColor,
//                ),
//                height: height,
//                width: 12.0,
//            ));
//          },
        child: new ListView(
          controller: _settingScrollController,
          children: <Widget>[
            new Row(
              children: <Widget>[
                new Container(
                  height: 32.0,
                  padding: const EdgeInsets.symmetric(horizontal: 0.0),
                  child: new Checkbox(
                      value: onlyShowCount,
                      onChanged: (val) { toggleOnlyShowCount(val); }
                  ),
                ),
                new Text("Only show count in dice", style: diceStyle,)
              ],
            ),
            new Row(
              children: <Widget>[
                new Container(
                  height: 32.0,
                  padding: const EdgeInsets.symmetric(horizontal: 0.0),
                  child: new Checkbox(
                      value: individualDice,
                      onChanged: (val) { toggleIndividualDice(val); }
                  ),
                ),
                new Text("Dice show individual as default", style: diceStyle,)
              ],
            ),
//            Row(
//              children: <Widget>[
//                Padding(
//                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
//                  child: new RaisedButton(color: Colors.grey.shade600, onPressed: () {}, child: new Text("Play Tutorial", style: diceStyle,),),
//                ),
//              ],
//            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: new Row(
                children: <Widget>[
                  new RaisedButton(color: Colors.grey.shade600, onPressed: handleSettingsDeleteHistory, child: new Text("Delete Dice History", style: diceStyle,),),
                  new Container(width: 8.0,),
                  new RaisedButton(color: Colors.grey.shade600, onPressed: handleSettingsDeleteFavorites, child: new Text("Delete Favorites", style: diceStyle,),)
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget buildTabView(_Page page) {
    switch (page.type) {
      case PageType.roller:
        return getStandardRollerPage();
      case PageType.customRoller:
        return getCustomRollerPage();
      case PageType.settings:
        return getSettings();
      case PageType.history:
        return getDiceHistory();
      case PageType.favorites:
        return getFavorites();
      default:
        return getStandardRollerPage();
    }
  }

  @override
  Widget build(BuildContext context) {
//    print("- - - - - - ");
//    print("building");
    return new Scaffold(
      key: _scaffoldKey,
      appBar: new PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: new Container(
          color: Colors.grey.shade800,
          child: new SafeArea(
            child: new Container(
              //color: Colors.green,
              child: new TabBar(
                controller: _controller,
                tabs: _allPages.map((_Page page) => new Tab(
                  text: page.label,
                )).toList(),
              ),
            ),
          ),
        )
      ),
      body: new Column(
        children: <Widget>[
          new Ink(
            height: 160.0,
            child: new TabBarView(
              controller: _controller,
              children: _allPages.map(buildTabView).toList()
            ),
          ),
          new Container(
            color: Colors.grey.shade800,
            child: new TabBar(
              controller: _listsController,
              tabs: _histories.map((_Page page) => new Tab(
                text: page.label,
              )).toList(),
            ),
          ),
          new Container(
            child: new Expanded(
              child: Row(
                children: <Widget>[
                  new Expanded(
                    child: new TabBarView(
                      controller: _listsController,
                      children: _histories.map(buildTabView).toList(),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class DiceHistoryItem extends StatefulWidget {
  DiceHistoryItem(this.history, this.removeHistory, this.index,
      this.addToFavs, this.reroll, this.writeHistory);

//  DiceHistoryItem(List<DiceHistoryModel> histories, Function(int) removeHistory,
//    Function(DiceHistoryModel) addToFavorites, Function() reroll, int index, {bool showIndividual}) :
//      this.history = histories,
//      this.removeHistory = removeHistory,
//      this.index = index,
//      this.showIndividual = showIndividual
//      {
////        print("DiceHistoryItem: " + history[index].dice.toString());
//      }

  final List<DiceHistoryModel> history;
  final void Function(int) removeHistory;
  final int index;
  final void Function(DiceHistoryModel) addToFavs;
  final void Function(int) reroll;
  final void Function() writeHistory;

  @override
  _DiceHistoryItemState createState() => _DiceHistoryItemState(history, removeHistory, index, addToFavs, reroll, writeHistory);
}

class _DiceHistoryItemState extends State<DiceHistoryItem> {

//  _DiceHistoryItemState(this.history, this.removeHistory, this.index,
//      this.addToFavs, this.reroll, {this.showIndividual});

  _DiceHistoryItemState(List<DiceHistoryModel> history, Function removeHistory, int index,
      Function(DiceHistoryModel) addToFavs, Function(int) reroll, Function() writeHistory) {
    this.history = history;
    this.removeHistory = removeHistory;
    this.index = index;
    this.addToFavs = addToFavs;
    this.reroll = reroll;
    this.writeHistory = writeHistory;

    this.history[index].index = index;
//    print("Proving index was set: ${this.history[index].index}");
//    print("_DiceHistoryItemState: " + index.toString() + ", " + this.history[index].dice.toString());
  }

  static const String saveToFavsString = 'Save to favorite';
  static const String rerollOnes = "Reroll 1's";
  static const String removeLowest = "Remove lowest";
  static const String rerollLowest = "Reroll all lowest";
  static const String addHighlight = "Add highlighting";

  int index;
  List<DiceHistoryModel> history;
  void Function(int) removeHistory; //final
  void Function(DiceHistoryModel) addToFavs;
  void Function(int) reroll;
  void Function() writeHistory;

  TextStyle diceStyle = new TextStyle(color: Colors.grey.shade50, fontSize: 18.0);
  TextStyle diceStyleBold = new TextStyle(color: Colors.grey.shade50, fontWeight: FontWeight.w800);

  void showMenuSelection(String value) {
    if(<String>[saveToFavsString, rerollOnes, removeLowest, rerollLowest, addHighlight].contains(value))
      print("showMenuSelection: " + value);

    switch(value) {
      case saveToFavsString:
        addToFavs(history[index]);
        break;
      case rerollOnes:
        var updated = DiceUtility.rerollOnes(history[index].dice);
        setState((){ history[index].dice = updated; });
        break;
      case removeLowest:
        var updated = DiceUtility.removeLowest(history[index].dice);
        setState((){ history[index].dice = updated; });
        break;
      case rerollLowest:
        var updated = DiceUtility.rerollAllLowest(history[index].dice);
        setState(() { history[index].dice = updated; });
        break;
      case addHighlight:
        changeHighlightDialog(context).then((val) {
          changeHighlight(val);
        });

    }
  }

  Future<Map<String, bool>> changeHighlightDialog(BuildContext context) {
    return showDialog<Map<String, bool>>(
        context: context,
        builder: (BuildContext context) {
          Map<String, bool> newHighlight = new Map<String, bool>();

          void updateNewHighlight(bool least, bool greatest) {
            newHighlight["least"] = least;
            newHighlight["greatest"] = greatest;
          }

          return new AlertDialog(
            title: const Text("Select highlight"),
            content: new SingleChildScrollView(
              child: new HighlightSelectDialog(updateNewHighlight, history[index].highlighting),
            ),
            actions: <Widget>[
              new FlatButton(onPressed: () {Navigator.pop(context); }, child: new Text("Cancel"), textColor: Colors.grey.shade50,),
              new FlatButton(onPressed: () {Navigator.of(context).pop(newHighlight); }, child: new Text("Change")),
            ],
          );
        }
    );
  }

  void changeHighlight(Map<String, bool> highlight) {
    if(highlight != null) {
      setState(() {
        history[index].highlighting = highlight;
      });

      writeHistory();
    }
  }

  Widget getHistoryColor() {
    var c = history[index].color;

    if(c != null && c["r"] >= 0 && c["g"] >= 0 && c["b"] >= 0) {
      return new Container(
        color: new Color.fromARGB(255, c["r"], c["g"], c["b"]),
        width: 10.0,
        height: 60.0,
      );
    } else {
      return new Container(
        width: 10.0,
        height: 60.0,
      );
    }
  }

  Text getDiceText() {
//    print("getDiceText: " + history[index].dice.toString());
    return history[index].getDiceToString(individual: history[index].showIndividual);
  }

  Text getDiceName() {
    String name = history[index].name;

    return new Text(name, style: diceStyleBold,);
  }

  void toggleShowIndividual() {
    setState(() {
      history[index].showIndividual = !history[index].showIndividual;
    });
  }

  void rerollThis() {
    reroll(index);
  }

  @override
  Widget build(BuildContext context) {
    return new InkWell(
      onTap: toggleShowIndividual,
      onLongPress: rerollThis,
      child: new Row(
        children: <Widget>[
          getHistoryColor(),
          new Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  new Container(
                    child: getDiceName(),
                  ),
                  new Container(
                    child: getDiceText(),
                  )
                ]
              ),
            ),
          ),
          new Container(
          width: 24.0,
            child: new PopupMenuButton<String>(
              onSelected: showMenuSelection,
                itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
                  const PopupMenuItem<String>(
                    value: saveToFavsString,
                    child: Text(saveToFavsString)
                  ),
                  const PopupMenuItem<String>(
                      value: rerollOnes,
                      child: Text(rerollOnes)
                  ),
                  const PopupMenuItem<String>(
                      value: removeLowest,
                      child: Text(removeLowest)
                  ),
                  const PopupMenuItem<String>(
                      value: rerollLowest,
                      child: Text(rerollLowest)
                  ),
                  const PopupMenuItem<String>(
                      value: addHighlight,
                      child: Text(addHighlight)
                  ),
                ])
          ),
          new IconButton(icon: new Icon(Icons.delete_forever), onPressed: () {
            //print("deleteForever pressed: " + history.index.toString());
//              print("______________________________");
//              print("deleting: " + index.toString());
            removeHistory(index);
          }),
        ],
      ),
    );
  }
}

class FavoriteItem extends StatefulWidget {
  FavoriteItem(this.index, this.favorites, this.uploadFavorite, this.removeFavorite,
      this.rollFavorite, this.writeFavorites);

  final int index;
  final List<FavoriteModel> favorites;
  final void Function(int) uploadFavorite;
  final void Function(int) removeFavorite;
  final void Function(int) rollFavorite;
  final void Function() writeFavorites;

  @override
  _FavoriteItemState createState() => _FavoriteItemState(index, favorites, uploadFavorite,
      removeFavorite, rollFavorite, writeFavorites);
}

class _FavoriteItemState extends State<FavoriteItem> {
  _FavoriteItemState(this.index, this.favorites, this.uploadFavorite, this.removeFavorite,
      this.rollFavorite, this.writeFavorites);

  TextStyle diceStyle = new TextStyle(color: Colors.grey.shade50);
  TextStyle diceStyleBold = new TextStyle(color: Colors.grey.shade50, fontWeight: FontWeight.w800);

  int index;
  List<FavoriteModel> favorites;
  final void Function(int) uploadFavorite;
  final void Function(int) removeFavorite;
  final void Function(int) rollFavorite;
  final void Function() writeFavorites;

  Widget getHistoryColor() {
    var c = favorites[index].color;

    if(c != null && c["r"] >= 0 && c["g"] >= 0 && c["b"] >= 0) {
      return new Container(
        color: new Color.fromARGB(255, c["r"], c["g"], c["b"]),
        width: 10.0,
        height: 60.0,
      );
    } else {
      return new Container(
        width: 10.0,
        height: 60.0,
      );
    }
  }

  void changeName(String name) {
    if(name != null) {
      setState(() {
        favorites[index].name = name;
      });

      writeFavorites();
    }
  }

  void changeRules(Map<String, bool> rules) {
    if(rules != null) {
      setState(() {
        favorites[index].rules = rules;
      });

      writeFavorites();
    }
  }

  void showMenuSelection(String value) {
    if(<String>["Change color", "Change name", "Upload to roller", "Add rule", "Add highlighting"].contains(value)) {
      print(value);
      switch(value) {
        case "Change name":
          changeNameDialog(context).then((val) {
            changeName(val);
          });
          break;
        case "Change color":
          changeColorDialog(context).then((val) {
            changeColor(val);
          });
          break;
        case "Upload to roller":
          uploadFavorite(index);
          break;
        case "Add rule":
          changeRulesDialog(context).then((val) {
            changeRules(val);
          });
          break;
        case "Add highlighting":
          changeHighlightDialog(context).then((val) {
            changeHighlight(val);
          });
          break;
      }
    }
  }

  Future<String> changeNameDialog(BuildContext context) {
    return showDialog<String>(
        context: context,
      builder: (BuildContext context) {
        return new SimpleDialog(
          title: new Text("Change name"),
          children: <Widget>[new TextDialog()],
        );
      }
    );
  }

  changeColor(Color color) {
    if(color == null) return;

    setState(() {
      favorites[index].setColor(color);
    });

    writeFavorites();
  }

  Future<Color> changeColorDialog(BuildContext context) {
    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        Color newColor;
        return new AlertDialog(
          title: const Text("Pick a color!"),
          content: new SingleChildScrollView(
            child: new ColorPicker(
                pickerColor: favorites[index].getColor(),
                onColorChanged: (pickedColor) {
                  newColor = pickedColor;
                },

              enableLabel: false,
              pickerAreaHeightPercent: 0.75,
            ),
          ),
          actions: <Widget>[
            new FlatButton(
              onPressed: () { Navigator.pop(context); },
              child: new Text("Cancel"),
              textColor: Colors.grey.shade50,
            ),
            new FlatButton(
                onPressed: () {
                  Navigator.of(context).pop(newColor);
                },
                child: new Text("Change")
            )
          ],
        );
      }
    );
  }

  Future<Map<String, bool>> changeRulesDialog(BuildContext context) {
    return showDialog<Map<String, bool>>(
      context: context,
      builder: (BuildContext context) {
        Map<String, bool> newRules = new Map<String, bool>();

        void updateNewRules(bool rerollOnes, bool rerollLowest, bool removeLowest) {
          newRules["rerollOnes"] = rerollOnes;
          newRules["rerollLowest"] = rerollLowest;
          newRules["removeLowest"] = removeLowest;
        }

        return new AlertDialog(
          title: const Text("Select rules"),
          content: new SingleChildScrollView(
            child: new RulesSelectDialog(updateNewRules, favorites[index].rules),
          ),
          actions: <Widget>[
            new FlatButton(onPressed: () {Navigator.pop(context); }, child: new Text("Cancel"), textColor: Colors.grey.shade50,),
            new FlatButton(onPressed: () {Navigator.of(context).pop(newRules); }, child: new Text("Change")),
          ],
        );
      }
    );
  }

  Future<Map<String, bool>> changeHighlightDialog(BuildContext context) {
    return showDialog<Map<String, bool>>(
        context: context,
        builder: (BuildContext context) {
          Map<String, bool> newHighlight = new Map<String, bool>();

          void updateNewHighlight(bool least, bool greatest) {
            newHighlight["least"] = least;
            newHighlight["greatest"] = greatest;
          }

          return new AlertDialog(
            title: const Text("Select highlight"),
            content: new SingleChildScrollView(
              child: new HighlightSelectDialog(updateNewHighlight, favorites[index].highlighting),
            ),
            actions: <Widget>[
              new FlatButton(onPressed: () {Navigator.pop(context); }, child: new Text("Cancel"), textColor: Colors.grey.shade50,),
              new FlatButton(onPressed: () {Navigator.of(context).pop(newHighlight); }, child: new Text("Change")),
            ],
          );
        }
    );
  }

  void changeHighlight(Map<String, bool> highlight) {
    if(highlight != null) {
      setState(() {
        favorites[index].highlighting = highlight;
      });

      writeFavorites();
    }
  }

  Widget getRuleImages() {
    Widget rerollOnes = favorites[index].rules["rerollOnes"]
        ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: new Image(image: new AssetImage("assets/rerollones.png"), height: 40.0,),
        )
        : new Container();
    Widget rerollLowest = favorites[index].rules["rerollLowest"]
        ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: new Image(image: new AssetImage("assets/rerolllowest.png"), height: 40.0,),
        )
        : new Container();
    Widget removeLowest = favorites[index].rules["removeLowest"]
        ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: new Image(image: new AssetImage("assets/removelowest.png"), height: 40.0,),
        )
        : new Container();

    return new Row(
      children: <Widget>[
        rerollOnes,
        rerollLowest,
        removeLowest
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return new InkWell(
      onTap: () { uploadFavorite(index); },
      onLongPress: () { rollFavorite(index); },
      child: new Container(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: new Row(
            children: <Widget>[
              getHistoryColor(),
              new Expanded(
                child: new Container(
                  height: 60.0,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: new Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        new Container(
                          child: new Text(favorites[index].name, style: diceStyleBold,),
                        ),
                        new Container(
                          child: favorites[index].getDiceText(),
                        )
                      ]
                  ),
                ),
              ),
              getRuleImages(),
              new Container(
              width: 24.0,
                child:
                new PopupMenuButton<String>(
                  onSelected: showMenuSelection,
                  itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
                    const PopupMenuItem<String>(
                        value: 'Change color',
                        child: Text('Change color')
                    ),
                    const PopupMenuItem<String>(
                        value: 'Change name',
                        child: Text('Change name')
                    ),
                    const PopupMenuItem<String>(
                        value: 'Upload to roller',
                        child: Text('Upload to roller')
                    ),
                    const PopupMenuItem<String>(
                        value: 'Add rule',
                        child: Text('Select rules')
                    ),
                    const PopupMenuItem<String>(
                        value: 'Add highlighting',
                        child: Text('Add highlighting')
                    )
                  ]),
              ),
              IconButton(
                icon: new Icon(Icons.delete_forever),
                onPressed: () { removeFavorite(index); },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FavoriteModel implements Comparable<FavoriteModel> {

  int index;
  String name;
  Map<String, int> color;
  Map<String, bool> highlighting;
  Map<String, dynamic> rules;
  Map<String, int> dice;

  static const Map<String, int> defaultColor = {"r":30,"g":250,"b":80};
  static const Map<String, bool> defaultHighlight = {"least":false,"greatest":false};
  static const Map<String, bool> defaultRules = {"rerollOnes":false, "rerollLowest":false, "removeLowest":false};
  static const Map<String, int> defaultDice = {"1":0};

  FavoriteModel({
    this.name = "",
    this.color = defaultColor,
    this.highlighting = defaultHighlight,
    this.rules = defaultRules,
    this.dice = defaultDice,
  });

  FavoriteModel.fromJson(Map<String, dynamic> json) :
    name = json["name"],
    color = (json["color"] as Map).cast<String, int>(),
    highlighting = (json["highlighting"] as Map).cast<String, bool>(),
    rules = (json["rules"] as Map).cast<String, bool>(),
    dice = (json["dice"] as Map).cast<String, int>();

  Map<String, dynamic> toJson() => {
    "name": name,
    "color": color,
    "highlighting": highlighting,
    "rules": rules,
    "dice": dice,
  };

  Text getDiceText() {
    if(dice == null) {
      return new Text("Dice == null");
    }

    String returnable = "";

    var sortedKeys = dice.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    int mod;

    sortedKeys.forEach((key) {
      if(key == "1") {
        mod = dice[key];
      } else {
        int numDice = dice[key];
        returnable += "$numDice" + "d" + "$key";

        if(sortedKeys.last != key) returnable += " + ";
      }
    });

    if(mod != null) {
      String sign;

      if(mod < 0) {
        sign = " - ";
        mod *= -1;
      } else {
        sign = " + ";
      }

      returnable += sign + mod.toString();
    }

    return new Text(returnable);
  }

  @override
  int compareTo(FavoriteModel other) {
    return index.compareTo(other.index);
  }

  void setColor(Color color) {
    this.color = new Map<String, int>();
    this.color["r"] = color.red;
    this.color["g"] = color.green;
    this.color["b"] = color.blue;
  }

  Color getColor() {
    return new Color.fromARGB(255, color["r"], color["g"], color["b"]);
  }
}

class DiceHistoryModel implements Comparable<DiceHistoryModel>{

  int index;
  bool showIndividual = false;
  FavoriteModel favoriteOrigin;
  String name;
  Map<String, int> color; //int
  Map<String, bool> highlighting; //bool
  Map<String, List<int>> dice; //List<int>

  static const Map<String, int> defaultColor = {"r":-1,"g":-1,"b":-1};
  static const Map<String, bool> defaultHighlight = {"least":false,"greatest":false};
  static const Map<String, List<int>> defaultDice = {"1":[0]};

  DiceHistoryModel({
    this.name = "",
    this.color = defaultColor,
    this.highlighting = defaultHighlight,
    this.dice = defaultDice,
    this.showIndividual,
    this.favoriteOrigin
  });

  DiceHistoryModel.fromJson(Map<String, dynamic> json, int index, {this.showIndividual}) :
    name = json["name"],
    color = (json["color"] as Map).cast<String, int>(),
    highlighting = (json["highlighting"] as Map).cast<String, bool>(),
    dice = (json["dice"] as Map).map((numSides, rolls) => MapEntry(numSides, (rolls as List).cast<int>()));

  Map<String, dynamic> toJson() => {
    "name": name,
    "color": color,
    "highlighting": highlighting,
    "dice": dice,
  };

  int getTotal() {
    int total = 0;
    dice.forEach((key, value) {
      value.forEach((roll) {
        total += roll;
      });
    });
    return total;
  }

  int getModifier() {
    if(dice.containsKey("1") && dice["1"].isNotEmpty) {
      return dice["1"][0];
    } else {
      return null;
    }
  }


  @override
  int compareTo(DiceHistoryModel other) {
    return index.compareTo(other.index);
  }

  TextStyle lowLight = new TextStyle(color: Colors.red);
  TextStyle highLight = new TextStyle(color: Colors.green);
  TextStyle normal =  new TextStyle(color: Colors.grey.shade50);

  Text getDiceToString({bool individual}) {

    if(dice == null) {
      return new Text("DICE = null");
    }

    if(individual == null) {
      individual = false;
    }

    if(individual) {

      List<TextSpan> textSpans = new List<TextSpan>();
      var sortedKeys = dice.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      String curText = "";

      sortedKeys.forEach((numSides) {
        if(numSides == "1") {
          curText += "Mod:";
        } else {
          curText += "d$numSides:";
        }

        List<int> diceResults = dice[numSides];

        if((highlighting["least"] || highlighting["greatest"]) && numSides != "1") {
          int lowest = diceResults[0];
          int greatest = diceResults[0];


          // Get least and greatest for this numSides
          for(int i = 0; i < diceResults.length; i++) {
            if(diceResults[i] < lowest) lowest = diceResults[i];
            if(diceResults[i] > greatest) greatest = diceResults[i];
          }

          //
          for(int i = 0; i < diceResults.length; i++) {
            if(highlighting["least"] && diceResults[i] == lowest) {
              textSpans.add(new TextSpan(style: normal, text: curText));
              textSpans.add(new TextSpan(style: lowLight, text: " ${diceResults[i]}"));

              curText = "";

            } else if(highlighting["greatest"] && diceResults[i] == greatest) {
              textSpans.add(new TextSpan(style: normal, text: curText));
              textSpans.add(new TextSpan(style: highLight, text: " ${diceResults[i]}"));

              curText = "";

            } else {
                curText += " ${diceResults[i]}";
            }

            if(i < diceResults.length - 1) curText += ",";
          }

        } else {
          for(int i = 0; i < diceResults.length; i++) {
            curText += " ${diceResults[i]}";
            if(i < diceResults.length - 1) curText += ",";
          }
        }

        if(sortedKeys.last != numSides) curText += " | ";
      });

      textSpans.add(new TextSpan(style: normal, text: curText));

      return new Text.rich(new TextSpan(children: textSpans));

    } else {
      String returnable = "";

      int total = 0;
      int mod = 0;
      bool modIsEmpty = true;
      var sortedKeys = dice.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

      sortedKeys.forEach((numSides) {
        if(numSides == "1") {
          modIsEmpty = false;
          dice[numSides].forEach((val) {
            mod += val;
          });
        } else {
          List<dynamic> results = dice[numSides];
          int numDice = results.length;
          returnable += "$numDice" + "d" + "$numSides";

          if (sortedKeys.last != numSides) returnable += " + ";

          results.forEach((dieRes) {
            total += dieRes;
          });
        }
      });

      if(!modIsEmpty) {
        String sign;

        if(mod < 0) {
          sign = " - ";
          mod *= -1;
        } else {
          sign = " + ";
        }

        returnable += sign + mod.toString();
      }

      returnable += " = $total";

      return new Text(returnable);
    }
  }
}

class TextDialog extends StatefulWidget {

  @override
  State createState() => new _TextDialogState();
}

class _TextDialogState extends State<TextDialog> {

  String name;

  Function() getChangeNameFun() {
    if(name != null && name.isNotEmpty) {
      return () {
        Navigator.of(context).pop(name);
      };
    } else {
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    return new Column (
      children: <Widget> [
        new Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            new Container(width: 20.0),
            new Flexible(
              child: new TextField(
          onChanged: (val) {
              setState(() {
                name = val;
              });
          },
        ),
            ),
          new Container(width: 20.0,),]
        ),
      new Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          new FlatButton(
          onPressed: () { Navigator.pop(context); },
          child: new Text("Cancel"),
          textColor: Colors.grey.shade200,
        ),
        new FlatButton(
          onPressed: getChangeNameFun(),
          child: new Text("Change",),
          textColor: Colors.green,
        )]
      )]
    );
  }
}

class RulesSelectDialog extends StatefulWidget {
  RulesSelectDialog(this.updateVals, this.oldRules);

  final Function(bool, bool, bool) updateVals;
  final Map<String, bool> oldRules;

  @override
  State createState() => new _RulesSelectDialogState(updateVals, oldRules);
}

class _RulesSelectDialogState extends State<RulesSelectDialog> {
  _RulesSelectDialogState(this.updateVals, this.oldRules);

  Function(bool, bool, bool) updateVals;
  final Map<String, bool> oldRules;

  bool rerollOnes = false;
  bool rerollLowest = false;
  bool removeLowest = false;


  @override
  void initState() {
    super.initState();
    rerollOnes = oldRules["rerollOnes"];
    rerollLowest = oldRules["rerollLowest"];
    removeLowest = oldRules["removeLowest"];
  }

  void update() {
    updateVals(rerollOnes, rerollLowest, removeLowest);
  }

  @override
  Widget build(BuildContext context) {
    return new Column(
      children: <Widget>[
        new CheckboxListTile(value: rerollOnes,
          onChanged: (val) {
            setState(() {
              rerollOnes = val;
            });
            update();
          },
          title: const Text("Reroll ones"),
        ),
        new CheckboxListTile(
          value: rerollLowest,
          onChanged: (val) {
            setState(() {
              rerollLowest = val;
            });
            update();
          },
          title: new Text("Reroll lowest"),
        ),
        new CheckboxListTile(
          value: removeLowest,
          onChanged: (val) {
            setState(() {
              removeLowest = val;
            });
            update();
          },
          title: new Text("Remove lowest"),)
      ],
    );
  }
}

class HighlightSelectDialog extends StatefulWidget {
  HighlightSelectDialog(this.updateVals, this.oldHighlight);

  final Function(bool, bool) updateVals;
  final Map<String, bool> oldHighlight;

  @override
  State createState() => new _HighlightSelectDialogState(updateVals, oldHighlight);
}

class _HighlightSelectDialogState extends State<HighlightSelectDialog> {
  _HighlightSelectDialogState(this.updateVals, this.oldHighlight);

  Function(bool, bool) updateVals;
  final Map<String, bool> oldHighlight;

  bool least = false;
  bool greatest = false;

  @override
  void initState() {
    super.initState();
    least = oldHighlight["least"];
    greatest = oldHighlight["greatest"];
  }

  void update() {
    updateVals(least, greatest);
  }

  @override
  Widget build(BuildContext context) {
    return new Column(
      children: <Widget>[
        new CheckboxListTile(
          value: least,
          onChanged: (val) {
            setState(() {
              least = val;
            });
            update();
          },
          title: new Text("Least"),
        ),
        new CheckboxListTile(
          value: greatest,
          onChanged: (val) {
            setState(() {
              greatest = val;
            });
            update();
          },
          title: new Text("Greatest"),)
      ],
    );
  }
}


class DiceUtility {
  static Map<String, List<int>> rerollOnes(Map<String, List<int>> dice) {
    return dice.map((numSides, results) {

      if(int.tryParse(numSides) > 1) {
        for(int i = 0; i < results.length; i++) {
          if(results[i] == 1) {
            int newVal = 0;
            while(newVal <= 1) {
              newVal = getRandomRoll(int.parse(numSides));
            }
            results[i] = newVal;
          }
        }

        return MapEntry(numSides, results);

      } else {
          return MapEntry(numSides, results);
      }
    });
  }

  static Map<String, List<int>> removeLowest(Map<String, List<int>> dice) {
    return dice.map((numSides, results) {
      if(int.tryParse(numSides) > 1) {
        int lowest = results[0];
        for(int i = 0; i < results.length; i++) {
          if(results[i] < lowest) {
            lowest = results[i];
          }
        }
        results.removeWhere((val) => val == lowest);
      }

      return MapEntry(numSides, results);
    });
  }

  static Map<String, List<int>> rerollAllLowest(Map<String, List<int>> dice) {
    return dice.map((numSides, results) {
      if(int.tryParse(numSides) > 1) {
        int lowest = results[0];
        for(int i = 0; i < results.length; i++) {
          if(results[i] < lowest) {
            lowest = results[i];
          }
        }
        for(int i = 0; i < results.length; i++) {
          if(results[i] == lowest) {
            results[i] = getRandomRoll(int.parse(numSides));
          }
        }
      }

      return MapEntry(numSides, results);
    });
  }

  static int getRandomRoll(int numSides) {
    return Random(Random().nextInt(1000000000)).nextInt(numSides) + 1;
  }
}