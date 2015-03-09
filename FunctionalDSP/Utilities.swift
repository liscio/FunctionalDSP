//
//  Utilities.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 2015-03-09.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation
import Accelerate

func scale(inout x: [Float], var a: Float) {
    vDSP_vsmul(x, 1, &a, &x, 1, vDSP_Length(x.count))
}

func scale(inout x: [Double], var a: Double) {
    vDSP_vsmulD(x, 1, &a, &x, 1, vDSP_Length(x.count))
}

func zeros(count: Int) -> [Float] {
    return [Float](count: count, repeatedValue: 0)
}

func zeros(count: Int) -> [Double] {
    return [Double](count: count, repeatedValue: 0)
}