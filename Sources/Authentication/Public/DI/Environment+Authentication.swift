import SwiftUI

extension EnvironmentValues {
    @Entry public var authenticationUseCase: AuthenticationUseCase? = nil
}

public extension View {
    func authenticationUseCase(_ authenticationUseCase: AuthenticationUseCase) -> some View {
        environment(\.authenticationUseCase, authenticationUseCase)
    }
}
