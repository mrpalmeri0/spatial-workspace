import Foundation
import CoreMedia

@MainActor final class RemoteVideoDecoder {
    private var format: CMVideoFormatDescription?
    private var previousSPS: Data?, previousPPS: Data?
    func reset() { format = nil; previousSPS = nil; previousPPS = nil }
    func sample(_ packet: RemoteMessage) -> CMSampleBuffer? {
        guard let sps = packet.sps, let pps = packet.pps, let data = packet.data,
              !sps.isEmpty, !pps.isEmpty, !data.isEmpty else { return nil }
        if sps != previousSPS || pps != previousPPS {
            var newFormat: CMFormatDescription?
            let status: OSStatus = sps.withUnsafeBytes { s in pps.withUnsafeBytes { p in
                let pointers = [s.bindMemory(to: UInt8.self).baseAddress!, p.bindMemory(to: UInt8.self).baseAddress!]
                let sizes = [sps.count, pps.count]
                return pointers.withUnsafeBufferPointer { pointer in sizes.withUnsafeBufferPointer { size in
                    CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: nil, parameterSetCount: 2,
                        parameterSetPointers: pointer.baseAddress!, parameterSetSizes: size.baseAddress!, nalUnitHeaderLength: 4, formatDescriptionOut: &newFormat)
                } }
            } }
            guard status == noErr else { return nil }
            format = newFormat; previousSPS = sps; previousPPS = pps
        }
        guard let format else { return nil }
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: data.count,
            blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: data.count, flags: 0, blockBufferOut: &block) == noErr,
            let block else { return nil }
        let copied = data.withUnsafeBytes { bytes in CMBlockBufferReplaceDataBytes(with: bytes.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: data.count) }
        guard copied == noErr else { return nil }
        var sample: CMSampleBuffer?
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var size = data.count
        guard CMSampleBufferCreateReady(allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: 1,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sample) == noErr,
            let sample else { return nil }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) as? [NSMutableDictionary] {
            attachments.first?[kCMSampleAttachmentKey_DisplayImmediately] = true
        }
        return sample
    }
}
