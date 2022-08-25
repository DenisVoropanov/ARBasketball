//
//  ViewController.swift
//  SportAR
//
//  Created by Alexandra Popova on 23.08.2022.
//
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // MARK: - @IBOutlets
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var lightButton: UIButton!
    
    // MARK: - Properties
    
    let configuration = ARWorldTrackingConfiguration()
    var lightSwitcher = false
    
    private var isHoopAdded = false {
        didSet {
            configuration.planeDetection = self.isHoopAdded ? [] : [.horizontal, .vertical]
            configuration.isLightEstimationEnabled = true
            sceneView.session.run(configuration, options: .removeExistingAnchors)
        }
    }
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Detect vertical planes
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - Private Methods
    
    private func getBallNode() -> SCNNode? {
        
        // Get current position to the ball
        guard let frame = sceneView.session.currentFrame else {
            return nil
        }
        
        // Get camera transform
        let cameraTransform = frame.camera.transform
        let matrixCameraTransform = SCNMatrix4(cameraTransform)
        
        // Ball geometry and color
        let ball = SCNSphere(radius: 0.125)
        let ballTexture: UIImage = #imageLiteral(resourceName: "texture")
        ball.firstMaterial?.diffuse.contents = ballTexture
        
        
        // Ball node
        let ballNode = SCNNode(geometry: ball)
        ballNode.name = "ball"
        
        
        // Calculate force matrix for pushing the ball
        let power = Float(5)
        let x = -matrixCameraTransform.m31 * power
        let y = -matrixCameraTransform.m32 * power
        let z = -matrixCameraTransform.m33 * power
        let forceDirection = SCNVector3(x, y, z)
        
        // Add physics
        ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ballNode))
        
        ballNode.physicsBody?.mass = 0.570
        
        // Apply force
        ballNode.physicsBody?.applyForce(forceDirection, asImpulse: true)
        
        // Assign camera position to ball
        ballNode.simdTransform = cameraTransform
        
        return ballNode
    }
    
    private func getHoopNode() -> SCNNode {
        
        let scene = SCNScene(named: "hoop.scn", inDirectory: "art.scnassets")!
        
        let hoopNode = SCNNode()
        
        let board = scene.rootNode.childNode(withName: "board", recursively: false)!.clone()
        let ring = scene.rootNode.childNode(withName: "ring", recursively: false)!.clone()
        
        
        board.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: board,
                options: [SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron]
            )
        )
        
        ring.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                node: ring,
                options: [SCNPhysicsShape.Option.type : SCNPhysicsShape.ShapeType.concavePolyhedron]
            )
        )
        
        
        hoopNode.addChildNode(board)
        hoopNode.addChildNode(ring)
        
        return hoopNode.clone()
    }
    
    private func getPlaneNode(for plane: ARPlaneAnchor) -> SCNNode {
        
        let plane = SCNPlane(width: 10, height: 10)
        plane.firstMaterial?.diffuse.contents = UIColor.orange
        
        // Create 75% transparent plane node
        let planeNode = SCNNode(geometry: plane)
        planeNode.opacity = 0.25
        
        // Rotate plane
        planeNode.eulerAngles.x -= .pi / 2
        
        return planeNode
    }
    
    private func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        
        guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else { return }
        
        // Change plane node center
        planeNode.simdPosition = anchor.center
        
        // Change plane size
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
        
    }
    
    private func restartGame() {
        
        isHoopAdded = false
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            if node.name != nil {
                node.removeFromParentNode()
            }
            
        }
    }
    
    private func lightOnAndOf() {
        lightSwitcher.toggle()
        
        if lightSwitcher {
            lightButton.tintColor = UIColor.green
        } else {
            lightButton.tintColor = UIColor.white
        }
        
        let device = AVCaptureDevice.default(for: AVMediaType.video)
        if ((device?.hasTorch) != nil) {
            do {
                try device?.lockForConfiguration()
                device?.torchMode = device?.torchMode == AVCaptureDevice.TorchMode.on ? .off : .on
                device?.unlockForConfiguration()
            }
            catch {
                print("Torch couldn't be used")
            }
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Add hoop to the center of vertical plane
        node.addChildNode(getPlaneNode(for: planeAnchor))
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Update plane node
        updatePlaneNode(node, for: planeAnchor)
    }
    
    // MARK: - @IBActions
    
    @IBAction func userTapped(_ sender: UITapGestureRecognizer) {
        
        if isHoopAdded {
            
            guard let ballNode = getBallNode() else {
                return
            }
            
            sceneView.scene.rootNode.addChildNode(ballNode)
            
        } else {
            
            let location = sender.location(in: sceneView)
            
            guard let result = sceneView.hitTest(location, types: .existingPlaneUsingExtent).first else {
                return
            }
            
            guard let anchor = result.anchor as? ARPlaneAnchor, anchor.alignment == .vertical else {
                return
            }
            
            // Get hoop node and set it coordinates
            let hoopNode = getHoopNode()
            hoopNode.simdTransform = result.worldTransform
            hoopNode.eulerAngles.x -= .pi / 2
            
            isHoopAdded = true
            sceneView.scene.rootNode.addChildNode(hoopNode)
            
        }
        
    }
    
    @IBAction func restartButton(_ sender: UIButton) {
        restartGame()
        
    }
    
    @IBAction func lightToggleButton(_ sender: UIButton) {
        lightOnAndOf()
    }
}
