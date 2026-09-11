import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../controller/constants.dart';
import 'language_event.dart';
import 'language_state.dart';

class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  LanguageBloc()
      : super(LanguageState(locale: Constants.languageController.locale)) {
    on<LoadLanguageEvent>(_onLoadLanguage);
    on<ChangeLanguageEvent>(_onChangeLanguage);
  }

  void _onLoadLanguage(LoadLanguageEvent event, Emitter<LanguageState> emit) {
    emit(LanguageState(locale: Constants.languageController.locale));
  }

  void _onChangeLanguage(
      ChangeLanguageEvent event, Emitter<LanguageState> emit) {
    Constants.languageController.setLocale(event.locale.languageCode);
    emit(LanguageState(locale: event.locale));
  }
}
