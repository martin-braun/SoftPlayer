import Foundation
import Combine
import SwiftUI
import SpotifyWebAPI
import RegularExpressions
import Logging

struct PlaylistsScrollView: View {
    
    private typealias RatedPlaylist = (
        playlist: Playlist<PlaylistsItemsReference>,
        rating: Double
    )
    
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var playerManager: PlayerManager
    @EnvironmentObject var spotify: Spotify

    @Binding var isShowingPlaylistsView: Bool
    
    @AppStorage("onlyShowMyPlaylists") var onlyShowMyPlaylists = false
    
    @State private var searchText = ""
    @State private var selectedPlaylistURI: String? = nil
    @State private var searchFieldIsFocused = false
    
    @State private var playPlaylistCancellable: AnyCancellable? = nil
    
    let highlightAnimation = Animation.linear(duration: 0.1)
    let searchFieldId = "search field"
    
    var filteredPlaylists:
        [(offset: Int, element: Playlist<PlaylistsItemsReference>)] {
        
        let currentUserId = self.playerManager.currentUser?.id
        
        if searchText.strip().isEmpty {
            return Array(
                self.playerManager.playlistsSortedByLastModifiedDate
                    .filter { playlist in
                        if onlyShowMyPlaylists, let userId = playlist.owner?.id,
                                userId != currentUserId {
                            return false
                        }
                        return true
                    }
                    .enumerated()
            )
        }
        
        let lowerCasedSearch = searchText.lowercased()
        let searchWords = lowerCasedSearch.words
        
        let playlists = self.playerManager.playlistsSortedByLastModifiedDate
            .compactMap { playlist -> RatedPlaylist? in
                
                if onlyShowMyPlaylists, let userId = playlist.owner?.id,
                        userId != currentUserId {
                    return nil
                }
                
                let lowerCasedPlaylistName = playlist.name.lowercased()
                if lowerCasedSearch == lowerCasedPlaylistName {
                    return (playlist: playlist, rating: .infinity)
                }
                
                var rating: Double = 0
                if try! lowerCasedPlaylistName.regexMatch(
                    lowerCasedSearch,
                    regexOptions: [.ignoreMetacharacters]
                ) != nil {
                    rating += Double(lowerCasedSearch.count)
                }
                
                for searchWord in searchWords {
                    if try! lowerCasedPlaylistName.regexMatch(
                        searchWord,
                        regexOptions: [.ignoreMetacharacters]
                    ) != nil {
                        rating += Double(searchWord.count)
                    }
                }
                
                if rating == 0 {
                    return nil
                }
                
                return (playlist: playlist, rating: rating)
                
            }
            .sorted { lhs, rhs in
                lhs.rating > rhs.rating
            }
            .map(\.playlist)
            .enumerated()
        
        return Array(playlists)
        
        
    }
    
    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                HStack {
                    FocusableTextField(
                        text: $searchText,
                        isFirstResponder: $searchFieldIsFocused,
                        onCommit: searchFieldDidCommit,
                        receiveKeyEvent: receiveSearchFieldKeyEvent
                    )
                    .touchBar(content: PlayPlaylistsTouchBarView.init)
                    .padding(.leading, 6)
                    .padding(.trailing, -5)
                    
                    filterMenuView
                        .padding(.trailing, 5)
                }
                .padding(.top, 10)
                .padding(.bottom, -7)
                .id(searchFieldId)
                
                LazyVStack {
                    
                    ForEach(
                        self.filteredPlaylists,
                        id: \.element.uri
                    ) { playlist in
                        PlaylistsCellView(
                            playlist: playlist.element,
                            isSelected: selectedPlaylistURI == playlist.element.uri
                        )
                        .if(playlist.offset == 0) {
                            $0.padding(.top, 10)
                        }
                        .id(playlist.offset)
                    }
                    
                }
                
                Spacer()
                    .frame(height: 8)
                
            }
            .background(
                KeyEventHandler { event in
                    _ = self.receiveKeyEvent(event, scrollView: scrollView)
                }
                .touchBar(content: PlayPlaylistsTouchBarView.init)
            )
            .onAppear {
//                if !ProcessInfo.processInfo.isPreviewing {
                    scrollView.scrollTo(0, anchor: .top)
//                }
            }
            .onChange(of: searchText) { text in
                scrollView.scrollTo(searchFieldId, anchor: .top)
            }
            
        }
        
    }
    
    var filterMenuView: some View {
        Menu {
            Button(action: {
                self.onlyShowMyPlaylists.toggle()
            }, label: {
                HStack {
                    if onlyShowMyPlaylists {
                        Image(systemName: "checkmark")
                    }
                    Text("Only Show My Playlists ⌘M")
                }
            })
        } label: {
            Image(systemName: "line.horizontal.3.decrease.circle.fill")
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .help("Filters")
        .frame(width: 30)
    }

    func receiveSearchFieldKeyEvent(_ event: NSEvent) -> Bool {
        print("receiveSearchFieldKeyEvent: \(event)")
        return receiveKeyEvent(event, scrollView: nil)
    }
    
    /// Returns `true` if the key event was handled; else, `false`.
    func receiveKeyEvent(_ event: NSEvent, scrollView: ScrollViewProxy?) -> Bool {

        print("PlaylistsScrollView key event: \(event)")

        let characters = event.charactersIgnoringModifiers
        
        if event.modifierFlags.contains(.command) {
            if event.keyCode == 123 {
                self.playerManager.previousTrackOrSeekBackwards()
                return true
            }
            else if event.keyCode == 49 {
                self.playerManager.playPause()
                return true
            }
            else if event.keyCode == 124 {
                self.playerManager.nextTrackOrSeekForwards()
                return true
            }
            else if event.keyCode == 126 {  // up arrow
                let newSoundVolume = Int(
                    max(0, self.playerManager.soundVolume - 10)
                )
                self.playerManager.player.setSoundVolume?(
                    newSoundVolume
                )
            }
            else if event.keyCode == 125 {  // down arrow
                let newSoundVolume = Int(
                    min(100, self.playerManager.soundVolume + 10)
                )
                self.playerManager.player.setSoundVolume?(
                    newSoundVolume
                )
            }
            else if let characters = characters {
                switch characters {
                    case "k":
                        self.playerManager.playPause()
                    case "r":
                        self.playerManager.cycleRepeatMode()
                    case "s":
                        self.playerManager.toggleShuffle()
                    case "m":
                        self.onlyShowMyPlaylists.toggle()
                    case ",":
                        let appDelegate = NSApplication.shared.delegate
                            as! AppDelegate
                        appDelegate.openSettingsWindow()
                    default:
                        return false
                }
                return true
            }
        }
        // return or enter key
        else if [76, 36].contains(event.keyCode) {
            self.searchFieldDidCommit()
            return true
        }
        else if let scrollView = scrollView,
                event.specialKey == nil,
                let character = characters {
            print("charactersIgnoringModifiers: '\(character)'")
            print("PlaylistsScrollView receiveKeyEvent: '\(character)'")
            print(event)

            self.searchFieldIsFocused = true
            self.searchText += character
            print("scrolling to search field")
            scrollView.scrollTo(searchFieldId, anchor: .top)
            return true
        }
        return false
    }

    func searchFieldDidCommit() {
        print("onSearchFieldCommit")
        guard isShowingPlaylistsView else {
            print("skipping because not presented")
            return
        }
        if let firstPlaylist = self.filteredPlaylists.first?.element {
            withAnimation(highlightAnimation) {
                self.selectedPlaylistURI = firstPlaylist.uri
            }
            print("playing playlist \(firstPlaylist.name)")
            self.playPlaylist(firstPlaylist)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(highlightAnimation) {
                    self.selectedPlaylistURI = nil
                }
            }
        }
        else {
            withAnimation(highlightAnimation) {
                self.selectedPlaylistURI = nil
            }
        }
    }

    func playPlaylist(_ playlist: Playlist<PlaylistsItemsReference>) {
        self.playPlaylistCancellable = self.playerManager
            .playPlaylist(playlist)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    let alertTitle = #"Couldn't play "\#(playlist.name)""#
                    self.playerManager.presentNotification(
                        title: alertTitle,
                        message: error.localizedDescription
                    )
                    print("PlaylistsScrollView: \(alertTitle): \(error)")
                }
            })

    }

}

struct PlaylistsScrollView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView_Previews.previews
            .onAppear {
                PlayerView.debugShowPlaylistsView = true
            }
    }
}
