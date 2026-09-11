import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitialState extends AuthState {
  const AuthInitialState();
}

class AuthLoadingState extends AuthState {
  const AuthLoadingState();
}

class UnauthenticatedState extends AuthState {
  const UnauthenticatedState();
}

class OtpSentState extends AuthState {
  final String phone;
  final String? message;
  final String? otpCode;

  const OtpSentState({required this.phone, this.message, this.otpCode});

  @override
  List<Object?> get props => [phone, message, otpCode];
}

class AuthenticatedState extends AuthState {
  final String phone;
  final String? customerId;
  final String? name;
  final String? token;
  final bool isProfileCompleted;

  const AuthenticatedState({
    required this.phone,
    this.customerId,
    this.name,
    this.token,
    this.isProfileCompleted = true,
  });

  @override
  List<Object?> get props => [phone, customerId, name, token, isProfileCompleted];
}

class AuthErrorState extends AuthState {
  final String message;

  const AuthErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}
