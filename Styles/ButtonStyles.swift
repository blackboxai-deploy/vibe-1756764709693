import SwiftUI

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isDisabled {
                        Color.gray.opacity(0.6)
                    } else {
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Secondary Button Style
struct SecondaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(isDisabled ? .secondary : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDisabled ? .gray.opacity(0.2) : .regularMaterial)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button Style
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.red, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Compact Button Style
struct CompactButtonStyle: ButtonStyle {
    var color: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style
struct IconButtonStyle: ButtonStyle {
    var backgroundColor: Color = .clear
    var foregroundColor: Color = .primary
    var size: CGFloat = 44
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(foregroundColor)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(backgroundColor)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Card Button Style
struct CardButtonStyle: ButtonStyle {
    var backgroundColor: Color = .clear
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(backgroundColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Floating Action Button Style
struct FloatingActionButtonStyle: ButtonStyle {
    var color: Color = .purple
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Pill Button Style
struct PillButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var color: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(color, lineWidth: isSelected ? 0 : 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Navigation Button Style
struct NavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .background(Color.clear)
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .opacity(configuration.isPressed ? 1 : 0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Button Style Extensions
extension Button {
    func primaryStyle(disabled: Bool = false) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isDisabled: disabled))
            .disabled(disabled)
    }
    
    func secondaryStyle(disabled: Bool = false) -> some View {
        self.buttonStyle(SecondaryButtonStyle(isDisabled: disabled))
            .disabled(disabled)
    }
    
    func destructiveStyle() -> some View {
        self.buttonStyle(DestructiveButtonStyle())
    }
    
    func compactStyle(color: Color = .blue) -> some View {
        self.buttonStyle(CompactButtonStyle(color: color))
    }
    
    func iconStyle(backgroundColor: Color = .clear, foregroundColor: Color = .primary, size: CGFloat = 44) -> some View {
        self.buttonStyle(IconButtonStyle(backgroundColor: backgroundColor, foregroundColor: foregroundColor, size: size))
    }
    
    func cardStyle(backgroundColor: Color = .blue) -> some View {
        self.buttonStyle(CardButtonStyle(backgroundColor: backgroundColor))
    }
    
    func floatingStyle(color: Color = .purple) -> some View {
        self.buttonStyle(FloatingActionButtonStyle(color: color))
    }
    
    func pillStyle(isSelected: Bool = false, color: Color = .blue) -> some View {
        self.buttonStyle(PillButtonStyle(isSelected: isSelected, color: color))
    }
    
    func navigationStyle() -> some View {
        self.buttonStyle(NavigationButtonStyle())
    }
}