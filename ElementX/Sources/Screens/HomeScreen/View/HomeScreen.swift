//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import Sentry
import SwiftUI

struct HomeScreen: View {
    @Environment(\.isInSidebar) private var isInSidebar
    
    @ObservedObject var context: HomeScreenViewModel.Context
    
    @State private var scrollViewAdapter = ScrollViewAdapter()
    
    @Namespace private var navigationTransitionNamespace
    private enum NavigationTransitionSourceID {
        case spaceFilters
    }
    
    var body: some View {
        HomeScreenContent(context: context, scrollViewAdapter: scrollViewAdapter)
            .alert(item: $context.alertInfo)
            .alert(item: $context.leaveRoomAlertItem,
                   actions: leaveRoomAlertActions,
                   message: leaveRoomAlertMessage)
            .navigationTitle(context.viewState.hasSimplifiedHeader ? "" : title)
            .navigationBarTitleDisplayMode(Compound.supportsGlass ? .inline : .automatic)
            .toolbar { toolbar }
            // The editor role leading aligns the title, the large space title doesn't need it and it would stick to the rooms pushed above.
            .toolbarRole(Compound.supportsGlass && !context.viewState.hasSimplifiedHeader ? .editor : .automatic)
            .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
            .track(screen: .Home)
            .toolbarBloom(hasSearchBar: context.viewState.isRoomListSearchEnabled)
            .sentryTrace("\(Self.self)")
            .sheet(item: $context.spaceFiltersViewModel) { vm in
                ChatsSpaceFiltersScreen(context: vm.context)
                    .navigationTransition(.zoom(sourceID: NavigationTransitionSourceID.spaceFilters,
                                                in: navigationTransitionNamespace))
            }
            .sheet(isPresented: $context.isPresentingMultiAccountAnnouncement) {
                MultiAccountAnnouncementView(context: context)
                    .onAppear { context.send(viewAction: .multiAccountAnnouncementAppeared) }
            }
            .onAppear { context.send(viewAction: .screenAppeared) }
    }
    
    // MARK: - Private
    
    private var title: String {
        if let selectedSpace = context.viewState.selectedSpaceFilter {
            selectedSpace.room.name
        } else {
            L10n.screenRoomlistMainSpaceTitle
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if context.viewState.hasSimplifiedHeader {
            largeTitleToolbar
        } else {
            defaultToolbar
        }
    }
    
    /// Leveragers: the profile picture next to the app name and its signature, like our Voice app, and the new room button.
    @ToolbarContentBuilder
    private var largeTitleToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 10) {
                settingsButton
                    .buttonStyle(.borderless)
                
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(InfoPlistReader.main.bundleDisplayName)
                        .font(.custom("Sora", size: 22, relativeTo: .title2).weight(.bold))
                        .foregroundStyle(.compound.textPrimary)
                    
                    Text(UntranslatedL10n.screenRoomlistBrandTagline)
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                }
                .fixedSize()
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
        }
        // The avatar is already round, a glass circle around it would crop it.
        .backportSharedBackgroundVisibility(.hidden)
        
        ToolbarItem(placement: .primaryAction) {
            if #available(iOS 26, *) {
                newRoomButton
            } else {
                newRoomButton
                    .buttonStyle(.compound(.super, size: .toolbarIcon))
            }
        }
        
        if #available(iOS 26, *), context.viewState.isRoomListSearchEnabled {
            // The room list search field, floating at the bottom of the screen.
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
        }
    }
    
    @ToolbarContentBuilder
    private var defaultToolbar: some ToolbarContent {
        ToolbarItem(placement: Compound.supportsGlass ? .title : .navigationBarLeading) {
            HStack(spacing: isInSidebar ? 8 : 12) {
                // The settings button is inside the title on iOS 26 to workaround a
                // weird liquid glass transition when pushing/popping a room.
                settingsButton
                    .buttonStyle(.borderless)
                
                if #available(iOS 26, *) {
                    if context.viewState.spaceMenuFilters.isEmpty {
                        titleText
                    } else {
                        Menu {
                            spaceMenuButtons
                        } label: {
                            HStack(spacing: 4) {
                                titleText
                                    .truncationMode(.tail)
                                CompoundIcon(\.chevronDown, size: .small, relativeTo: .compound.headingLGBold)
                                    .foregroundStyle(.compound.iconSecondary)
                            }
                            // Toolbar titles aren't width constrained: keep long space names clear of the buttons.
                            .frame(maxWidth: 240, alignment: .leading)
                        }
                        .menuIndicator(.hidden) // Our own chevron sits next to the title.
                        .accessibilityHint(L10n.screenHomeTabSpaces)
                    }
                }
            }
        }
        .backportSharedBackgroundVisibility(.hidden)
        
        ToolbarItem(placement: .primaryAction) {
            if #available(iOS 26, *) {
                newRoomButton
            } else {
                newRoomButton
                    .buttonStyle(.compound(.super, size: .toolbarIcon))
            }
        }
        
        if context.viewState.shouldShowSpaceFilters {
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            
            ToolbarItem(placement: .primaryAction) {
                SpaceFiltersButton(selected: context.viewState.selectedSpaceFilter != nil) {
                    context.send(viewAction: .spaceFilters)
                }
                .matchedTransitionSource(id: NavigationTransitionSourceID.spaceFilters,
                                         in: navigationTransitionNamespace)
            }
        }
    }
    
    private var titleText: some View {
        Text(title)
            .font(isInSidebar ? .compound.bodyLGSemibold : .compound.headingLGBold)
            .foregroundStyle(.compound.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(isInSidebar ? 1 : 0.6) // Allow scaling down to bodyLG if needed.
    }
    
    private var spaceMenuButtons: some View {
        ForEach(context.viewState.spaceMenuFilters) { filter in
            Button {
                context.send(viewAction: .selectSpaceFilter(filter))
            } label: {
                if filter.id == context.viewState.selectedSpaceFilter?.id {
                    Label(filter.room.name, icon: \.check)
                } else {
                    Text(filter.room.name)
                }
            }
        }
    }
    
    private var settingsButton: some View {
        AvatarSettingsButton(userProfile: context.viewState.userProfile,
                             mediaProvider: context.mediaProvider) {
            context.send(viewAction: .showSettings)
        }
    }
    
    @ViewBuilder
    private var newRoomButton: some View {
        switch context.viewState.roomListMode {
        case .empty, .rooms:
            Button {
                context.send(viewAction: .startChat)
            } label: {
                CompoundIcon(\.plus)
            }
            .accessibilityLabel(L10n.actionStartChat)
            .accessibilityIdentifier(A11yIdentifiers.homeScreen.startChat)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func leaveRoomAlertActions(_ item: LeaveRoomAlertItem) -> some View {
        Button(item.cancelTitle, role: .cancel) { }
        Button(item.confirmationTitle, role: .destructive) {
            context.send(viewAction: .confirmLeaveRoom(roomIdentifier: item.roomID))
        }
    }
    
    private func leaveRoomAlertMessage(_ item: LeaveRoomAlertItem) -> some View {
        Text(item.subtitle)
    }
    
    private struct SpaceFiltersButton: View {
        @Environment(\.isInSidebar) private var isInSidebar
        
        var selected = false
        var action: () -> Void
        
        /// Design prefers the custom style over the system's styling of a Toggle within a toolbar,
        /// however Glass isn't supported for toolbar buttons in the sidebar on iPadOS 26 (likely due
        /// to glass on glass being discouraged by Apple), so we need to handle our styling accordingly.
        var shouldUseGlassButtonStyle: Bool {
            !isInSidebar
        }
        
        var body: some View {
            if #available(iOS 26, *), shouldUseGlassButtonStyle {
                if selected {
                    content
                        .backportButtonStyleGlassProminent()
                        .tint(.compound.bgActionPrimaryRest)
                } else {
                    content
                }
            } else {
                if selected {
                    content
                        .buttonStyle(.compound(.primary, size: .toolbarIcon))
                } else {
                    content
                        .buttonStyle(.compound(.tertiary, size: .toolbarIcon))
                }
            }
        }
        
        private var content: some View {
            Button {
                action()
            } label: {
                CompoundIcon(\.filter)
            }
            .accessibilityLabel(L10n.screenRoomlistYourSpaces)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier(A11yIdentifiers.homeScreen.spaceFilters)
        }
    }
}

// MARK: - Previews

struct HomeScreen_Previews: PreviewProvider, TestablePreview {
    static let loadingViewModel = viewModel(.skeletons)
    static let emptyViewModel = viewModel(.empty)
    static let loadedViewModel = viewModel(.rooms)
    
    static var previews: some View {
        ElementNavigationStack {
            HomeScreen(context: loadingViewModel.context)
        }
        .snapshotPreferences(expect: loadingViewModel.context.$viewState.map { state in
            state.roomListMode == .skeletons
        })
        .previewDisplayName("Loading")
        
        ElementNavigationStack {
            HomeScreen(context: emptyViewModel.context)
        }
        .snapshotPreferences(expect: emptyViewModel.context.$viewState.map { state in
            state.roomListMode == .empty
        })
        .previewDisplayName("Empty")
        
        ElementNavigationStack {
            HomeScreen(context: loadedViewModel.context)
        }
        .snapshotPreferences(expect: loadedViewModel.context.$viewState.map { state in
            state.roomListMode == .rooms
        })
        .previewDisplayName("Loaded")
    }
    
    static func viewModel(_ mode: HomeScreenRoomListMode) -> HomeScreenViewModel {
        let userID = "@alice:example.com"
        
        let roomSummaryProviderState: RoomSummaryProviderMockConfigurationState = switch mode {
        case .awaitingCachedRooms, .skeletons:
            .loading
        case .empty:
            .loaded([])
        case .rooms:
            .loaded(.mockRooms)
        }
        
        let clientProxy = ClientProxyMock(.init(userID: userID,
                                                roomSummaryProvider: RoomSummaryProviderMock(.init(state: roomSummaryProviderState))))
        
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        
        return HomeScreenViewModel(userSession: userSession,
                                   availableSessionsPublisher: .init([.init(userSession: userSession)]),
                                   selectedRoomPublisher: CurrentValueSubject<String?, Never>(nil).asCurrentValuePublisher(),
                                   analyticsService: AnalyticsServiceMock(.init()),
                                   bugReportService: BugReportServiceMock(.init()),
                                   userIndicatorController: UserIndicatorControllerMock())
    }
}
