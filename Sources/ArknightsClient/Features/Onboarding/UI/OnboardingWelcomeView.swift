// SPDX-License-Identifier: MPL-2.0

import SwiftUI

struct OnboardingWelcomeView: View {
	@Bindable var model: LauncherViewModel
	let updateState: OnboardingUpdateState
	let intelTranslationState: IntelTranslationState
	let rosettaInstallationState: RosettaInstallationState
	let retry: () -> Void
	let retryIntelTranslation: () -> Void
	let installRosetta: () -> Void

	var body: some View {
		OnboardingPage(
			title: L10n.string(OnboardingStrings.welcomeTitle),
			subtitle: L10n.string(OnboardingStrings.welcomeSubtitle),
			accentColor: model.accentColor
		) {
			SettingsPanel(
				title: L10n.string(OnboardingStrings.languagePanel),
				systemImage: "globe"
			) {
				SettingsActionRow(
					title: L10n.string(OnboardingStrings.language),
					detail: L10n.string(OnboardingStrings.languageDetail)
				) {
					GlassMenuPicker(
						selection: $model.appLanguage,
						options: AppLanguage.allCases.map {
							($0, L10n.string(OnboardingStrings.appLanguage($0)))
						},
						accentColor: model.accentColor
					)
				}
			}

			SettingsPanel(title: L10n.string(statusTitle), systemImage: statusImage) {
				switch updateState {
				case .checking:
					HStack(spacing: 12) {
						ProgressView()
						Text(OnboardingStrings.releaseCheck)
							.foregroundStyle(.secondary)
					}
				case .current:
					Label(
						OnboardingStrings.launcherCurrent,
						systemImage: "checkmark.circle.fill"
					)
					.foregroundStyle(model.accentColor)
				case .updateRequired(let release):
					VStack(alignment: .leading, spacing: 8) {
						Text(OnboardingStrings.versionAvailable(release.version))
							.bold()
						Text(OnboardingStrings.updateDetail)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				case .checkFailed:
					VStack(alignment: .leading, spacing: 10) {
						Text(OnboardingStrings.updateCheckFailedDetail)
							.foregroundStyle(.secondary)
						CapsuleActionButton(
							title: L10n.string(OnboardingStrings.tryAgain),
							systemImage: "arrow.clockwise",
							tone: .accent(model.accentColor), action: retry
						)
					}
				}
			}

			if updateState.allowsSetup {
				SettingsPanel(
					title: L10n.string(OnboardingStrings.compatibilityPanel),
					systemImage: translationImage
				) {
					switch intelTranslationState {
					case .waitingForLauncherCheck:
						Text(OnboardingStrings.compatibilityWaiting)
							.foregroundStyle(.secondary)
					case .checking:
						HStack(spacing: 12) {
							ProgressView()
							Text(OnboardingStrings.compatibilityChecking)
								.foregroundStyle(.secondary)
						}
					case .available:
						Label(
							OnboardingStrings.compatibilityAvailable,
							systemImage: "checkmark.circle.fill"
						)
						.foregroundStyle(model.accentColor)
					case .rosettaMissing:
						OnboardingRosettaRecoveryView(
							installationState: rosettaInstallationState,
							accentColor: model.accentColor,
							install: installRosetta,
							checkAgain: retryIntelTranslation
						)
					case .gameTestModeEnabled:
						VStack(alignment: .leading, spacing: 10) {
							Text(OnboardingStrings.compatibilityGameTestMode)
								.foregroundStyle(.secondary)
								.fixedSize(horizontal: false, vertical: true)
							Text("sudo game-test-tool disable")
								.font(.callout.monospaced())
								.textSelection(.enabled)
							CapsuleActionButton(
								L10n.string(OnboardingStrings.checkAgain),
								systemImage: "arrow.clockwise",
								tone: .accent(model.accentColor),
								action: retryIntelTranslation
							)
						}
					case .unavailable:
						VStack(alignment: .leading, spacing: 10) {
							Text(OnboardingStrings.compatibilityUnavailable)
								.foregroundStyle(.secondary)
								.fixedSize(horizontal: false, vertical: true)
							CapsuleActionButton(
								L10n.string(OnboardingStrings.checkAgain),
								systemImage: "arrow.clockwise",
								tone: .accent(model.accentColor),
								action: retryIntelTranslation
							)
						}
					case .unsupportedOS:
						Text(OnboardingStrings.compatibilityUnsupported)
							.foregroundStyle(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}

			SettingsPanel(
				title: L10n.string(OnboardingStrings.nextTitle),
				systemImage: "point.forward.to.point.capsulepath"
			) {
				Text(OnboardingStrings.nextDetail)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private var statusTitle: LocalizedStringResource {
		OnboardingStrings.statusTitle(updateState)
	}

	private var statusImage: String {
		switch updateState {
		case .checking: "arrow.trianglehead.2.clockwise"
		case .current: "checkmark.shield"
		case .updateRequired: "arrow.down.app"
		case .checkFailed: "wifi.exclamationmark"
		}
	}

	private var translationImage: String {
		switch intelTranslationState {
		case .waitingForLauncherCheck, .checking: "hourglass"
		case .available: "cpu"
		case .rosettaMissing, .gameTestModeEnabled, .unavailable, .unsupportedOS:
			"exclamationmark.triangle"
		}
	}
}
