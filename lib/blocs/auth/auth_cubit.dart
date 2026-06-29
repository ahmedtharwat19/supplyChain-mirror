import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());

  Future<void> signUp({required String email, required String password}) async {
    emit(AuthLoading());
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      emit(AuthSuccess());
    } on FirebaseAuthException catch (e) {
      String error = 'حدث خطأ أثناء التسجيل';
      if (e.code == 'email-already-in-use') {
        error = 'البريد الإلكتروني مستخدم بالفعل';
      } else if (e.code == 'invalid-email') {
        error = 'البريد الإلكتروني غير صالح';
      } else if (e.code == 'weak-password') {
        error = 'كلمة المرور ضعيفة جداً';
      }
      emit(AuthFailure(error));
    }
  }

  Future<void> login({required String email, required String password}) async {
    emit(AuthLoading());
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      emit(AuthSuccess());
    } on FirebaseAuthException catch (e) {
      String error = 'فشل تسجيل الدخول';
      if (e.code == 'user-not-found') {
        error = 'المستخدم غير موجود';
      } else if (e.code == 'wrong-password') {
        error = 'كلمة المرور غير صحيحة';
      }
      emit(AuthFailure(error));
    }
  }
}
