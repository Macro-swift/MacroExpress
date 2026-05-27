//
//  MulterStorage.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021-2026 ZeeZide GmbH. All rights reserved.
//

import struct MacroCore.Buffer
import class  http.IncomingMessage

public protocol MulterStorageContext {

  var config  : multer           { get }

  /// The active request, exposed so storage
  /// implementations can pass it to their
  /// destination / filename selectors.
  var request : IncomingMessage  { get }

  func handleError(_ error: Swift.Error)
}

/**
 * Backend that receives the bytes of a multipart file part.
 *
 * Calls follow this lifecycle:
 *   `startFile` -> `write` (0..n times) -> `endFile`
 *
 * `startFile` and `endFile` are asynchronous: their completion handler
 * MUST be invoked exactly once when the underlying I/O has finished
 * (open / close, upload, ...).
 *
 * `write` is fire-and-forget; failures are surfaced via the next
 * `endFile` completion or directly through `context.handleError`.
 */
public protocol MulterStorage {

  func startFile(_ file: multer.File, in context: MulterStorageContext,
                 completion: @escaping ( Swift.Error? ) -> Void)

  func write(_ data: Buffer, to file: multer.File,
             in context: MulterStorageContext)

  func endFile(_ file: multer.File, in context: MulterStorageContext,
               completion: @escaping ( Swift.Error? ) -> Void)
}
