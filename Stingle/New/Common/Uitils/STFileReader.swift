//
//  STFileReader.swift
//  Stingle
//
//  Created by Khoren Asatryan on 5/25/21.
//

import Foundation

final class STFileReader {
   
    let fileURL: URL
    private var channel: DispatchIO?
        
    lazy var fullSize: Int = {
        let size = STApplication.shared.fileSystem.contents(in: self.fileURL)?.count ?? 0
        return size
    }()
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    // MARK: Managing I/O
    
    @discardableResult
    func open() -> Bool {
        guard self.channel == nil else {
            return true
        }
        guard let path = (self.fileURL.path as NSString).utf8String else { return false }
        self.channel = DispatchIO(type: .random, path: path, oflag: 0, mode: 0, queue: .main, cleanupHandler: { error in
            print("Closed a channel with status: \(error)")
        })
        self.channel?.setLimit(lowWater: .max)
        return true
    }
    
    func close() {
        self.channel?.close()
        self.channel = nil
    }
    
    // MARK: Reading the File
    
    func read(byteRange: CountableRange<off_t>, queue: DispatchQueue = .main, completionHandler: @escaping (DispatchData?) -> Void) {
        if let channel = self.channel {
            channel.read(offset: off_t(byteRange.startIndex), length: byteRange.count, queue: queue, ioHandler: { done, data, error in
                completionHandler(data)
            })
        }
        else {
            completionHandler(nil)
        }
    }
    

    func read(fromOffset: off_t, length: off_t, queue: DispatchQueue = .main, completionHandler: @escaping (DispatchData?) -> Void) {
        if let channel = self.channel {
            
            let length = min(off_t(self.fullSize) - fromOffset, length)
            
            
            channel.read(offset: fromOffset, length: Int(length), queue: queue, ioHandler: { done, data, error in
                completionHandler(data)
            })
        }
        else {
            completionHandler(nil)
        }
    }
    
    deinit {
        self.close()
    }
}

private extension CountableRange where Bound: SignedInteger {
    
    func contains(_ other: Self) -> Bool {
        guard !other.isEmpty else {
            return false
        }
        return contains(other.startIndex) && contains(other.endIndex - 1)
    }
    
    var middleIndex: Bound {
        guard !isEmpty else { return startIndex }
        return (endIndex - 1 - startIndex) / 2
    }
    
    func intersects(_ other: Self) -> Bool {
        guard !isEmpty, !other.isEmpty else { return false }
        if other.contains(startIndex) || other.contains(endIndex - 1) {
            return true
        }
        return contains(other.startIndex) || contains(other.endIndex - 1)
    }
}
