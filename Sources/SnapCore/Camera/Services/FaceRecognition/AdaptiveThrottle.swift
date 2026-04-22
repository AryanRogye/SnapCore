//
//  AdaptiveThrottle.swift
//  ComfyRep
//
//  Created by Aryan Rogye on 12/28/25.
//

import Foundation

final class AdaptiveThrottle {
    private var lastProcessedTime: CFAbsoluteTime = 0
    
    let stableInterval: CFAbsoluteTime
    let movingInterval: CFAbsoluteTime
    
    private let lock = NSLock()
    private var _currentInterval: CFAbsoluteTime
    
    var currentInterval: CFAbsoluteTime {
        lock.lock(); defer { lock.unlock() }
        return _currentInterval
    }
    
    init(stableFPS: Double, movingFPS: Double, startMoving: Bool = true) {
        self.stableInterval = 1.0 / stableFPS
        self.movingInterval = 1.0 / movingFPS
        self._currentInterval = startMoving ? (1.0 / movingFPS) : (1.0 / stableFPS)
    }
    
    /// Call this per frame; returns true if you should do work now.
    func shouldProcessNow() -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        defer { lock.unlock() }
        
        if now - lastProcessedTime < _currentInterval { return false }
        lastProcessedTime = now
        return true
    }
    
    func setStable() {
        lock.lock(); defer { lock.unlock() }
        _currentInterval = stableInterval
    }
    
    func setMoving() {
        lock.lock(); defer { lock.unlock() }
        _currentInterval = movingInterval
    }
    
    func setStable(_ stable: Bool) {
        stable ? setStable() : setMoving()
    }
}
