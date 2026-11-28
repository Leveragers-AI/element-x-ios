//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The full-screen "Update required" screen: no close button, the update is the only way past it.
struct AppUpdateBlockingScreen: View {
    let updateURL: URL
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Image(asset: Asset.Images.appLogo)
                        .accessibilityHidden(true)
                    
                    VStack(spacing: 8) {
                        Text(AppUpdateStrings.requiredTitle)
                            .font(.compound.headingLGBold)
                            .foregroundColor(.compound.textPrimary)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(AppUpdateStrings.requiredMessage)
                            .font(.compound.bodyLG)
                            .foregroundColor(.compound.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    
                    Button { openURL(updateURL) } label: {
                        Text(AppUpdateStrings.update)
                    }
                    .buttonStyle(.compound(.primary))
                }
                .padding(24)
                .readableFrame()
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            AuthenticationStartScreenBackgroundImage()
        }
    }
}

// MARK: - Previews

struct AppUpdateBlockingScreen_Previews: PreviewProvider {
    static var previews: some View {
        AppUpdateBlockingScreen(updateURL: "https://testflight.apple.com/join/zMWdSWBu")
    }
}
