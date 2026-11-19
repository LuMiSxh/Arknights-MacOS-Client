// SPDX-License-Identifier: MPL-2.0

import ArknightsInfrastructure

// Infrastructure imports no other target, so the application's transfer limits are applied here.
extension TransferRateEstimator {
	package init(clock: any Clock<Duration> = ContinuousClock()) {
		self.init(
			clock: clock,
			sampleInterval: AppConstants.Network.transferRateSampleInterval,
			stallTimeout: AppConstants.Network.transferRateStallTimeout,
			smoothingFactor: AppConstants.Network.transferRateSmoothingFactor
		)
	}
}

extension ProgressEmissionGate {
	package init(clock: any Clock<Duration>) {
		self.init(clock: clock, interval: AppConstants.Network.progressEmissionInterval)
	}
}
