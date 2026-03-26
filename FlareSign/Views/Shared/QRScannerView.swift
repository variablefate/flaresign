import SwiftUI
import AVFoundation

/// Camera-based QR code scanner that returns the scanned string.
struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScan = { code in
            onScan(code)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.055, alpha: 1)

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupCamera() }
                    else { self?.showPermissionDenied() }
                }
            }
        case .denied, .restricted:
            showPermissionDenied()
        @unknown default:
            showPermissionDenied()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showError("Camera not available on this device")
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        // Scanning frame overlay
        addScanOverlay()

        self.captureSession = session
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else { return }

        hasScanned = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onScan?(value)
    }

    private func addScanOverlay() {
        let overlay = UIView()
        overlay.frame = view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.isUserInteractionEnabled = false

        // Semi-transparent border with clear center
        let scanSize: CGFloat = 250
        let maskLayer = CAShapeLayer()
        let outerPath = UIBezierPath(rect: overlay.bounds)
        let innerRect = CGRect(
            x: (overlay.bounds.width - scanSize) / 2,
            y: (overlay.bounds.height - scanSize) / 2,
            width: scanSize, height: scanSize
        )
        let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: 16)
        outerPath.append(innerPath)
        outerPath.usesEvenOddFillRule = true
        maskLayer.path = outerPath.cgPath
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        overlay.layer.addSublayer(maskLayer)

        // Orange corner brackets
        let bracketColor = UIColor(red: 1.0, green: 0.565, blue: 0.424, alpha: 1) // rfPrimary
        let bracketLength: CGFloat = 30
        let bracketWidth: CGFloat = 3

        for corner in [(innerRect.minX, innerRect.minY, 1, 1),
                       (innerRect.maxX, innerRect.minY, -1, 1),
                       (innerRect.minX, innerRect.maxY, 1, -1),
                       (innerRect.maxX, innerRect.maxY, -1, -1)] {
            let (x, y, dx, dy) = (corner.0, corner.1, CGFloat(corner.2), CGFloat(corner.3))
            let hLine = CALayer()
            hLine.backgroundColor = bracketColor.cgColor
            hLine.frame = CGRect(x: dx > 0 ? x : x - bracketLength, y: dy > 0 ? y : y - bracketWidth, width: bracketLength, height: bracketWidth)
            overlay.layer.addSublayer(hLine)

            let vLine = CALayer()
            vLine.backgroundColor = bracketColor.cgColor
            vLine.frame = CGRect(x: dx > 0 ? x : x - bracketWidth, y: dy > 0 ? y : y - bracketLength, width: bracketWidth, height: bracketLength)
            overlay.layer.addSublayer(vLine)
        }

        view.addSubview(overlay)
    }

    private func showPermissionDenied() {
        let container = UIView()
        container.frame = view.bounds
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "camera.fill"))
        icon.tintColor = .gray
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let title = UILabel()
        title.text = "Camera Access Required"
        title.textColor = .white
        title.font = .systemFont(ofSize: 18, weight: .bold)

        let body = UILabel()
        body.text = "Open Settings to allow camera access for scanning QR codes."
        body.textColor = .gray
        body.font = .systemFont(ofSize: 14)
        body.textAlignment = .center
        body.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle("Open Settings", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.tintColor = UIColor(red: 1.0, green: 0.565, blue: 0.424, alpha: 1)
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(body)
        stack.addArrangedSubview(button)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 40),
        ])

        view.addSubview(container)
    }

    private func showError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .gray
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15)
        label.frame = view.bounds
        view.addSubview(label)
    }

    @objc private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
