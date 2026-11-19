import SwiftUI

struct VotingView: View {
    @ObservedObject var vm: GameViewModel
    @State private var revealAgreement = false
    var body: some View {
        ZStack {
            Night.background.ignoresSafeArea()
            CinematicBackground(animated: false, gold: true)
            VStack(spacing: 0) {
                HStack { BrandMark(); Spacer(); Eyebrow(text: "Optional local voting", color: Night.gold); Spacer(); MusicQuickControls(manager: vm.music); IconButton(symbol: "xmark", label: "Close and erase votes", action: vm.clearPrivateVote) }.padding(30)
                Hairline()
                ScrollView {
                    VStack(spacing: 25) {
                        Text(vm.voteTitle).font(Night.serif(35)).multilineTextAlignment(.center)
                        if vm.voteSetup { setup }
                        else if let vote = vm.vote {
                            if vote.isComplete { results(vote) }
                            else if vm.votePrivacyCover { privacyCover(vote) }
                            else { ballot(vote) }
                        }
                    }.padding(40).frame(maxWidth: 850).frame(maxWidth: .infinity)
                }
                VStack(spacing: 6) {
                    Text("Shared-screen voting is not perfectly anonymous.").foregroundStyle(Night.gold)
                    Text("Others may see your choice or infer it from totals. Pass freely. Only totals are kept in memory; closing erases them.").foregroundStyle(Night.muted)
                }.font(.system(size: 11)).multilineTextAlignment(.center).padding(22)
            }
        }.transition(.opacity)
    }
    private var setup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Agree on the options together.").font(Night.serif(25))
            Text("Use 2–20 labels, one per line. For stories or date ideas, use labels such as “Story A” or “Plan B”; read the details aloud, voluntarily.")
                .font(.system(size: 13)).foregroundStyle(Night.muted).lineSpacing(5)
            TextEditor(text: $vm.voteOptionsText).font(.system(size: 16)).scrollContentBackground(.hidden).padding(12).frame(height: 180).background(Night.card, in: RoundedRectangle(cornerRadius: 7))
            NightButton(title: "Prepare the ballot", gold: true, action: vm.beginVoting)
        }
    }
    private func privacyCover(_ vote: LocalVote) -> some View {
        VStack(spacing: 25) {
            Image(systemName: "hand.raised").font(.system(size: 48, weight: .ultraLight)).foregroundStyle(Night.gold)
            Eyebrow(text: "Ballot \(vote.submitted + 1) of \(vote.voterCount)", color: Night.gold)
            Text("Pass the Mac.\nGive the next player a moment.").font(Night.serif(39)).multilineTextAlignment(.center).lineSpacing(8)
            Text("Look away from the screen. No names are attached to ballots.").font(.system(size: 13)).foregroundStyle(Night.muted)
            NightButton(title: "I'm ready to vote", symbol: "arrow.right", gold: true) { vm.votePrivacyCover = false }
            Button("Opt out of this ballot") { vm.submitVote(nil) }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Night.muted)
        }.padding(35)
    }
    private func ballot(_ vote: LocalVote) -> some View {
        VStack(spacing: 18) {
            Eyebrow(text: "Choose privately. Then pass the Mac.", color: Night.gold)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                ForEach(vote.options.indices, id: \.self) { index in
                    Button { vm.submitVote(index) } label: {
                        Text(vote.options[index]).font(.system(size: 18, weight: .medium)).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(23)
                            .background(Night.card, in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Night.gold.opacity(0.3)))
                    }.buttonStyle(.plain)
                }
            }
            Button("Pass — no vote") { vm.submitVote(nil) }.buttonStyle(.plain).foregroundStyle(Night.muted).padding(15)
        }
    }
    private func results(_ vote: LocalVote) -> some View {
        VStack(spacing: 22) {
            if !vm.voteReveal {
                Text("The room has spoken.").font(Night.serif(42))
                Text("Bring everyone back to the screen. Reveal only if every participant agrees. Small groups can make totals identifiable.")
                    .font(.system(size: 14)).foregroundStyle(Night.muted).multilineTextAlignment(.center).lineSpacing(6)
                Toggle("Everyone agrees to reveal the aggregate totals.", isOn: $revealAgreement).toggleStyle(.checkbox).tint(Night.gold)
                NightButton(title: "Reveal totals", gold: true) { vm.voteReveal = true }.disabled(!revealAgreement)
                Button("Erase without revealing", action: vm.clearPrivateVote).buttonStyle(.plain).foregroundStyle(Night.muted)
            } else {
                Eyebrow(text: "Aggregate totals only", color: Night.gold)
                ForEach(vote.options.indices, id: \.self) { index in
                    HStack {
                        Text(vote.options[index]).font(Night.serif(24))
                        Spacer()
                        Text("\(vote.totals[index])").font(Night.serif(30)).foregroundStyle(Night.gold)
                    }.padding(18).background(Night.card, in: RoundedRectangle(cornerRadius: 6))
                }
                Text("\(vote.abstentions) passed · no individual ballots retained").font(.system(size: 12)).foregroundStyle(Night.muted)
                if vm.activeQuestion?.voting == .verdict && vm.voteCategory < 2 {
                    NightButton(title: "Next category", symbol: "arrow.right", gold: true) { revealAgreement = false; vm.nextVoteCategory() }
                } else { NightButton(title: "Close & erase votes", gold: true, action: vm.clearPrivateVote) }
            }
        }
    }
}
