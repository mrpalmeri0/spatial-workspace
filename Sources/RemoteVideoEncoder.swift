import Foundation
import VideoToolbox

final class RemoteVideoEncoder {
    private var session: VTCompressionSession?
    private let queue = DispatchQueue(label: "local.rayneo.remote.encoder", qos: .userInteractive)
    private var count: Int64 = 0
    init() throws {
        var created: VTCompressionSession?
        let result = VTCompressionSessionCreate(allocator: nil, width: 1920, height: 1080,
            codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil,
            compressedDataAllocator: nil, outputCallback: nil, refcon: nil, compressionSessionOut: &created)
        guard result == noErr, let created else { throw NSError(domain: "VideoToolbox", code: Int(result)) }
        session = created
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_AverageBitRate, value: 8_000_000 as CFNumber)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: 30 as CFNumber)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 30 as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(created)
    }
    func encode(_ pixel: CVPixelBuffer, completion: @escaping (RemoteMessage?) -> Void) {
        queue.async { [self] in
            guard let session else { completion(nil); return }
            count += 1
            let result = VTCompressionSessionEncodeFrame(session, imageBuffer: pixel,
                presentationTimeStamp: CMTime(value: count, timescale: 30), duration: CMTime(value: 1, timescale: 30),
                frameProperties: nil, infoFlagsOut: nil) { status, _, sample in
                guard status == noErr, let sample, let block = CMSampleBufferGetDataBuffer(sample),
                      let format = CMSampleBufferGetFormatDescription(sample) else { completion(nil); return }
                var length = 0, pointer: UnsafeMutablePointer<Int8>?
                guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
                      let pointer else { completion(nil); return }
                var packet = RemoteMessage("video")
                packet.data = Data(bytes: pointer, count: length)
                for index in 0..<2 {
                    var parameter: UnsafePointer<UInt8>?, size = 0
                    guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: index,
                        parameterSetPointerOut: &parameter, parameterSetSizeOut: &size, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil) == noErr,
                        let parameter else { completion(nil); return }
                    if index == 0 { packet.sps = Data(bytes: parameter, count: size) }
                    else { packet.pps = Data(bytes: parameter, count: size) }
                }
                completion(packet)
            }
            if result != noErr { completion(nil) }
        }
    }
    deinit { if let session { VTCompressionSessionInvalidate(session) } }
}
