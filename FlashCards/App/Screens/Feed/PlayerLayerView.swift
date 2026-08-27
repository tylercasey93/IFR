// App/Screens/Feed/PlayerLayerView.swift
import AVFoundation
import SwiftUI
import UIKit

/// AVPlayerLayer wrapper: unlike SwiftUI's VideoPlayer, this gives full-bleed
/// .resizeAspectFill with no system playback chrome — what a feed cell needs.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class LayerHostView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> LayerHostView {
        let view = LayerHostView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: LayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}
