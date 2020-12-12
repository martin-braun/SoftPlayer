import Foundation
import Combine
import SwiftUI
import SpotifyWebAPI

struct TouchBarPlaylistButton: View {
    
    @EnvironmentObject var playerManager: PlayerManager
    @EnvironmentObject var spotify: Spotify
    
    let playlist: Playlist<PlaylistsItemsReference>

    init(playlist: Playlist<PlaylistsItemsReference>) {
        self.playlist = playlist
    }
    
    @State private var isMakingRequestToPlayPlaylist = false
    
    @State private var alertIsPresented = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var playPlaylistCancellable: AnyCancellable? = nil
    
    var playlistImage: Image {
        if let identifier = try? SpotifyIdentifier(uri: playlist.uri),
                let image = self.playerManager.image(for: identifier) {
            return image
        }
        return Image(.spotifyAlbumPlaceholder)
    }
    
    var body: some View {
        
        Button(action: {
            self.playPlaylist(playlist)
        }, label: {
            playlistImage
                .resizable()
                .aspectRatio(contentMode: .fill)
                .colorMultiply(Color(#colorLiteral(red: 0.4762042937, green: 0.4762042937, blue: 0.4762042937, alpha: 1)))
                .blur(radius: 2)
                .frame(width: 133, height: 28)
                .cornerRadius(3)
                .overlay(
                    Text(playlist.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .fixedSize(horizontal: false, vertical: true)
                )
        })
        .buttonStyle(PlainButtonStyle())
        .alert(isPresented: $alertIsPresented) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage)
            )
        }

    }
    
    func playPlaylist(_ playlist: Playlist<PlaylistsItemsReference>) {
        
        self.isMakingRequestToPlayPlaylist = true
        
        let playbackRequest = PlaybackRequest(
            context: .contextURI(playlist),
            offset: nil
        )
        
        self.playerManager.playlistsLastPlayedDates[playlist.uri] = Date()
        
        self.playPlaylistCancellable = self.spotify.api
            .getAvailableDeviceThenPlay(playbackRequest)
            .receive(on: RunLoop.main)
            .handleAuthenticationError(spotify: self.spotify)
            .sink(
                receiveCompletion: { completion in
                    self.isMakingRequestToPlayPlaylist = false
                    if case .failure(let error) = completion {
                        self.alertTitle =
                            #"Couldn't play "\#(playlist.name)""#
                        self.alertMessage = error.localizedDescription
                        self.alertIsPresented = true
                        print("\(alertTitle): \(error)")
                    }
                },
                receiveValue: { }
            )

    }

}

struct TouchBarPlaylistButton_Previews: PreviewProvider {
    static var previews: some View {
        PlayPlaylistsTouchBarView_Previews.previews
    }
}