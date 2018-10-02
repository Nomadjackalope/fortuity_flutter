import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomDieButton extends StatelessWidget {
  const CustomDieButton(this.die, {this.text, this.onTap, this.onLongPress});

  final int die;
  final String text;
  final void Function(int) onTap;
  final void Function() onLongPress;

  Text getText() {
    String textVal = text == null || text.isEmpty ? "..." : text;
    return new Text(textVal);
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
        decoration: new BoxDecoration(
        border: Border.all(color: Colors.grey.shade50),
    ),
    width: 60.0,
    height: 60.0,
    child: new Material(
      color: Colors.transparent,
      child: new InkWell(
        onTap: () { onTap(die); },
        onLongPress: onLongPress,
        child: Center(child: getText()),
        highlightColor: Colors.red,
        splashColor: Colors.green,
      ),
    ));
  }
}

class CustomDieDialog extends StatefulWidget {
  CustomDieDialog(this.dialogSuccess);

  final void Function(int, int) dialogSuccess;

  @override
  State createState() => new _CustomDieDialogState(dialogSuccess);
}

class _CustomDieDialogState extends State<CustomDieDialog> {
  _CustomDieDialogState(this.dialogSuccessFunction);

  final void Function(int, int) dialogSuccessFunction;

  bool creatingModifier = false;

  String modifier, numDice, numSides;

  final TextEditingController _modController = new TextEditingController();
  final TextEditingController _nDiceController = new TextEditingController();
  final TextEditingController _nSidesController = new TextEditingController();


  @override
  void initState() {
    super.initState();

    _modController.text = modifier != null ? modifier : "";
    _nDiceController.text = numDice != null ? numDice : "";
    _nSidesController.text = numSides != null ? numSides : "";

    _modController.addListener(_modControllerListener);

    _nDiceController.addListener(_nDiceControllerListener);

    _nSidesController.addListener(_nSidesControllerListener);
  }


  @override
  void dispose() {
    _modController.removeListener(_modControllerListener);
    _nDiceController.removeListener(_nDiceControllerListener);
    _nSidesController.removeListener(_nSidesControllerListener);

    _modController.dispose();
    _nDiceController.dispose();
    _nSidesController.dispose();
    super.dispose();
  }

  void _modControllerListener() {
    setState(() {
      modifier = _modController.text.isNotEmpty ? _modController.text : null;
    });
  }

  void _nDiceControllerListener() {
    setState(() {
      numDice = _nDiceController.text.isNotEmpty ? _nDiceController.text : null;
    });
  }

  void _nSidesControllerListener() {
    setState(() {
      numSides = _nSidesController.text.isNotEmpty ? _nSidesController.text : null;
    });
  }

  bool verifyDieInput() {
    if(numDice == null || numSides == null) {
      return false;
    }

    int numDiceParsed = int.tryParse(numDice);
    int numSidesParsed = int.tryParse(numSides);

    return numDiceParsed != null && numDiceParsed > 0 && numDiceParsed <= 100
        && numSidesParsed != null && numSidesParsed > 0;
  }

  bool verifyModInput() {
    return modifier != null && int.tryParse(modifier) != null;
  }

  Widget getAddButton() {
    void Function() buttonAction;

    if(creatingModifier && verifyModInput()) {
      buttonAction = () {
        dialogSuccessFunction(int.parse(modifier), 1);
        Navigator.pop(context);
      };
    } else if(!creatingModifier && verifyDieInput()) {
      buttonAction = () {
        dialogSuccessFunction(int.parse(numDice), int.parse(numSides));
        Navigator.pop(context);
      };
    }

    FlatButton button = new FlatButton(
      onPressed: buttonAction,
      child: new Text("Add"),
      textColor: Colors.green,
    );

    return button;
  }

  Widget getCancelButton() {
    return new FlatButton(
      onPressed: () { Navigator.pop(context); },
      child: new Text("Cancel"),
    );
  }

  Widget getCreator() {
    if(creatingModifier) {
      return new Container(
        width: 100.0,
        child: new TextField(
            decoration: InputDecoration(hintText: "Modifier"),
          controller: _modController,
          keyboardType: TextInputType.numberWithOptions(),
          inputFormatters: [WhitelistingTextInputFormatter(new RegExp(r'[\-\d]'))],
        ),
      );
    } else {
      return new Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          new Container(
            width: 100.0,
            child: new TextField(
                decoration: InputDecoration(hintText: "# dice"),
              controller: _nDiceController,
              keyboardType: TextInputType.numberWithOptions(),
              inputFormatters: [WhitelistingTextInputFormatter(new RegExp(r'[\d]'))],
            ),
          ),
          new Container(
            width: 100.0,
            child: new TextField(
              decoration: InputDecoration(hintText: "# sides"),
              controller: _nSidesController,
              keyboardType: TextInputType.numberWithOptions(),
              inputFormatters: [WhitelistingTextInputFormatter(new RegExp(r'[\d]'))],
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Column(
      children: <Widget>[
        new Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Text("Die"),
            new Switch(value: creatingModifier, onChanged: (val) {
              setState(() {
                creatingModifier = val;
              });
            }),
            new Text("Modifier"),
        ]),
        getCreator(),new Container(height: 20.0,),
        new Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
           getCancelButton(),
           getAddButton()
          ],
        )
      ],
    );
  }
}