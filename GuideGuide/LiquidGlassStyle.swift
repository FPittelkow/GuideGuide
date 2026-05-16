//
//  LiquidGlassStyle.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import SwiftUI

extension View {
    func guideGlassSurface(cornerRadius: CGFloat = 20, shadow: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return self
            .background(.ultraThinMaterial, in: shape)
            .glassEffect(.regular, in: shape)
            .overlay {
                shape
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(shadow ? 0.10 : 0), radius: shadow ? 24 : 0, x: 0, y: shadow ? 12 : 0)
    }
}
