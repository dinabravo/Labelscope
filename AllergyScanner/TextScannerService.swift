import AVFoundation
import Vision
import Combine

final class TextScannerService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var detectedMatches: [AllergenMatch] = []
    @Published private(set) var matchedBoxes: [CGRect] = []

    var allergens: [String] = [] {
        didSet {
            textRequest.customWords = allergens
            allergenPhrases = Dictionary(uniqueKeysWithValues:
                allergens.map { ($0, AllergenMatcher.searchPhrases(for: $0)) })
        }
    }

    /// Precomputed search phrases (aliases, plural/singular forms) per user allergen,
    /// rebuilt whenever `allergens` changes instead of on every frame.
    private var allergenPhrases: [String: [String]] = [:]

    private var matchedSet = Set<String>()
    private var lastAlertDate = Date.distantPast
    private let alertCooldown: TimeInterval = 1.0

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "TextScannerQueue")

    // Vision's .accurate recognizer is noticeably slower than .fast, so only feed it
    // every Nth camera frame to keep the live preview responsive.
    private var frameCounter = 0
    private let frameProcessInterval = 3

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(output)
        // Frames are deliberately left in the sensor's native (landscape) orientation —
        // Vision is told how to read them via an orientation hint in captureOutput(), and
        // CameraPreview undoes that rotation before mapping boxes onto the preview layer.
    }

    func start() {
        queue.async {
            guard !self.session.isRunning else { return }
            DispatchQueue.main.async {
                self.matchedSet.removeAll()
                self.detectedMatches.removeAll()
                self.matchedBoxes.removeAll()
                self.lastAlertDate = .distantPast
            }
            self.session.startRunning()
        }
    }

    func stop() {
        queue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func getSession() -> AVCaptureSession { session }

    // MARK: - OCR

    private lazy var textRequest: VNRecognizeTextRequest = {
        let req = VNRecognizeTextRequest(completionHandler: handleTexts)
        req.recognitionLevel = .accurate
        req.recognitionLanguages = ["en-US","es-ES","fr-FR","de-DE"]
        req.usesLanguageCorrection = true
        req.customWords = allergens
        return req
    }()

    private func handleTexts(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation],
              !observations.isEmpty
        else {
            // no text: clear boxes
            DispatchQueue.main.async { self.matchedBoxes = [] }
            return
        }

        // Keep each line's recognized-text candidate (for precise per-phrase boxes below)
        // alongside its normalized string (for matching, with clean word boundaries
        // regardless of how OCR punctuated the text — commas, parens, line breaks, etc.).
        let lines: [(candidate: VNRecognizedText, normalized: String, box: CGRect)] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            return (candidate, AllergenMatcher.normalize(candidate.string), obs.boundingBox)
        }

        // Join across lines so multi-word allergens (e.g. "tree nuts") and words wrapped
        // across two lines still match.
        let fullText = lines.map(\.normalized).joined(separator: " ")

        // An allergen matches if any of its search phrases (itself, its plural/singular
        // form, or a known alias/derivative like "whey" for "milk") appears in the text.
        // Keep the specific phrase that matched so the UI can show *why* it was flagged.
        let found: [(allergen: String, phrase: String)] = allergens.compactMap { allergen in
            guard let phrase = (allergenPhrases[allergen] ?? [])
                .first(where: { AllergenMatcher.containsPhrase($0, in: fullText) })
            else { return nil }
            return (allergen, phrase)
        }

        // Draw a tight box around just the matched word/phrase within its line, rather
        // than the whole line (an ingredient line can be long; only the match matters).
        // Falls back to the whole line's box on the rare case the phrase can't be located
        // precisely (e.g. it only matched once split across two lines).
        let foundPhrases = Set(found.map(\.phrase))
        let boxes: [CGRect] = lines.flatMap { line -> [CGRect] in
            let matchingPhrases = foundPhrases.filter { AllergenMatcher.containsPhrase($0, in: line.normalized) }
            guard !matchingPhrases.isEmpty else { return [] }
            let tightBoxes = matchingPhrases.compactMap { phrase -> CGRect? in
                guard let range = AllergenMatcher.rangeOfPhrase(phrase, in: line.candidate.string) else { return nil }
                return try? line.candidate.boundingBox(for: range)?.boundingBox
            }
            return tightBoxes.isEmpty ? [line.box] : tightBoxes
        }

        // throttle detectedMatches, but always update boxes
        let now = Date()
        DispatchQueue.main.async {
            self.matchedBoxes = boxes

            if !found.isEmpty, now.timeIntervalSince(self.lastAlertDate) > self.alertCooldown {
                self.lastAlertDate = now
                let new = found.filter { !self.matchedSet.contains($0.allergen.lowercased()) }
                self.matchedSet.formUnion(new.map { $0.allergen.lowercased() })
                self.detectedMatches.append(contentsOf: new.map {
                    AllergenMatch(allergen: $0.allergen.capitalized, matchedPhrase: $0.phrase)
                })
            }
        }
    }

    // MARK: - Delegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % frameProcessInterval == 0 else { return }

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // The buffer is in the sensor's native landscape orientation; `.right` tells Vision
        // to read it as portrait (the scanner UI is portrait-only). Vision then returns
        // boxes in *upright* normalized coordinates — CameraPreview relies on exactly this
        // when it maps them back to the preview layer.
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right, options: [:])
        try? handler.perform([textRequest])
    }
}
