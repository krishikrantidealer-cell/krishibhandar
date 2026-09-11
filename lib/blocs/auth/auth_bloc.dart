import 'package:flutter_bloc/flutter_bloc.dart';
import '../../controller/auth_controller.dart';
import '../../services/api_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthInitialState()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SendOtpEvent>(_onSendOtp);
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<SignOutEvent>(_onSignOut);

    add(const CheckAuthStatusEvent());
  }

  Future<void> _onCheckAuthStatus(
      CheckAuthStatusEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoadingState());
    try {
      final loggedIn = await AuthController.isLoggedIn();
      if (loggedIn) {
        final phone = await AuthController.getSavedPhone() ?? '';
        final customerId = await AuthController.getCustomerId();
        final name = await AuthController.getSavedName();
        final token = await ApiService.getAuthToken();
        final isCompleted = await AuthController.isProfileCompleted();
        emit(AuthenticatedState(
          phone: phone,
          customerId: customerId,
          name: name,
          token: token,
          isProfileCompleted: isCompleted,
        ));
      } else {
        emit(const UnauthenticatedState());
      }
    } catch (_) {
      emit(const UnauthenticatedState());
    }
  }

  Future<void> _onSendOtp(SendOtpEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoadingState());
    try {
      final res = await AuthController.sendOtp(phone: event.phone);
      if (res.success) {
        final code = res.data?['code']?.toString() ?? res.data?['otp']?.toString();
        emit(OtpSentState(
          phone: event.phone,
          message: res.message ?? 'OTP sent successfully',
          otpCode: code,
        ));
      } else {
        emit(AuthErrorState(
            message: res.message ?? 'Failed to send OTP. Please try again.'));
      }
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  Future<void> _onVerifyOtp(
      VerifyOtpEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoadingState());
    try {
      final res = await AuthController.verifyOtp(
        phone: event.phone,
        otp: event.otp,
      );

      if (res.success) {
        final phone = await AuthController.getSavedPhone() ?? event.phone;
        final customerId = await AuthController.getCustomerId();
        final name = await AuthController.getSavedName();
        final token = await ApiService.getAuthToken();
        final isCompleted = await AuthController.isProfileCompleted();

        emit(AuthenticatedState(
          phone: phone,
          customerId: customerId,
          name: name,
          token: token,
          isProfileCompleted: isCompleted,
        ));
      } else {
        emit(AuthErrorState(
            message: res.message ?? 'Invalid OTP. Please try again.'));
      }
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  Future<void> _onSignOut(SignOutEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoadingState());
    try {
      await AuthController.signOut();
    } catch (_) {}
    emit(const UnauthenticatedState());
  }
}
