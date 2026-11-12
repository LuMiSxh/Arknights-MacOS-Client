// SPDX-License-Identifier: MPL-2.0

/// A runtime patch the user can turn off. Every case is on by default; the runtime gates it
/// with one `LMISXH_AKMOCL_*` variable. The Bilibili, fullscreen, and cursor gates follow the
/// server or their own setting, so they are not listed.
package enum RuntimePatch: String, CaseIterable, Sendable {
	case aceImports
	case appContainer
	case winsock
	case menu
	case audio
	case aceTiming
	case aceDispatcher
	case aceRosetta
	case eflags
	case hybridThread

	/// The runtime lanes whose build contains the patch.
	package var lanes: Set<RuntimeLane> {
		switch self {
		case .aceImports, .appContainer, .winsock, .menu: [.x86, .arm]
		case .audio, .aceTiming, .aceDispatcher, .aceRosetta: [.x86]
		case .eflags, .hybridThread: [.arm]
		}
	}
}
