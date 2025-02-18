//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

class StoryThumbnailView: UIView {
    enum Attachment {
        case file(TSAttachment)
        case text(TextAttachment)
        case missing

        static func from(_ attachment: StoryMessageAttachment, transaction: SDSAnyReadTransaction) -> Self {
            switch attachment {
            case .file(let attachmentId):
                guard let attachment = TSAttachment.anyFetch(uniqueId: attachmentId, transaction: transaction) else {
                    owsFailDebug("Unexpectedly missing attachment for story")
                    return .missing
                }
                return .file(attachment)
            case .text(let attachment):
                return .text(attachment)
            }
        }
    }

    init(attachment: Attachment) {
        super.init(frame: .zero)

        layer.cornerRadius = 12
        clipsToBounds = true

        switch attachment {
        case .file(let attachment):
            if let pointer = attachment as? TSAttachmentPointer {
                let pointerView = UIView()

                if let blurHashImageView = buildBlurHashImageViewIfAvailable(pointer: pointer) {
                    pointerView.addSubview(blurHashImageView)
                    blurHashImageView.autoPinEdgesToSuperviewEdges()
                }

                let downloadStateView = buildDownloadStateView(for: pointer)
                pointerView.addSubview(downloadStateView)
                downloadStateView.autoPinEdgesToSuperviewEdges()

                addSubview(pointerView)
                pointerView.autoPinEdgesToSuperviewEdges()
            } else if let stream = attachment as? TSAttachmentStream {
                let backgroundImageView = buildBackgroundImageView(stream: stream)
                addSubview(backgroundImageView)
                backgroundImageView.autoPinEdgesToSuperviewEdges()
                let imageView = buildThumbnailImageView(stream: stream)
                addSubview(imageView)
                imageView.autoPinEdgesToSuperviewEdges()
            } else {
                owsFailDebug("Unexpected attachment type \(type(of: attachment))")
            }
        case .text(let attachment):
            let textThumbnailView = TextAttachmentView(attachment: attachment).asThumbnailView()
            addSubview(textThumbnailView)
            textThumbnailView.autoPinEdgesToSuperviewEdges()
        case .missing:
            // TODO: error state
            break
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildBackgroundImageView(stream: TSAttachmentStream) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill

        applyThumbnailImage(to: imageView, for: stream)

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        imageView.addSubview(blurView)
        blurView.autoPinEdgesToSuperviewEdges()

        return imageView
    }

    private func buildThumbnailImageView(stream: TSAttachmentStream) -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.minificationFilter = .trilinear
        imageView.layer.magnificationFilter = .trilinear
        imageView.layer.allowsEdgeAntialiasing = true

        applyThumbnailImage(to: imageView, for: stream)

        return imageView
    }

    private static let thumbnailCache = LRUCache<String, UIImage>(maxSize: 64, shouldEvacuateInBackground: true)
    private func applyThumbnailImage(to imageView: UIImageView, for stream: TSAttachmentStream) {
        if let thumbnailImage = Self.thumbnailCache[stream.uniqueId] {
            imageView.image = thumbnailImage
        } else {
            stream.thumbnailImageSmall { thumbnailImage in
                imageView.image = thumbnailImage
                Self.thumbnailCache.setObject(thumbnailImage, forKey: stream.uniqueId)
            } failure: {
                owsFailDebug("Failed to generate thumbnail")
            }
        }
    }

    private func buildBlurHashImageViewIfAvailable(pointer: TSAttachmentPointer) -> UIView? {
        guard let blurHash = pointer.blurHash, let blurHashImage = BlurHash.image(for: blurHash) else {
            return nil
        }
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.minificationFilter = .trilinear
        imageView.layer.magnificationFilter = .trilinear
        imageView.layer.allowsEdgeAntialiasing = true
        imageView.image = blurHashImage
        return imageView
    }

    private static let mediaCache = CVMediaCache()
    private func buildDownloadStateView(for pointer: TSAttachmentPointer) -> UIView {
        let view = UIView()

        let progressView = CVAttachmentProgressView(
            direction: .download(attachmentPointer: pointer),
            style: .withCircle,
            isDarkThemeEnabled: true,
            mediaCache: Self.mediaCache
        )
        view.addSubview(progressView)
        progressView.autoSetDimensions(to: progressView.layoutSize)
        progressView.autoCenterInSuperview()

        return view
    }
}
