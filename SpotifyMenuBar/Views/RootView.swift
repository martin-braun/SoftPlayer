import Foundation
import Combine
import SwiftUI
import SpotifyWebAPI

struct RootView: View {
 
    fileprivate static var debugShowLoginView = false
    
    @EnvironmentObject var spotify: Spotify

    @State private var requestTokensCancellable: AnyCancellable? = nil
    
    var body: some View {
        VStack {
            if spotify.isAuthorized && !Self.debugShowLoginView {
                PlayerView()
            }
            else {
                LoginView()
            }
        }
        .frame(
            width: CGFloat(AppDelegate.popoverWidth),
            height: CGFloat(AppDelegate.popoverHeight)
        )
        .onReceive(
            spotify.redirectURLSubject,
            perform: handleRedirectURL(_:)
        )
        
    }
    
    func handleRedirectURL(_ url: URL) {

        Loggers.general.trace("LoginView received redirect URL: \(url)")
        
        self.spotify.isRetrievingTokens = true
        
        self.requestTokensCancellable = self.spotify.api.authorizationManager
            .requestAccessAndRefreshTokens(
                redirectURIWithQuery: url,
                codeVerifier: self.spotify.codeVerifier,
                state: self.spotify.authorizationState
            )
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: receiveRequestTokensCompletion(_:))
        
        self.spotify.generateNewAuthorizationParameters()

    }
    
    func receiveRequestTokensCompletion(
        _ completion: Subscribers.Completion<Error>
    ) {
        Loggers.general.trace("request tokens completion: \(completion)")
        self.spotify.isRetrievingTokens = false
        let alert = NSAlert()
        let alertTitle: String
        let alertMessage: String
        
        switch completion {
            case .finished:
                alertTitle =
                        "Successfully connected to your Spotify account"
                alertMessage = ""
                alert.alertStyle = .informational
            case .failure(let error):
                alert.alertStyle = .warning
                alertTitle =
                        "Could not Authorize with your Spotify account"
                
                if let authError = error as? SpotifyAuthorizationError,
                   authError.accessWasDenied {
                    alertMessage =
                        "You denied the authorization request (:"
                }
                else {
                    alertMessage = error.customizedLocalizedDescription
                }
        }

        alert.messageText = alertTitle
        alert.informativeText = alertMessage
        alert.runModal()
    }
    
    
}

struct RootView_Previews: PreviewProvider {
    
    static let playerManager = PlayerManager(spotify: Spotify())
    
    static var previews: some View {

        ForEach(ColorScheme.allCases, id: \.self) { colorScheme in
            RootView()
                .preferredColorScheme(colorScheme)
                .environmentObject(playerManager)
                .environmentObject(playerManager.spotify)
                .onAppear(perform: onAppear)
                .frame(
                    width: CGFloat(AppDelegate.popoverWidth),
                    height: CGFloat(AppDelegate.popoverHeight)
                )
        }
    }
    
    static func onAppear() {
//        RootView.debugShowLoginView = true
//        playerManager.spotify.isAuthorized = true
//        playerManager.spotify.isRetrievingTokens = false
    }
}
