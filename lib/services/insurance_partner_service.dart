class InsurancePartnerResult {
  const InsurancePartnerResult({required this.status, this.partnerReference});

  final String status;
  final String? partnerReference;
}

abstract interface class InsurancePartner {
  Future<InsurancePartnerResult> createIncident({
    required String incidentType,
    required bool consentToShare,
    String? reportId,
  });
}

class DemoInsurancePartner implements InsurancePartner {
  const DemoInsurancePartner();

  @override
  Future<InsurancePartnerResult> createIncident({
    required String incidentType,
    required bool consentToShare,
    String? reportId,
  }) async {
    return InsurancePartnerResult(
      status: consentToShare ? 'stored' : 'draft',
      partnerReference: consentToShare
          ? 'BT-INS-${DateTime.now().millisecondsSinceEpoch}'
          : null,
    );
  }
}
