//
//  DispatchData.swift
//  DispatchKit <https://github.com/anpol/DispatchKit>
//
//  Copyright (c) 2014 Andrei Polushin. All rights reserved.
//

import Foundation

public struct DispatchData<T: IntegerType>: DispatchObject {

    typealias Scale = DispatchDataScale<T>

    public static var Empty: DispatchData {
        return DispatchData(rawValue: dispatch_data_empty)
    }

    @available(*, unavailable, renamed="rawValue")
    public var data: dispatch_data_t {
        return rawValue
    }

    @available(*, unavailable, renamed="DispatchData(rawValue:)")
    public init(raw data: dispatch_data_t) {
        self.rawValue = data
    }

    public let rawValue: dispatch_data_t

    public init(rawValue: dispatch_data_t) {
        self.rawValue = rawValue
    }

    /**
     * Copies the array's data and manages it internally.
     *
     * - parameter array: The array to be copied.
     */
    public init!(_ array: [T]) {
        let size = Scale.toBytes(array.count)

        guard let rawValue = array.withUnsafeBufferPointer({ p in
            dispatch_data_create(p.baseAddress, size, nil, nil)
        }) else {
            return nil
        }

        self.rawValue = rawValue
    }

    /**
     * Consumes a buffer previosly allocated by `UnsafeMutablePointer.alloc`_.
     *
     * - parameter buffer:
     * - parameter count:
     * - parameter queue: A queue on which to call `UnsafeMutablePointer.dealloc`_ for the buffer.
     */
    public init!(_ buffer: UnsafeMutablePointer<T>, _ count: Int, _ queue: dispatch_queue_t! = nil) {
        let size = Scale.toBytes(count)

        guard let rawValue = dispatch_data_create(buffer, size, queue, {
            buffer.dealloc(count)
        }) else {
            return nil
        }

        self.rawValue = rawValue
    }

    // The destructor is responsible to free the buffer.
    public init!(_ buffer: UnsafePointer<T>, _ count: Int,
         _ queue: dispatch_queue_t!, destructor: dispatch_block_t!) {

        let size = Scale.toBytes(count)
        guard let rawValue = dispatch_data_create(buffer, size, queue, destructor) else {
            return nil
        }

        self.rawValue = rawValue
    }

    public var count: Int {
        return Scale.fromBytes(dispatch_data_get_size(rawValue))
    }

    public subscript(range: Range<Int>) -> DispatchData! {
        let offset = Scale.toBytes(range.startIndex)
        let length = Scale.toBytes(range.endIndex - range.startIndex)

        guard let rawValue = dispatch_data_create_subrange(rawValue, offset, length) else {
            return nil
        }

        return DispatchData(rawValue: rawValue)
    }


    public typealias Region = (data: DispatchData, offset: Int)

    public func copyRegion(location: Int) -> Region! {
        var offset: Int = 0

        guard let region = dispatch_data_copy_region(rawValue, Scale.toBytes(location), &offset) else {
            return nil
        }

        return (DispatchData(rawValue: region), Scale.fromBytes(offset))
    }


    public typealias Buffer = (start: UnsafePointer<T>, count: Int)

    public func createMap() -> (owner: DispatchData, buffer: Buffer)! {
        var buffer: UnsafePointer<Void> = nil
        var size: Int = 0

        guard let owner = dispatch_data_create_map(rawValue, &buffer, &size) else {
            return nil
        }

        return (DispatchData(rawValue: owner), (UnsafePointer<T>(buffer), Scale.fromBytes(size)))
    }


    public typealias Applier = (region: Region, buffer: Buffer) -> Bool

    public func apply(applier: Applier) -> Bool {
        return dispatch_data_apply(rawValue) {
            (region, offset, buffer, size) -> Bool in
            applier(region: (DispatchData<T>(rawValue: region), Scale.fromBytes(offset)),
                    buffer: (UnsafePointer<T>(buffer), Scale.fromBytes(size)))
        }
    }

}


public func + <T>(a: DispatchData<T>, b: DispatchData<T>) -> DispatchData<T>! {
    guard let rawValue = dispatch_data_create_concat(a.rawValue, b.rawValue) else {
        return nil
    }

    return DispatchData<T>(rawValue: rawValue)
}
