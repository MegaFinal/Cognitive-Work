//
//  SeventhOnboardingView.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 25/08/26.
//

import SwiftUI

/// Seventh onboarding step, where the user picks the chores that are split
/// equally between every resident of the house.
///
/// Rooms are listed as collapsible sections. Tapping the chevron of a room
/// toggles ``RoomDTO/isExpanded`` for that room alone, revealing the chores
/// that can be marked through a `Toggle`. The trailing button advances to the
/// next step.
///
/// Spacing is derived from the container size reported by `GeometryReader`, so
/// the layout keeps its proportions across device sizes.
///
/// > Warning: Every room currently expands the same ``mockedChores`` array.
/// > Since ``ChoreDTO`` is a reference type, selecting a chore in one room also
/// > selects it in the others. Give each room its own list before replacing the
/// > mock with real data.
struct SelectChoresOnboardingView: View {

    // MARK: - Constants

    /// Layout values shared by the screen, kept here to avoid magic numbers.
    ///
    /// Ratio constants are multiplied by the width or height reported by
    /// `GeometryReader`; the remaining values are absolute, in points.
    private enum Layout {
        /// Font size of the screen title.
        static let titleFontSize: CGFloat = 32

        /// Font size of the explanatory subtitle.
        static let subtitleFontSize: CGFloat = 16

        /// Font size of each room name.
        static let roomNameFontSize: CGFloat = 24

        /// Font size of the chevron inside the advance button.
        static let advanceIconFontSize: CGFloat = 22

        /// Fraction of the container height used as the title top padding.
        static let titleTopRatio: CGFloat = 0.034

        /// Absolute bottom padding of the title.
        static let titleBottomPadding: CGFloat = 10

        /// Fraction of the container height used as the subtitle bottom padding.
        static let subtitleBottomRatio: CGFloat = 0.025

        /// Fraction of the container height used as the room name bottom padding.
        static let roomNameBottomRatio: CGFloat = 0.018

        /// Fraction of the container height used as the divider thickness.
        static let dividerHeightRatio: CGFloat = 0.001

        /// Fraction of the container height reserved below the advance button.
        static let advanceButtonBottomRatio: CGFloat = 0.07

        /// Fraction of the container width used as the horizontal margin.
        static let horizontalMarginRatio: CGFloat = 0.086

        /// Diameter of the circular advance button.
        static let advanceButtonSize: CGFloat = 56

        /// Blur radius of the advance button shadow.
        static let advanceButtonShadowRadius: CGFloat = 8

        /// Vertical offset of the advance button shadow.
        static let advanceButtonShadowOffsetY: CGFloat = 4

        /// Opacity of the advance button shadow.
        static let advanceButtonShadowOpacity: CGFloat = 0.2
    }

    // MARK: - Properties

    /// Rooms listed on the screen, each holding its own expansion state.
    @State private var rooms: [RoomDTO] = [
        RoomDTO(name: "Sala", symbol: ""),
        RoomDTO(name: "Banheiro", symbol: ""),
        RoomDTO(name: "Cozinha", symbol: ""),
        RoomDTO(name: "Área de serviço", symbol: "")
    ]

    /// Placeholder chores rendered inside every expanded room.
    ///
    /// > Note: Temporary stand-in for the chores fetched from CloudKit through
    /// > ``RoomModel/fetchRelatedChores()``.
    @State private var mockedChores: [ChoreDTO] = [
        ChoreDTO(name: "tarefa1", description: "descrição 1", frequency: .daily, duration: 10, priorityTag: .high),
        ChoreDTO(name: "tarefa2", description: "descrição 2", frequency: .daily, duration: 10, priorityTag: .high),
        ChoreDTO(name: "tarefa3", description: "descrição 3", frequency: .daily, duration: 10, priorityTag: .high)
    ]

    /// Chores the user marked to be split between the residents.
    private var selectedChores: [ChoreDTO] {
        mockedChores.filter { $0.isSelected }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            VStack(alignment: .leading) {
                buildHeader(height: height)

                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach($rooms) { $room in
                            buildRoomSection(room: $room, height: height)
                        }
                    }
                }

                buildAdvanceButton(height: height)
            }
            .padding(.horizontal, width * Layout.horizontalMarginRatio)
        }
    }

    // MARK: - View Builders

    /// Builds the title and the explanatory subtitle of the step.
    /// - Parameter height: Container height reported by `GeometryReader`, in points.
    /// - Returns: The stacked header texts.
    private func buildHeader(height: CGFloat) -> some View {
        VStack(alignment: .leading) {
            Text("Selecione as tarefas")
                .bold()
                .font(.system(size: Layout.titleFontSize))
                .foregroundStyle(.titleGray)
                .padding(.top, height * Layout.titleTopRatio)
                .padding(.bottom, Layout.titleBottomPadding)

            Text("Escolha **apenas** as tarefas que serão divididas de maneira igual entre todos os moradores")
                .font(.system(size: Layout.subtitleFontSize))
                .foregroundStyle(.subTitleGray)
                .padding(.bottom, height * Layout.subtitleBottomRatio)
        }
    }

    /// Builds a collapsible section for a single room.
    ///
    /// The chore toggles are rendered only while the room is expanded, so the
    /// remaining sections keep their collapsed height.
    ///
    /// - Parameters:
    ///   - room: Binding to the room being rendered, used to flip its expansion state.
    ///   - height: Container height reported by `GeometryReader`, in points.
    /// - Returns: The room header, its divider and, when expanded, its chores.
    private func buildRoomSection(room: Binding<RoomDTO>, height: CGFloat) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(room.wrappedValue.name)
                    .font(.system(size: Layout.roomNameFontSize))
                    .bold()
                    .padding(.bottom, height * Layout.roomNameBottomRatio)

                Spacer()

                Button {
                    room.wrappedValue.isExpanded.toggle()
                } label: {
                    Image(systemName: room.wrappedValue.isExpanded ? "chevron.up" : "chevron.down")
                }
                .fontWeight(.semibold)
                .foregroundStyle(.black)
            }

            Divider()
                .frame(height: height * Layout.dividerHeightRatio)
                .overlay(Color.black)

            if room.wrappedValue.isExpanded {
                ForEach($mockedChores) { $chore in
                    Toggle(chore.name, isOn: $chore.isSelected)
                }
            }
        }
    }

    /// Builds the trailing button that confirms the selection and advances.
    /// - Parameter height: Container height reported by `GeometryReader`, in points.
    /// - Returns: The circular advance button aligned to the trailing edge.
    private func buildAdvanceButton(height: CGFloat) -> some View {
        HStack {
            Spacer()

            Button {
                // TODO: Persist `selectedChores` as ChoreModel records and push the
                // next onboarding step. Blocked until the CloudKit save flow is ready.
                advanceToNextStep()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: Layout.advanceIconFontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: Layout.advanceButtonSize, height: Layout.advanceButtonSize)
                    .background(Color.accentColor, in: Circle())
                    .shadow(
                        color: .black.opacity(Layout.advanceButtonShadowOpacity),
                        radius: Layout.advanceButtonShadowRadius,
                        y: Layout.advanceButtonShadowOffsetY
                    )
            }
        }
        .padding(.bottom, height * Layout.advanceButtonBottomRatio)
    }

    // MARK: - Helpers

    /// Confirms the current selection and moves on to the next onboarding step.
    ///
    /// > Note: Not implemented yet. Kept as a named entry point so the button
    /// > label stays free of business logic.
    private func advanceToNextStep() {
        // TODO: Implement once the onboarding navigation flow is defined.
    }
}

#Preview {
    SelectChoresOnboardingView()
}
