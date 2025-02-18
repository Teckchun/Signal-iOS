//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

public class CVComponentGiftBadge: CVComponentBase, CVComponent {

    public var componentKey: CVComponentKey { .giftBadge }

    private let giftBadge: CVComponentState.GiftBadge

    private let timeState: TimeState

    // Component state objects are derived from TSInteractions, and they're
    // only updated when the underlying interaction changes. The "N days
    // remaining" label depends on the current time, so we need to use
    // CVItemViewState, which is refreshed even when the underlying interaction
    // hasn't changed. This is similar to how the time in the footer works.
    struct TimeState: Equatable {
        let timeRemainingText: String
    }

    static func buildTimeState(_ giftBadge: CVComponentState.GiftBadge) -> TimeState {
        return TimeState(timeRemainingText: GiftBadgeView.timeRemainingText(for: giftBadge.expirationDate))
    }

    private var viewState: GiftBadgeView.State {
        GiftBadgeView.State(
            badgeLoader: self.giftBadge.loader,
            timeRemainingText: self.timeState.timeRemainingText,
            isIncoming: self.isIncoming,
            conversationStyle: self.conversationStyle
        )
    }

    init(itemModel: CVItemModel, giftBadge: CVComponentState.GiftBadge, timeState: TimeState) {
        self.giftBadge = giftBadge
        self.timeState = timeState
        super.init(itemModel: itemModel)
    }

    public func buildComponentView(componentDelegate: CVComponentDelegate) -> CVComponentView {
        CVComponentViewGiftBadge()
    }

    public func configureForRendering(
        componentView: CVComponentView,
        cellMeasurement: CVCellMeasurement,
        componentDelegate: CVComponentDelegate
    ) {
        guard let componentView = componentView as? CVComponentViewGiftBadge else {
            owsFailDebug("unexpected componentView")
            componentView.reset()
            return
        }

        componentView.giftBadgeView.configureForRendering(state: self.viewState, cellMeasurement: cellMeasurement)
    }

    public func measure(maxWidth: CGFloat, measurementBuilder: CVCellMeasurement.Builder) -> CGSize {
        return GiftBadgeView.measurement(for: self.viewState, maxWidth: maxWidth, measurementBuilder: measurementBuilder)
    }

    public override func handleTap(
        sender: UITapGestureRecognizer,
        componentDelegate: CVComponentDelegate,
        componentView: CVComponentView,
        renderItem: CVRenderItem
    ) -> Bool {

        guard let componentView = componentView as? CVComponentViewGiftBadge else {
            owsFailDebug("unexpected componentView")
            return false
        }

        let buttonView = componentView.giftBadgeView.buttonStack
        guard buttonView.bounds.contains(sender.location(in: buttonView)) else {
            return false
        }

        let itemViewModel = CVItemViewModelImpl(renderItem: renderItem)
        componentDelegate.cvc_didTapGiftBadge(itemViewModel)
        return true
    }

    public class CVComponentViewGiftBadge: NSObject, CVComponentView {
        fileprivate let giftBadgeView = GiftBadgeView(name: "GiftBadgeView")

        public var isDedicatedCellView = false

        public var rootView: UIView { giftBadgeView }

        public func setIsCellVisible(_ isCellVisible: Bool) {
            // TODO: (GB) Start/stop the gift wrap animation, as needed.
        }

        public func reset() {
            giftBadgeView.reset()
        }
    }
}
