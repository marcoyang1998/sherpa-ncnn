//
//  ViewController.swift
//  SherpaNcnn
//
//  Created by fangjun on 2023/1/28.
//

import AVFoundation
import UIKit

extension AudioBuffer {
  func array() -> [Float] {
    return Array(UnsafeBufferPointer(self))
  }
}

extension AVAudioPCMBuffer {
  func array() -> [Float] {
    return self.audioBufferList.pointee.mBuffers.array()
  }
}

class ViewController: UIViewController {
  @IBOutlet weak var resultLabel: UILabel!
  @IBOutlet weak var recordBtn: UIButton!

  var audioEngine: AVAudioEngine? = nil
  var recognizer: SherpaNcnnRecognizer! = nil

  /// It saves the decoded results so far
  var sentences: [String] = [] {
    didSet {
      updateLabel()
    }
  }
  var lastSentence: String = ""
  let maxSentence: Int = 20
  var results: String {
    if sentences.isEmpty && lastSentence.isEmpty {
      return ""
    }
    if sentences.isEmpty {
      return "0: \(lastSentence.lowercased())"
    }

    let start = max(sentences.count - maxSentence, 0)
    if lastSentence.isEmpty {
      return sentences.enumerated().map { (index, s) in "\(index): \(s.lowercased())" }[start...]
        .joined(separator: "\n")
    } else {
      return sentences.enumerated().map { (index, s) in "\(index): \(s.lowercased())" }[start...]
        .joined(separator: "\n") + "\n\(sentences.count): \(lastSentence.lowercased())"
    }
  }

  func updateLabel() {
    DispatchQueue.main.async {
      self.resultLabel.text = self.results
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.

    resultLabel.text = "ASR with Next-gen Kaldi\n\nPress the Start button to run!"
    recordBtn.setTitle("Start", for: .normal)
    initRecognizer()
    initRecorder()
  }

  @IBAction func onRecordBtnClick(_ sender: UIButton) {
    if recordBtn.currentTitle == "Start" {
      startRecorder()
      recordBtn.setTitle("Stop", for: .normal)
    } else {
      stopRecorder()
      recordBtn.setTitle("Start", for: .normal)
    }
  }

  func initRecognizer() {
    // Please select one model that is best suitable for you.
    //
    // You can also modify Model.swift to add new pre-trained models from
    // https://k2-fsa.github.io/sherpa/ncnn/pretrained_models/index.html

    var modelConfig = getMultilingualModelConfig2022_12_06()
    // var modelConfig = getMultilingualModelConfig2022_12_06_Int8()
    // var modelConfig = getConvEmformerSmallEnglishModelConfig2023_01_09()
    // var modelConfig = getConvEmformerSmallEnglishModelConfig2023_01_09_Int8()
    // var modelConfig = getLstmTransducerEnglish_2022_09_05()

    var decoderConfig = sherpaNcnnDecoderConfig(
      decodingMethod: "modified_beam_search",
      numActivePaths: 4,
      enableEndpoint: true,
      rule1MinTrailingSilence: 1.2,
      rule2MinTrailingSilence: 2.4,
      rule3MinUtteranceLength: 200)

    recognizer = SherpaNcnnRecognizer(
      modelConfig: &modelConfig,
      decoderConfig: &decoderConfig)
  }

  func initRecorder() {
    print("init recorder")
    audioEngine = AVAudioEngine()
    let inputNode = self.audioEngine?.inputNode
    let bus = 0
    let inputFormat = inputNode?.outputFormat(forBus: bus)
    let outputFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: 16000, channels: 1,
      interleaved: false)!

    let converter = AVAudioConverter(from: inputFormat!, to: outputFormat)!

    inputNode!.installTap(
      onBus: bus,
      bufferSize: 1024,
      format: inputFormat
    ) {
      (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
      var newBufferAvailable = true

      let inputCallback: AVAudioConverterInputBlock = {
        inNumPackets, outStatus in
        if newBufferAvailable {
          outStatus.pointee = .haveData
          newBufferAvailable = false

          return buffer
        } else {
          outStatus.pointee = .noDataNow
          return nil
        }
      }

      let convertedBuffer = AVAudioPCMBuffer(
        pcmFormat: outputFormat,
        frameCapacity:
          AVAudioFrameCount(outputFormat.sampleRate)
          * buffer.frameLength
          / AVAudioFrameCount(buffer.format.sampleRate))!

      var error: NSError?
      let _ = converter.convert(
        to: convertedBuffer,
        error: &error, withInputFrom: inputCallback)

      // TODO(fangjun): Handle status != haveData

      let array = convertedBuffer.array()
      if !array.isEmpty {
        self.recognizer.acceptWaveform(samples: array)
        self.recognizer.decode()
        let isEndpoint = self.recognizer.isEndpoint()
        let text = self.recognizer.getResult().text

        if !text.isEmpty && self.lastSentence != text {
          self.lastSentence = text
          self.updateLabel()
          print(text)
        }

        if isEndpoint && !text.isEmpty {
          let tmp = self.lastSentence
          self.lastSentence = ""
          self.sentences.append(tmp)
        }
      }
    }

  }

  func startRecorder() {
    lastSentence = ""
    sentences = []

    do {
      try self.audioEngine?.start()
    } catch let error as NSError {
      print("Got an error starting audioEngine: \(error.domain), \(error)")
    }
    print("started")
  }

  func stopRecorder() {
    audioEngine?.stop()
    print("stopped")
  }
}
