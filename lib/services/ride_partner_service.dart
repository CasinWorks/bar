class RidePartnerResult {
  const RidePartnerResult({
    required this.provider,
    required this.status,
    this.externalUrl,
    this.partnerReference,
  });

  final String provider;
  final String status;
  final String? externalUrl;
  final String? partnerReference;
}

abstract interface class RidePartner {
  Future<RidePartnerResult> requestRide({
    required String pickupBranch,
    required String destination,
  });
}

class GrabDeepLinkPartner implements RidePartner {
  const GrabDeepLinkPartner();

  @override
  Future<RidePartnerResult> requestRide({
    required String pickupBranch,
    required String destination,
  }) async {
    final query = Uri.encodeComponent('$pickupBranch to $destination');
    return RidePartnerResult(
      provider: 'grab',
      status: 'opened_partner',
      externalUrl:
          'https://grab.onelink.me/2695613898?pid=blind_tiger&c=ride_assist&af_web_dp=https%3A%2F%2Fwww.grab.com%2Fph%2Ftransport%2F&q=$query',
    );
  }
}

class DemoRidePartner implements RidePartner {
  const DemoRidePartner();

  @override
  Future<RidePartnerResult> requestRide({
    required String pickupBranch,
    required String destination,
  }) async {
    return RidePartnerResult(
      provider: 'demo',
      status: 'staff_notified',
      partnerReference: 'DEMO-RIDE-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
