import SwiftUI
import UIKit
import RealityKit
import ARKit
import AVFoundation

class StatusViewController: UIViewController {
    let messageLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.numberOfLines = 0
        label.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLabel()
    }
    
    private func setupLabel() {
        view.addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.addSubview(messageLabel)
        view.addSubview(containerView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            messageLabel.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 12),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            messageLabel.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -12),
            
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            containerView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9)
        ])
    }
    
    func showMessage(_ message: String, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async { [weak self] in
            self?.messageLabel.text = message
            self?.messageLabel.isHidden = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self?.messageLabel.isHidden = true
            }
        }
    }
}

// Main AR View Controller
class ARViewController: UIViewController, ARSessionDelegate {
    var arView: ARView!
    let statusViewController = StatusViewController()
    
    // Resource pairs
    let imageVideoPairs: [String: String] = [
        "Base-Mural": "video",
        "Base-Mural2": "video2",
        "Base-Mural3": "video3"
        
    ]
    
    let imageModelPairs: [String: String] = [
        "book": "Robot-Talk-On-Coms"
    ]
    
    // New audio pairs
    let imageAudioPairs: [String: String] = [
        "book": "song"
        
    ]
    
    // Entities and players
    var currentVideoNode: ModelEntity?
    var currentPlayer: AVPlayer?
    var currentModelEntity: Entity?
    var currentAudioPlayer: AVAudioPlayer?
    var isAnimationPlaying = false
    
    // UI Elements
    var resetButton: UIButton!
    var animationButton: UIButton!
    var audioButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAR()
        setupUI()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupAR() {
        arView = ARView(frame: view.bounds)
        view.addSubview(arView)
        arView.session.delegate = self
        resetTracking()
    }
    
    private func setupUI() {
        addChild(statusViewController)
        view.addSubview(statusViewController.view)
        statusViewController.didMove(toParent: self)
        
        // Reset Button
        resetButton = UIButton(type: .system)
        resetButton.setImage(UIImage(systemName: "arrow.clockwise.circle.fill"), for: .normal)
        resetButton.tintColor = .white
        resetButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        resetButton.layer.cornerRadius = 25
        resetButton.addTarget(self, action: #selector(resetTracking), for: .touchUpInside)
        
        // Animation Button
        animationButton = UIButton(type: .system)
        animationButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        animationButton.tintColor = .white
        animationButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        animationButton.layer.cornerRadius = 25
        animationButton.addTarget(self, action: #selector(toggleAnimation), for: .touchUpInside)
        animationButton.isHidden = true
        
        // Audio Button
        audioButton = UIButton(type: .system)
        audioButton.setImage(UIImage(systemName: "speaker.wave.2.circle.fill"), for: .normal)
        audioButton.tintColor = .white
        audioButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        audioButton.layer.cornerRadius = 25
        audioButton.addTarget(self, action: #selector(toggleAudio), for: .touchUpInside)
        audioButton.isHidden = true
        
        view.addSubview(resetButton)
        view.addSubview(animationButton)
        view.addSubview(audioButton)
        
        // Layout
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        animationButton.translatesAutoresizingMaskIntoConstraints = false
        audioButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            resetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            resetButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            resetButton.widthAnchor.constraint(equalToConstant: 50),
            resetButton.heightAnchor.constraint(equalToConstant: 50),
            
            animationButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            animationButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            animationButton.widthAnchor.constraint(equalToConstant: 50),
            animationButton.heightAnchor.constraint(equalToConstant: 50),
            
            audioButton.bottomAnchor.constraint(equalTo: animationButton.topAnchor, constant: -20),
            audioButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            audioButton.widthAnchor.constraint(equalToConstant: 50),
            audioButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc func resetTracking() {
        guard let referenceImages = ARReferenceImage.referenceImages(
            inGroupNamed: "AR Resources",
            bundle: Bundle.main
        ) else {
            statusViewController.showMessage("Missing AR Resources")
            return
        }
        
        // Clean up existing content
        arView.scene.anchors.removeAll()
        currentVideoNode = nil
        currentPlayer?.pause()
        currentModelEntity = nil
        currentAudioPlayer?.stop()
        currentAudioPlayer = nil
        
        let config = ARWorldTrackingConfiguration()
        config.detectionImages = referenceImages
        config.maximumNumberOfTrackedImages = 1
        
        arView.session.run(config, options: [.removeExistingAnchors, .resetTracking])
        statusViewController.showMessage("Looking for images...")
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let imageAnchor = anchor as? ARImageAnchor,
                  let imageName = imageAnchor.referenceImage.name else { continue }
            
            // Handle video content
            if let videoName = imageVideoPairs[imageName],
               let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mov") {
                setupVideo(for: imageAnchor, with: videoURL)
            }
            
            // Handle model content
            if let modelName = imageModelPairs[imageName],
               let modelURL = Bundle.main.url(forResource: modelName, withExtension: "usdz") {
                setupModel(for: imageAnchor, with: modelURL)
            }
            
            // Handle audio content
            if let audioName = imageAudioPairs[imageName],
               let audioURL = Bundle.main.url(forResource: audioName, withExtension: "wav") {
                setupAudio(with: audioURL)
            }
        }
    }
    
    private func setupVideo(for imageAnchor: ARImageAnchor, with videoURL: URL) {
        let player = AVPlayer(url: videoURL)
        currentPlayer = player
        
        let videoMaterial = VideoMaterial(avPlayer: player)
        let mesh = MeshResource.generatePlane(
            width: Float(imageAnchor.referenceImage.physicalSize.width),
            height: Float(imageAnchor.referenceImage.physicalSize.height)
        )
        
        let videoEntity = ModelEntity(mesh: mesh, materials: [videoMaterial])
        videoEntity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        currentVideoNode = videoEntity
        
        let anchorEntity = AnchorEntity(anchor: imageAnchor)
        anchorEntity.addChild(videoEntity)
        arView.scene.addAnchor(anchorEntity)
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main) { [weak self] _ in
                self?.currentPlayer?.seek(to: .zero)
                self?.currentPlayer?.play()
        }
        
        player.play()
        statusViewController.showMessage("Video playing")
    }
    
    private func setupModel(for imageAnchor: ARImageAnchor, with modelURL: URL) {
        do {
            let loadedEntity = try Entity.load(contentsOf: modelURL)
            
            loadedEntity.position = [0, 0.3, 0]
            loadedEntity.scale = [0.3, 0.3, 0.3]
            
            let rotation = simd_quatf(angle: 0, axis: [1, 0, 0])
            loadedEntity.orientation = rotation
            
            let anchorEntity = AnchorEntity(anchor: imageAnchor)
            anchorEntity.addChild(loadedEntity)
            arView.scene.addAnchor(anchorEntity)
            
            currentModelEntity = loadedEntity
            
            if !loadedEntity.availableAnimations.isEmpty {
                loadedEntity.playAnimation(loadedEntity.availableAnimations[0].repeat())
                isAnimationPlaying = true
                animationButton.isHidden = false
                animationButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
            }
            
            statusViewController.showMessage("Model loaded")
            
        } catch {
            print("Failed to load model: \(error)")
            statusViewController.showMessage("Failed to load model")
        }
    }
    
    private func setupAudio(with audioURL: URL) {
        do {
            currentAudioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            currentAudioPlayer?.prepareToPlay()
            currentAudioPlayer?.numberOfLoops = -1 // Loop indefinitely
            currentAudioPlayer?.play()
            audioButton.isHidden = false
            statusViewController.showMessage("Audio playing")
        } catch {
            print("Failed to load audio: \(error)")
            statusViewController.showMessage("Failed to load audio")
        }
    }
    
    @objc func toggleAnimation() {
        guard let entity = currentModelEntity,
              !entity.availableAnimations.isEmpty else { return }
        
        if isAnimationPlaying {
            entity.stopAllAnimations()
            animationButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        } else {
            entity.playAnimation(entity.availableAnimations[0].repeat())
            animationButton.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        }
        
        isAnimationPlaying.toggle()
    }
    
    @objc func toggleAudio() {
        guard let audioPlayer = currentAudioPlayer else { return }
        
        if audioPlayer.isPlaying {
            audioPlayer.pause()
            audioButton.setImage(UIImage(systemName: "speaker.slash.circle.fill"), for: .normal)
        } else {
            audioPlayer.play()
            audioButton.setImage(UIImage(systemName: "speaker.wave.2.circle.fill"), for: .normal)
        }
    }
}

// SwiftUI View
struct ContentView: View {
    var body: some View {
        ARViewControllerRepresentable()
            .edgesIgnoringSafeArea(.all)
    }
}

struct ARViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ARViewController {
        return ARViewController()
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {}
}
