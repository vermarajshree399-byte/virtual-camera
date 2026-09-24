//
//  main.swift
//  GestureCameraExtension
//
//  Created by Rajshree Verma on 23/09/26.
//

import Foundation
import CoreMediaIO

let providerSource = GestureCameraExtensionProviderSource(clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)

CFRunLoopRun()
