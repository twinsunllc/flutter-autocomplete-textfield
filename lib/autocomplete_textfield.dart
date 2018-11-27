library autocomplete_textfield;

import 'package:flutter/material.dart';

typedef Widget AutoCompleteOverlayItemBuilder<T>(
    BuildContext context, T suggestion);

typedef bool Filter<T>(T suggestion, String query);

typedef StringCallback(String data);

class AutoCompleteTextField<T> extends StatefulWidget {
  List<T> suggestions;
  Filter<T> itemFilter;
  Comparator<T> itemSorter;
  StringCallback textChanged, textSubmitted;
  AutoCompleteOverlayItemBuilder<T> itemBuilder;
  int suggestionsAmount;
  GlobalKey<AutoCompleteTextFieldState<T>> key;
  bool submitOnSuggestionTap, clearOnSubmit;

  InputDecoration decoration;
  TextStyle style;
  TextInputType keyboardType;
  TextInputAction textInputAction;
  TextCapitalization textCapitalization;

  AutoCompleteTextField(
      {this.style,
      this.decoration: const InputDecoration(),
      this.textChanged,
      this.textSubmitted,
      this.keyboardType: TextInputType.text,
      @required this.key,
      @required this.suggestions,
      @required this.itemBuilder,
      @required this.itemSorter,
      @required this.itemFilter,
      this.suggestionsAmount: 100,
      this.submitOnSuggestionTap: true,
      this.clearOnSubmit: true,
      this.textInputAction: TextInputAction.done,
      this.textCapitalization: TextCapitalization.sentences})
      : super(key: key);

  void clear() {
    key.currentState.clear();
  }

  void addSuggestion(T suggestion) {
    key.currentState.addSuggestion(suggestion);
  }

  void removeSuggestion(T suggestion) {
    key.currentState.removeSuggestion(suggestion);
  }

  void updateSuggestions(List<T> suggestions) {
    key.currentState.updateSuggestions(suggestions);
  }

  @override
  State<StatefulWidget> createState() => new AutoCompleteTextFieldState<T>(
      suggestions,
      textChanged,
      textSubmitted,
      itemBuilder,
      itemSorter,
      itemFilter,
      suggestionsAmount,
      submitOnSuggestionTap,
      clearOnSubmit,
      textCapitalization,
      decoration,
      style,
      keyboardType,
      textInputAction);
}

class AutoCompleteTextFieldState<T> extends State<AutoCompleteTextField> {
  final FocusNode _focus = new FocusNode();
  TextField textField;
  List<T> suggestions;
  StringCallback textChanged, textSubmitted;
  AutoCompleteOverlayItemBuilder<T> itemBuilder;
  Comparator<T> itemSorter;
  OverlayEntry listSuggestionsEntry;
  List<T> filteredSuggestions;
  Filter<T> itemFilter;
  int suggestionsAmount;
  bool submitOnSuggestionTap, clearOnSubmit;
  double suggestionBoxHeight = 200.0;

  String currentText = "";

  AutoCompleteTextFieldState(
      this.suggestions,
      this.textChanged,
      this.textSubmitted,
      this.itemBuilder,
      this.itemSorter,
      this.itemFilter,
      this.suggestionsAmount,
      this.submitOnSuggestionTap,
      this.clearOnSubmit,
      TextCapitalization textCapitalization,
      InputDecoration decoration,
      TextStyle style,
      TextInputType keyboardType,
      TextInputAction textInputAction) {
    textField = new TextField(
      textCapitalization: textCapitalization,
      decoration: decoration,
      style: style,
      keyboardType: keyboardType,
      focusNode: _focus,
      controller: new TextEditingController(),
      textInputAction: textInputAction,
      onTap: _onTextFieldTap,
      onChanged: (newText) {
        currentText = newText;
        textChanged(newText);
        updateOverlay(newText);
      },
      onSubmitted: (submittedText) {
        FocusScope.of(context).requestFocus(new FocusNode());
        textSubmitted(submittedText);
        print(submittedText);
        if (clearOnSubmit) {
          clear();
        }
      },
    );
    textField.focusNode.addListener(() {
      if (!textField.focusNode.hasFocus) {
        filteredSuggestions = [];
      }
    });
  }

  void clear() {
    textField.controller.clear();
    updateOverlay("");
  }

  void addSuggestion(T suggestion) {
    suggestions.add(suggestion);
    updateOverlay(currentText);
  }

  void removeSuggestion(T suggestion) {
    suggestions.contains(suggestion)
        ? suggestions.remove(suggestion)
        : throw "List does not contain suggestion and therefore cannot be removed";
    updateOverlay(currentText);
  }

  void updateSuggestions(List<T> suggestions) {
    this.suggestions = suggestions;
    updateOverlay(currentText);
  }

  void _onTextFieldTap() {
    updateOverlay(
        textField.controller.text?.isEmpty ? '' : textField.controller.text);
  }

  void updateOverlay(String query) {
    if (listSuggestionsEntry == null) {
      final RenderBox textFieldRenderBox = context.findRenderObject();
      final RenderBox overlay = Overlay.of(context).context.findRenderObject();
      final width = textFieldRenderBox.size.width;
      final RelativeRect position = new RelativeRect.fromRect(
        new Rect.fromPoints(
          textFieldRenderBox.localToGlobal(
              textFieldRenderBox.size.bottomLeft(Offset.zero),
              ancestor: overlay),
          textFieldRenderBox.localToGlobal(
              textFieldRenderBox.size.bottomRight(Offset.zero),
              ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );

      listSuggestionsEntry = new OverlayEntry(builder: (context) {
        return new Positioned(
            top: position.top,
            left: position.left,
            child: new Container(
                width: width,
                height: _focus.hasFocus ? suggestionBoxHeight : 0.0,
                child: new Card(
                    child: new ListView(
                  shrinkWrap: true,
                  children: filteredSuggestions.map((suggestion) {
                    return new Row(children: [
                      new Expanded(
                          child: new InkWell(
                              child: itemBuilder(context, suggestion),
                              onTap: () {
                                setState(() {
                                  if (submitOnSuggestionTap) {
                                    String newText = suggestion.toString();
                                    textField.focusNode.unfocus();
                                    textSubmitted(newText);
                                    if (clearOnSubmit) {
                                      clear();
                                    }
                                  } else {
                                    String newText = suggestion.toString();
                                    textField.controller.text = newText;
                                    textChanged(newText);
                                  }
                                });
                              }))
                    ]);
                  }).toList(),
                ))));
      });
      Overlay.of(context).insert(listSuggestionsEntry);
    }

    filteredSuggestions = getSuggestions(
        suggestions, itemSorter, itemFilter, suggestionsAmount, query);
        suggestionBoxHeight = updateSuggestionBoxHeight();
    listSuggestionsEntry.markNeedsBuild();
  }

  List<T> getSuggestions(List<T> suggestions, Comparator<T> sorter,
      Filter<T> filter, int maxAmount, String query) {

    suggestions.sort(sorter);
    suggestions = suggestions.where((item) => filter(item, query)).toList();
    if (suggestions.length > maxAmount) {
      suggestions = suggestions.sublist(0, maxAmount);
    }
    return suggestions;
  }

  @override
    void initState() {
      // TODO: implement initState
      super.initState();
      _focus.addListener(() {
        setState(() {
                });
      });
    }

  @override
  Widget build(BuildContext context) {
    return textField;
  }

  double updateSuggestionBoxHeight() {
    if (filteredSuggestions.length < 6) {
      return filteredSuggestions.length * 100.0;
    } else 
    return 200.0;
  }
}
