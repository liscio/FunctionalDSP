//
//  Utilities.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 2015-03-09.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation
import Accelerate

func scale(_ x: inout [Float], a: Float) {
    var a = a
    vDSP_vsmul(x, 1, &a, &x, 1, vDSP_Length(x.count))
}

func scale(_ x: inout [Double], a: Double) {
    var a = a
    vDSP_vsmulD(x, 1, &a, &x, 1, vDSP_Length(x.count))
}

func zeros(_ count: Int) -> [Float] {
    return [Float](repeating: 0, count: count)
}

func zeros(_ count: Int) -> [Double] {
    return [Double](repeating: 0, count: count)
}
