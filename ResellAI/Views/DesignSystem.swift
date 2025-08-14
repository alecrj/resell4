//
//  DesignSystem.swift
//  ResellAI
//
//  App Design System
//

import SwiftUI

// MARK: - DESIGN SYSTEM
struct DesignSystem {
    // Colors
    static let neonGreen = Color(red: 0.22, green: 1.0, blue: 0.08) // #39FF14
    static let background = Color.white
    static let primary = Color.black
    static let secondary = Color.gray
    static let tertiary = Color(white: 0.9)
    
    // Typography
    static let titleFont = Font.system(size: 28, weight: .bold, design: .default)
    static let headlineFont = Font.system(size: 20, weight: .semibold, design: .default)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .default)
    static let captionFont = Font.system(size: 14, weight: .medium, design: .default)
    
    // Spacing
    static let spacing1: CGFloat = 8
    static let spacing2: CGFloat = 16
    static let spacing3: CGFloat = 24
    static let spacing4: CGFloat = 32
    
    // Corner Radius
    static let cornerRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 16
}
