import '../models/blind_tiger_models.dart';

enum PaymentResult { success, failed, cancelled }

class PaymentService {
  Future<PaymentResult> processPayment({
    required PaymentMethod method,
    required int amount,
    dynamic package,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return PaymentResult.success;
  }
}
